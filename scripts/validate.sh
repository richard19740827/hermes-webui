#!/bin/sh
# Validate Hermes WebUI repository governance without CI/task-runner dependencies.
# POSIX shell only; dependencies are limited to git, python3, curl, and docker compose.

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
FAIL_MESSAGES=""
WARN_MESSAGES=""

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf 'PASS: %s\n' "$1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf 'FAIL: %s\n' "$1"
    FAIL_MESSAGES="${FAIL_MESSAGES}
- $1"
}

warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    printf 'WARN: %s\n' "$1"
    WARN_MESSAGES="${WARN_MESSAGES}
- $1"
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

check_clean_tree() {
    if ! have_cmd git; then
        fail "git is required to verify that the working tree is clean"
        return
    fi

    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        fail "git working tree is not clean"
    else
        pass "git working tree is clean"
    fi
}

check_required_commands() {
    if have_cmd python3; then
        pass "python3 is available"
    else
        fail "python3 is required"
    fi

    if have_cmd curl; then
        pass "curl is available"
    else
        fail "curl is required"
    fi

    if have_cmd docker && docker compose version >/dev/null 2>&1; then
        pass "docker compose is available"
    else
        fail "docker compose is required"
    fi
}

check_python_syntax() {
    if ! have_cmd python3; then
        fail "cannot check Python syntax because python3 is missing"
        return
    fi

    files=""
    for path in server.py bootstrap.py mcp_server.py api/*.py scripts/*.py; do
        if [ -f "$path" ]; then
            files="$files $path"
        fi
    done

    if [ -z "$files" ]; then
        fail "no Python files found for syntax check"
        return
    fi

    # shellcheck disable=SC2086 # intentional word splitting over repository file list
    if python3 - $files <<'PYEOF'
import sys

ok = True
for filename in sys.argv[1:]:
    try:
        with open(filename, "rb") as handle:
            source = handle.read()
        compile(source, filename, "exec")
    except SyntaxError as exc:
        ok = False
        print(f"{filename}:{exc.lineno}:{exc.offset}: {exc.msg}", file=sys.stderr)
    except OSError as exc:
        ok = False
        print(f"{filename}: {exc}", file=sys.stderr)

raise SystemExit(0 if ok else 1)
PYEOF
    then
        pass "Python syntax check passed"
    else
        fail "Python syntax check failed"
    fi
}

check_compose_render() {
    if ! have_cmd docker || ! docker compose version >/dev/null 2>&1; then
        fail "cannot render compose YAML because docker compose is missing"
        return
    fi

    if [ ! -f docker-compose.yml ]; then
        fail "docker-compose.yml is missing"
        return
    fi

    if docker compose -f docker-compose.yml config >/dev/null; then
        pass "docker-compose.yml renders successfully"
    else
        fail "docker-compose.yml does not render"
    fi
}

check_duplicate_env() {
    if [ ! -f docker-compose.yml ]; then
        fail "cannot check duplicate env because docker-compose.yml is missing"
        return
    fi

    duplicates=$(
        awk '
            /^[[:space:]]*#/ { next }
            /^[^[:space:]][^:]*:/ {
                if ($1 == "services:") {
                    in_services = 1
                } else if (in_services) {
                    in_services = 0
                    service = ""
                    in_env = 0
                }
                next
            }
            in_services && /^  [^[:space:]#][^:]*:/ {
                line = $0
                sub(/^  /, "", line)
                sub(/:.*/, "", line)
                service = line
                in_env = 0
                next
            }
            service != "" && /^    [^[:space:]#][^:]*:/ {
                line = $0
                sub(/^    /, "", line)
                key = line
                sub(/:.*/, "", key)
                if (key == "environment") {
                    in_env = 1
                } else {
                    in_env = 0
                }
                next
            }
            service != "" && in_env && /^      -[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=/ {
                line = $0
                sub(/^      -[[:space:]]*/, "", line)
                key = line
                sub(/=.*/, "", key)
                id = service ":" key
                if (seen[id] == 1) {
                    print id
                }
                seen[id] = 1
            }
        ' docker-compose.yml | sort -u
    )

    if [ -n "$duplicates" ]; then
        fail "docker-compose.yml has duplicate environment variables: $(printf '%s' "$duplicates" | tr '\n' ' ')"
    else
        pass "docker-compose.yml has no duplicate environment variables"
    fi
}

check_placeholder_password() {
    matches=$(
        awk '
            /^[[:space:]]*#/ { next }
            /HERMES_WEBUI_PASSWORD[[:space:]]*=[[:space:]]*(your-secret-password|change-me|changeme|password|secret|example|placeholder)/ {
                print FILENAME ":" FNR
            }
        ' docker-compose.yml .env.example .env.docker.example 2>/dev/null
    )

    if [ -n "$matches" ]; then
        fail "placeholder HERMES_WEBUI_PASSWORD is enabled: $(printf '%s' "$matches" | tr '\n' ' ')"
    else
        pass "no enabled placeholder HERMES_WEBUI_PASSWORD found"
    fi
}

check_no_root_compose_variants() {
    variants=""

    for path in docker-compose.*.yml docker-compose.*.yaml compose.*.yml compose.*.yaml; do
        case "$path" in
            'docker-compose.*.yml'|'docker-compose.*.yaml'|'compose.*.yml'|'compose.*.yaml')
                continue
                ;;
            docker-compose.yml|compose.yml)
                continue
                ;;
        esac

        if [ -f "$path" ]; then
            variants="${variants} ${path}"
        fi
    done

    if [ -n "$variants" ]; then
        fail "root contains compose variants:${variants}"
    else
        pass "root contains no extra compose variants; archive/ is ignored"
    fi
}

check_start_uses_bootstrap() {
    if [ ! -f start.sh ]; then
        fail "start.sh is missing"
        return
    fi

    direct_server=$(
        awk '
            /^[[:space:]]*#/ { next }
            /(^|[[:space:]])exec[[:space:]].*server\.py/ { print FNR }
            /(^|[[:space:]])python3?[[:space:]].*server\.py/ { print FNR }
        ' start.sh
    )

    if [ -n "$direct_server" ]; then
        fail "start.sh directly executes server.py at line(s): $(printf '%s' "$direct_server" | tr '\n' ' ')"
        return
    fi

    if awk 'BEGIN { found = 0 } /^[[:space:]]*#/ { next } /bootstrap\.py/ { found = 1 } END { exit found ? 0 : 1 }' start.sh; then
        pass "start.sh launches through bootstrap.py"
    else
        fail "start.sh does not launch through bootstrap.py"
    fi
}

check_ctl_uses_bootstrap() {
    if [ ! -f ctl.sh ]; then
        fail "ctl.sh is missing"
        return
    fi

    if awk 'BEGIN { found = 0 } /^[[:space:]]*#/ { next } /bootstrap\.py/ { found = 1 } END { exit found ? 0 : 1 }' ctl.sh; then
        pass "ctl.sh startup path references bootstrap.py"
    else
        fail "ctl.sh startup path does not reference bootstrap.py"
    fi
}

print_summary() {
    printf '\nValidation summary\n'
    printf '==================\n'
    printf 'PASS: %s\n' "$PASS_COUNT"
    printf 'WARN: %s\n' "$WARN_COUNT"
    printf 'FAIL: %s\n' "$FAIL_COUNT"

    if [ "$WARN_COUNT" -gt 0 ]; then
        printf '\nWarnings:%s\n' "$WARN_MESSAGES"
    fi

    if [ "$FAIL_COUNT" -gt 0 ]; then
        printf '\nFailures:%s\n' "$FAIL_MESSAGES"
        printf '\nFAIL\n'
        return 1
    fi

    printf '\nPASS\n'
    return 0
}

check_clean_tree
check_required_commands
check_python_syntax
check_compose_render
check_duplicate_env
check_placeholder_password
check_no_root_compose_variants
check_start_uses_bootstrap
check_ctl_uses_bootstrap

print_summary
