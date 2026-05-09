"""
Hermes Web UI -- Main server entry point.
Thin routing shell: imports Handler, delegates to api/routes.py, runs server.
All business logic lives in api/*.
"""
import logging
import socket
import sys
import time
import traceback
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

try:
    import resource
except ImportError:  # pragma: no cover - resource is Unix-only
    resource = None
from urllib.parse import urlparse

logger = logging.getLogger(__name__)

from api.auth import check_auth
from api.config import HOST, PORT, STATE_DIR, SESSION_DIR, DEFAULT_WORKSPACE
from api.helpers import j, get_profile_cookie
from api.profiles import set_request_profile, clear_request_profile
from api.routes import handle_delete, handle_get, handle_patch, handle_post
from api.startup import auto_install_agent_deps, fix_credential_permissions
from api.updates import WEBUI_VERSION


class QuietHTTPServer(ThreadingHTTPServer):
    """Custom HTTP server that silently handles common network errors."""
    daemon_threads = True
    request_queue_size = 64

    def __init__(self, *args, **kwargs):
        server_address = args[0] if args else kwargs.get('server_address', None)
        if server_address and ':' in server_address[0]:
            self.address_family = socket.AF_INET6
        super().__init__(*args, **kwargs)
        self.accept_loop_requests_total = 0
        self.accept_loop_last_request_at = 0.0

    def _handle_request_noblock(self):
        """Record accept-loop progress before dispatching a request handler.

        A process can be alive and still stop accepting/dispatching requests.
        Exposing this heartbeat on /health gives supervisors and watchdogs a
        cheap signal that the accept loop is still moving.

        Note: this method is called only from the single ``serve_forever()``
        thread in CPython socketserver, so the un-locked ``+=`` increment is
        safe — there is no other thread mutating these counters. The /health
        readers may see a stale value momentarily but never an inconsistent
        one (Python int reads are atomic). Per Opus advisor on stage-297.
        """
        self.accept_loop_requests_total += 1
        self.accept_loop_last_request_at = time.time()
        return super()._handle_request_noblock()
    
    def handle_error(self, request, client_address):
        """Override to suppress logging for common client disconnect errors."""
        exc_type, exc_value, _ = sys.exc_info()
        
        # Silently ignore common connection errors caused by client disconnects
        if exc_type in (ConnectionResetError, BrokenPipeError, ConnectionAbortedError, TimeoutError):
            return
        
        # Also handle socket errors that indicate client disconnect
        if issubclass(exc_type, OSError):
            # errno 54 is Connection reset by peer on macOS/BSD
            # errno 104 is Connection reset by peer on Linux
            if getattr(exc_value, 'errno', None) in (32, 54, 104, 110):  # EPIPE, ECONNRESET, ETIMEDOUT
                return
        
        # For other errors, use default logging
        super().handle_error(request, client_address)


class Handler(BaseHTTPRequestHandler):
    timeout = 30  # seconds — kills idle/incomplete connections to prevent thread exhaustion
    
    def setup(self):
        """Set socket options for each accepted connection."""
        super().setup()
        # TCP_NODELAY — universal, disables Nagle for HTTP latency
        try:
            self.connection.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        except OSError:
            pass
        # SO_KEEPALIVE — universal master switch (must be set before timing params)
        try:
            self.connection.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
        except OSError:
            pass
        # Per-platform timing parameters
        if hasattr(socket, 'TCP_KEEPIDLE'):  # Linux
            try:
                self.connection.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPIDLE, 10)
                self.connection.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPINTVL, 5)
                self.connection.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPCNT, 3)
            except OSError:
                pass
        elif hasattr(socket, 'TCP_KEEPALIVE'):  # macOS
            try:
                self.connection.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPALIVE, 10)
            except OSError:
                pass
    _ver_suffix = WEBUI_VERSION.removeprefix('v')
    server_version = ('HermesWebUI/' + _ver_suffix) if _ver_suffix != 'unknown' else 'HermesWebUI'
    def log_message(self, fmt, *args): pass  # suppress default Apache-style log

    def log_request(self, code: str='-', size: str='-') -> None:
        """Structured JSON logs for each request."""
        import json as _json
        duration_ms = round((time.time() - getattr(self, '_req_t0', time.time())) * 1000, 1)
        record = _json.dumps({
            'ts': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
            'method': self.command or '-',
            'path': self.path or '-',
            'status': int(code) if str(code).isdigit() else code,
            'ms': duration_ms,
        })
        print(f'[webui] {record}', flush=True)

    def do_GET(self) -> None:
        self._req_t0 = time.time()
        # Per-request profile context from cookie (issue #798)
        cookie_profile = get_profile_cookie(self)
        if cookie_profile:
            set_request_profile(cookie_profile)
        try:
            parsed = urlparse(self.path)
            if not check_auth(self, parsed): return
            result = handle_get(self, parsed)
            if result is False:
                return j(self, {'error': 'not found'}, status=404)
        except Exception as e:
            print(f'[webui] ERROR {self.command} {self.path}\n' + traceback.format_exc(), flush=True)
            return j(self, {'error': 'Internal server error'}, status=500)
        finally:
            clear_request_profile()

    def _handle_write(self, route_func) -> None:
        self._req_t0 = time.time()
        # Per-request profile context from cookie (issue #798)
        cookie_profile = get_profile_cookie(self)
        if cookie_profile:
            set_request_profile(cookie_profile)
        try:
            parsed = urlparse(self.path)
            if not check_auth(self, parsed): return
            result = route_func(self, parsed)
            if result is False:
                return j(self, {'error': 'not found'}, status=404)
        except Exception as e:
            print(f'[webui] ERROR {self.command} {self.path}\n' + traceback.format_exc(), flush=True)
            return j(self, {'error': 'Internal server error'}, status=500)
        finally:
            clear_request_profile()

    def do_POST(self) -> None:
        self._handle_write(handle_post)

    def do_PATCH(self) -> None:
        self._handle_write(handle_patch)

    def do_DELETE(self) -> None:
        self._handle_write(handle_delete)


def _raise_fd_soft_limit(target: int = 4096) -> dict:
    """Best-effort raise of RLIMIT_NOFILE for persistent WebUI hosts.

    macOS launchd jobs often start with a 256 soft limit. If a future FD leak
    regresses, that low ceiling turns a leak into a hard HTTP wedge quickly.
    Raising the soft limit does not hide leaks; it buys enough headroom for
    diagnostics and watchdog recovery.
    """
    if resource is None:
        return {"status": "unsupported"}
    try:
        soft, hard = resource.getrlimit(resource.RLIMIT_NOFILE)
    except Exception as exc:
        return {"status": "error", "error": str(exc)}

    # On Unix, RLIM_INFINITY is commonly a large int; keep the logic explicit
    # so tests can use ordinary integers without depending on platform values.
    desired = int(target)
    if hard not in (-1, getattr(resource, "RLIM_INFINITY", object())):
        desired = min(desired, int(hard))
    if soft >= desired:
        return {"status": "unchanged", "soft": soft, "hard": hard}
    try:
        resource.setrlimit(resource.RLIMIT_NOFILE, (desired, hard))
    except Exception as exc:
        return {"status": "error", "soft": soft, "hard": hard, "error": str(exc)}
    return {"status": "raised", "soft": desired, "hard": hard, "previous_soft": soft}


def main() -> None:
    from api.config import print_startup_config, verify_hermes_imports, _HERMES_FOUND

    # 1. 顯示祇園啟動資訊
    print("", flush=True)
    print("  === 祇園守護者：母艦點火中 ===", flush=True)
    print_startup_config()

    # 2. 提升系統效能 (FD Limit)
    fd_limit = _raise_fd_soft_limit()
    if fd_limit.get("status") == "raised":
        print(f"[ok] 已提升系統處理效率: {fd_limit.get('soft')}", flush=True)

    # 3. 修復憑證權限與 Session 恢復
    fix_credential_permissions()
    try:
        from api.session_recovery import recover_all_sessions_on_startup
        result = recover_all_sessions_on_startup(SESSION_DIR)
        if result.get("restored"):
            print(f"[祇園日誌] 已自動修復並恢復 {result['restored']} 筆對話紀錄。", flush=True)
    except Exception as exc:
        pass

    # 4. 確保透明家園資料夾已就緒 (對齊您的 .env)
    print(f"[祇園日誌] 正在確認家園路徑：{STATE_DIR}", flush=True)
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    SESSION_DIR.mkdir(parents=True, exist_ok=True)
    DEFAULT_WORKSPACE.mkdir(parents=True, exist_ok=True)

    # 5. 安全提示 (簡化版)
    from api.auth import is_auth_enabled
    if not is_auth_enabled():
        print(f'[!!] 提醒：目前為「公益開放模式」，建議於設定中配置密碼。', flush=True)

    # 6. 核心零件 (Hermes Agent) 檢查
    ok, missing, errors = verify_hermes_imports()
    if not ok and _HERMES_FOUND:
        print(f'[祇園日誌] 正在自動校準 Hermes 代理人零件...', flush=True)
        auto_install_agent_deps()
    
    # 7. 啟動即時監控監聽
    try:
        from api.gateway_watcher import start_watcher
        start_watcher()
    except Exception as e:
        print(f'[!!] 警告：監聽組件啟動異常: {e}', flush=True)

    # 8. 正式開啟服務入口
    httpd = QuietHTTPServer((HOST, PORT), Handler)
    scheme = 'http'
    
    print(f'', flush=True)
    print(f'  [恭喜] 祇園守護者已在 M4 Mac 上就位！', flush=True)
    print(f'  -> 本機存取: {scheme}://localhost:{PORT}', flush=True)
    print(f'  -> 區網存取: {scheme}://您的IP:{PORT}', flush=True)
    print(f'  (請保留此視窗以維持守護者運行)', flush=True)
    print(f'', flush=True)

    try:
        httpd.serve_forever()
    finally:
        try:
            from api.gateway_watcher import stop_watcher
            stop_watcher()
        except Exception:
            pass

if __name__ == '__main__':
    main()
