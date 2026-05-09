#!/usr/bin/env python3
"""One-shot bootstrap launcher for Hermes Web UI."""

from __future__ import annotations

import argparse
import os
import platform
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
import venv
import webbrowser
from pathlib import Path

INSTALLER_URL = "https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh"
REPO_ROOT = Path(__file__).resolve().parent

def _load_repo_dotenv() -> None:
    """Load REPO_ROOT/.env into os.environ."""
    env_path = REPO_ROOT / ".env"
    if not env_path.exists():
        return
    try:
        for raw_line in env_path.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            k = k.strip()
            if k.startswith("export "):
                k = k[7:].strip()
            v = v.strip().strip('"').strip("'")
            if k:
                os.environ[k] = v
    except Exception as exc:
        import sys as _sys
        print(f"[bootstrap] Warning: could not load .env — {exc}", file=_sys.stderr)

_load_repo_dotenv()

DEFAULT_HOST = os.getenv("HERMES_WEBUI_HOST", "127.0.0.1")
DEFAULT_PORT = int(os.getenv("HERMES_WEBUI_PORT", "8787"))

def info(msg: str) -> None:
    print(f"[bootstrap] {msg}", flush=True)

def is_wsl() -> bool:
    if platform.system() != "Linux":
        return False
    release = platform.release().lower()
    return (
        "microsoft" in release or "wsl" in release or bool(os.getenv("WSL_DISTRO_NAME"))
    )

def ensure_supported_platform() -> None:
    if platform.system() == "Windows" and not is_wsl():
        raise RuntimeError(
            "Native Windows is not supported for this bootstrap yet. "
            "Please run it from Linux, macOS, or inside WSL2."
        )

def _agent_dir_from_hermes_cli() -> Path | None:
    """Resolve the agent install root by inspecting the `hermes` CLI shebang.
    祇園優化版：確保即便路徑從 .hermes 遷移到 Hermes_Gion_Core 也能準確識別。"""
    hermes_path = shutil.which("hermes")
    if not hermes_path:
        return None
    try:
        with open(hermes_path, "r", encoding="utf-8", errors="replace") as f:
            first_line = f.readline().strip()
    except OSError:
        return None
    if not first_line.startswith("#!"):
        return None
    interp_field = first_line[2:].strip().split(None, 1)
    if not interp_field:
        return None
    interp = Path(interp_field[0])
    if not interp.is_absolute():
        return None
    for parent in interp.parents:
        if (parent / "run_agent.py").exists():
            info(f"偵測到大腦安裝於: {parent.resolve()}")
            return parent.resolve()
    return None

def discover_agent_dir() -> Path | None:
    # 修正：優先看向祇園家園
    home = Path(os.getenv("HERMES_HOME", str(Path.home() / "Hermes_Gion_Core"))).expanduser()
    candidates = [
        os.getenv("HERMES_WEBUI_AGENT_DIR", ""),
        str(home / "hermes-agent"),
        str(REPO_ROOT.parent / "hermes-agent"),
        str(Path.home() / "Hermes_Gion_Core" / "hermes-agent"),
        str(Path.home() / "hermes-agent"),
    ]
    for raw in candidates:
        if not raw:
            continue
        candidate = Path(raw).expanduser().resolve()
        if candidate.exists() and (candidate / "run_agent.py").exists():
            return candidate
    return _agent_dir_from_hermes_cli()

def discover_launcher_python(agent_dir: Path | None) -> str:
    env_python = os.getenv("HERMES_WEBUI_PYTHON")
    if env_python:
        return env_python
    if agent_dir:
        for rel in ("venv/bin/python", "venv/Scripts/python.exe", ".venv/bin/python", ".venv/Scripts/python.exe"):
            candidate = agent_dir / rel
            if candidate.exists():
                return str(candidate)
    for rel in (".venv/bin/python", ".venv/Scripts/python.exe"):
        candidate = REPO_ROOT / rel
        if candidate.exists():
            return str(candidate)
    return shutil.which("python3") or shutil.which("python") or sys.executable

def _python_can_run_webui_and_agent(python_exe: str, agent_dir: Path | None = None) -> bool:
    script = "import yaml\nfrom run_agent import AIAgent\n"
    env = os.environ.copy()
    if agent_dir:
        env["PYTHONPATH"] = (
            str(agent_dir)
            if not env.get("PYTHONPATH")
            else f"{agent_dir}{os.pathsep}{env['PYTHONPATH']}"
        )
    check = subprocess.run([python_exe, "-c", script], capture_output=True, text=True, env=env)
    return check.returncode == 0

def ensure_python_has_webui_deps(python_exe: str, agent_dir: Path | None = None) -> str:
    if _python_can_run_webui_and_agent(python_exe, agent_dir):
        return python_exe

    venv_dir = REPO_ROOT / ".venv"
    venv_python = venv_dir / ("Scripts/python.exe" if platform.system() == "Windows" else "bin/python")
    if not venv_python.exists():
        info(f"Creating local virtualenv at {venv_dir}")
        venv.EnvBuilder(with_pip=True, symlinks=True).create(venv_dir)

    info("Installing WebUI dependencies into local virtualenv")
    subprocess.run([str(venv_python), "-m", "pip", "install", "--quiet", "--upgrade", "pip"], check=True)
    subprocess.run([str(venv_python), "-m", "pip", "install", "--quiet", "-r", str(REPO_ROOT / "requirements.txt")], check=True)
    
    if _python_can_run_webui_and_agent(str(venv_python), agent_dir):
        return str(venv_python)
    raise RuntimeError("Python environment setup failed.")

def hermes_command_exists() -> bool:
    return shutil.which("hermes") is not None

def install_hermes_agent() -> None:
    info(f"Hermes Agent not found. Attempting install via {INSTALLER_URL}")
    subprocess.run(["/bin/bash", "-lc", f"curl -fsSL {INSTALLER_URL} | bash"], check=True)

def wait_for_health(url: str, timeout: float = 25.0) -> bool:
    deadline = time.time() + timeout
    if not url.startswith(("http://", "https://")):
        raise ValueError(f"Invalid health check URL: {url}")
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=2) as response:
                if b'"status": "ok"' in response.read():
                    return True
        except Exception:
            time.sleep(0.4)
    return False

def open_browser(url: str) -> None:
    try:
        webbrowser.open(url)
    except Exception as exc:
        info(f"Could not open browser automatically: {exc}")

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Bootstrap Hermes Web UI onboarding.")
    parser.add_argument("port", nargs="?", type=int, default=DEFAULT_PORT)
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--no-browser", action="store_true")
    parser.add_argument("--skip-agent-install", action="store_true")
    parser.add_argument("--foreground", action="store_true")
    return parser.parse_args()

_SUPERVISOR_ENV_VARS = ("INVOCATION_ID", "JOURNAL_STREAM", "NOTIFY_SOCKET", "XPC_SERVICE_NAME", "SUPERVISOR_ENABLED")

def _is_real_supervisor_value(name: str, value: str) -> bool:
    if not value: return False
    if name == "XPC_SERVICE_NAME":
        if value == "0" or value.startswith("application."): return False
    return True

def _detect_supervisor() -> str | None:
    explicit = os.environ.get("HERMES_WEBUI_FOREGROUND", "").strip().lower()
    if explicit in ("1", "true", "yes", "on"): return "HERMES_WEBUI_FOREGROUND"
    for name in _SUPERVISOR_ENV_VARS:
        if _is_real_supervisor_value(name, os.environ.get(name, "")): return name
    return None

def main() -> int:
    args = parse_args()
    ensure_supported_platform()

    agent_dir = discover_agent_dir()
    if not agent_dir and not hermes_command_exists():
        if args.skip_agent_install:
            raise RuntimeError("Hermes Agent not found.")
        install_hermes_agent()
        agent_dir = discover_agent_dir()

    python_exe = ensure_python_has_webui_deps(discover_launcher_python(agent_dir), agent_dir)
    # 修正：狀態目錄透明化
    state_dir = Path(os.getenv("HERMES_WEBUI_STATE_DIR", str(Path.home() / "Hermes_Gion_Core" / "webui_history"))).expanduser()
    state_dir.mkdir(parents=True, exist_ok=True)

    os.environ["HERMES_WEBUI_HOST"] = args.host
    os.environ["HERMES_WEBUI_PORT"] = str(args.port)
    os.environ.setdefault("HERMES_WEBUI_STATE_DIR", str(state_dir))
    if agent_dir:
        os.environ["HERMES_WEBUI_AGENT_DIR"] = str(agent_dir)

    server_cwd = str(agent_dir or REPO_ROOT)
    server_path = str(REPO_ROOT / "server.py")

    foreground_reason = "--foreground" if args.foreground else _detect_supervisor()
    if foreground_reason:
        info(f"Starting Hermes Web UI on http://{args.host}:{args.port} (foreground)")
        try:
            os.chdir(server_cwd)
        except OSError as exc:
            raise RuntimeError(f"Could not chdir: {exc}")
        if not os.access(python_exe, os.X_OK):
            raise RuntimeError(f"Python interpreter not executable: {python_exe}")
        os.execv(python_exe, [python_exe, server_path])
        raise RuntimeError("os.execv failed")

    log_path = state_dir / f"bootstrap-{args.port}.log"
    info(f"Starting Hermes Web UI on http://{args.host}:{args.port}")
    with log_path.open("ab") as log_file:
        proc = subprocess.Popen([python_exe, server_path], cwd=server_cwd, env=os.environ.copy(), stdout=log_file, stderr=subprocess.STDOUT, start_new_session=True)

    health_url = f"http://{args.host}:{args.port}/health"
    if not wait_for_health(health_url):
        raise RuntimeError(f"Web UI unhealthy. Check {log_path}")

    app_url = f"http://{args.host}:{args.port}"
    info(f"Web UI is ready: {app_url}")
    info(f"Log file: {log_path}")
    if not args.no_browser:
        open_browser(app_url)
    return 0

if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"[bootstrap] ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
