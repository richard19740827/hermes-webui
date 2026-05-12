#!/bin/sh
# Smoke-test the canonical local Docker runtime.
# POSIX shell only; requires docker compose and curl.

COMPOSE_FILE="docker-compose.yml"
SERVICE="hermes-webui"
HEALTH_URL="http://127.0.0.1:8787/health"
PROJECT_NAME="hermes-webui-smoke-$$"
COMPOSE_PROJECT_NAME="$PROJECT_NAME"
export COMPOSE_PROJECT_NAME
SMOKE_TMPDIR=""
HERMES_HOME=""
HERMES_WORKSPACE=""
STARTED=0
FAIL_COUNT=0
WARN_COUNT=0
PASS_COUNT=0
FAIL_MESSAGES=""
WARN_MESSAGES=""
CLEANUP_DONE=0

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf 'PASS: %s\n' "$1"
}

warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    printf 'WARN: %s\n' "$1"
    WARN_MESSAGES="${WARN_MESSAGES}
- $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf 'FAIL: %s\n' "$1" >&2
    FAIL_MESSAGES="${FAIL_MESSAGES}
- $1"
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

compose() {
    docker compose -f "$COMPOSE_FILE" "$@"
}

print_logs() {
    if have_cmd docker && docker compose version >/dev/null 2>&1 && [ -f "$COMPOSE_FILE" ]; then
        printf '\n--- recent compose logs (%s) ---\n' "$SERVICE" >&2
        compose logs --no-color --tail=200 "$SERVICE" >&2 || true
        printf '%s\n' '--- end compose logs ---' >&2
    fi
}

cleanup() {
    code=$?

    if [ "$CLEANUP_DONE" -eq 1 ]; then
        exit "$code"
    fi
    CLEANUP_DONE=1

    if have_cmd docker && docker compose version >/dev/null 2>&1 && [ -f "$COMPOSE_FILE" ]; then
        printf '\n[smoke] Rolling back compose project %s\n' "$COMPOSE_PROJECT_NAME"
        if compose down --volumes --remove-orphans; then
            pass "docker compose down --volumes --remove-orphans completed"
        else
            fail "docker compose down --volumes --remove-orphans failed"
        fi

        orphans=$(docker ps -a --filter "label=com.docker.compose.project=$COMPOSE_PROJECT_NAME" -q 2>/dev/null || true)
        if [ -n "$orphans" ]; then
            fail "orphan containers remain for project $COMPOSE_PROJECT_NAME: $(printf '%s' "$orphans" | tr '\n' ' ')"
        else
            pass "no orphan containers remain for project $COMPOSE_PROJECT_NAME"
        fi
    fi

    if [ -n "$SMOKE_TMPDIR" ]; then
        if rm -rf "$SMOKE_TMPDIR"; then
            pass "temporary smoke directory removed"
        else
            warn "could not remove temporary smoke directory: $SMOKE_TMPDIR"
        fi
    fi

    printf '\nSmoke summary\n'
    printf '=============\n'
    printf 'PASS: %s\n' "$PASS_COUNT"
    printf 'WARN: %s\n' "$WARN_COUNT"
    printf 'FAIL: %s\n' "$FAIL_COUNT"

    if [ "$WARN_COUNT" -gt 0 ]; then
        printf '\nWarnings:%s\n' "$WARN_MESSAGES"
    fi
    if [ "$FAIL_COUNT" -gt 0 ]; then
        printf '\nFailures:%s\n' "$FAIL_MESSAGES"
        printf '\nFAIL\n'
        exit 1
    fi

    printf '\nPASS\n'
    exit "$code"
}

trap cleanup EXIT INT TERM

require_cmds() {
    if have_cmd docker && docker compose version >/dev/null 2>&1; then
        pass "docker compose is available"
    else
        fail "docker compose is required"
    fi

    if have_cmd curl; then
        pass "curl is available"
    else
        fail "curl is required"
    fi

    if [ "$FAIL_COUNT" -gt 0 ]; then
        exit 1
    fi
}

check_canonical_compose() {
    if [ -f "$COMPOSE_FILE" ]; then
        pass "root docker-compose.yml exists"
    else
        fail "root docker-compose.yml is missing"
        exit 1
    fi

    if compose config >/dev/null; then
        pass "root docker-compose.yml renders"
    else
        fail "root docker-compose.yml does not render"
        exit 1
    fi
}

check_port_free() {
    if curl -fsS --max-time 2 "$HEALTH_URL" >/dev/null 2>&1; then
        fail "$HEALTH_URL already responds before smoke; stop the existing service before running smoke"
        exit 1
    fi
    pass "localhost:8787 is available for isolated smoke"
}

make_isolated_dirs() {
    base_tmp=${TMPDIR:-/tmp}
    i=0
    while [ "$i" -lt 20 ]; do
        candidate="$base_tmp/hermes-webui-smoke.$$.$i"
        if mkdir "$candidate" 2>/dev/null; then
            SMOKE_TMPDIR=$candidate
            break
        fi
        i=$((i + 1))
    done

    if [ -z "$SMOKE_TMPDIR" ]; then
        fail "could not create temporary smoke directory"
        exit 1
    fi

    HERMES_HOME="$SMOKE_TMPDIR/hermes-home"
    HERMES_WORKSPACE="$SMOKE_TMPDIR/workspace"
    mkdir -p "$HERMES_HOME" "$HERMES_WORKSPACE" || {
        fail "could not create isolated HERMES_HOME/HERMES_WORKSPACE"
        exit 1
    }

    export HERMES_HOME
    export HERMES_WORKSPACE

    pass "isolated HERMES_HOME created at $HERMES_HOME"
    pass "isolated HERMES_WORKSPACE created at $HERMES_WORKSPACE"
    pass "unique COMPOSE_PROJECT_NAME set to $COMPOSE_PROJECT_NAME"
}

start_runtime() {
    STARTED=1
    if compose up -d --build; then
        pass "docker compose up -d --build completed"
    else
        fail "docker compose up -d --build failed"
        print_logs
        exit 1
    fi
}

container_id() {
    compose ps -q "$SERVICE" 2>/dev/null || true
}

wait_for_container() {
    cid=""
    i=0
    while [ "$i" -lt 60 ]; do
        cid=$(container_id)
        if [ -n "$cid" ]; then
            pass "container exists"
            status=$(docker inspect -f '{{.State.Status}}' "$cid" 2>/dev/null || true)
            case "$status" in
                running)
                    pass "container is running"
                    break
                    ;;
                exited|dead)
                    fail "container exited before running"
                    print_logs
                    exit 1
                    ;;
            esac
        fi
        i=$((i + 1))
        sleep 2
    done

    if [ -z "$cid" ]; then
        fail "container was not created before timeout"
        print_logs
        exit 1
    fi

    status=$(docker inspect -f '{{.State.Status}}' "$cid" 2>/dev/null || true)
    if [ "$status" != "running" ]; then
        fail "container did not become running before timeout"
        print_logs
        exit 1
    fi

    i=0
    while [ "$i" -lt 60 ]; do
        status=$(docker inspect -f '{{.State.Status}}' "$cid" 2>/dev/null || true)
        health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$cid" 2>/dev/null || true)

        case "$status" in
            running)
                ;;
            exited|dead)
                fail "container exited while waiting for health"
                print_logs
                exit 1
                ;;
            *)
                fail "container status changed to $status while waiting for health"
                print_logs
                exit 1
                ;;
        esac

        case "$health" in
            healthy)
                pass "container health is healthy"
                return 0
                ;;
            none)
                warn "container has no Docker health status; continuing with HTTP health"
                return 0
                ;;
            unhealthy)
                fail "container health is unhealthy"
                print_logs
                exit 1
                ;;
            starting|"")
                ;;
            *)
                warn "container health status is $health; continuing with HTTP health"
                return 0
                ;;
        esac

        i=$((i + 1))
        sleep 2
    done

    warn "container health remained starting before timeout; continuing with HTTP health"
}

wait_for_http_health() {
    i=0
    while [ "$i" -lt 60 ]; do
        body=$(curl -fsS --max-time 3 "$HEALTH_URL" 2>/dev/null || true)
        case "$body" in
            *'"status"'*'"ok"'*)
                pass "$HEALTH_URL returned status ok"
                return 0
                ;;
        esac
        i=$((i + 1))
        sleep 2
    done

    fail "$HEALTH_URL did not return status ok before timeout"
    print_logs
    exit 1
}

check_state_dir() {
    if compose exec -T "$SERVICE" sh -c 'test -n "$HERMES_WEBUI_STATE_DIR" && test -d "$HERMES_WEBUI_STATE_DIR" && test -w "$HERMES_WEBUI_STATE_DIR"'; then
        pass "canonical state dir exists and is writable"
    else
        fail "canonical state dir is missing or not writable"
        print_logs
        exit 1
    fi
}

check_workspace_mount() {
    if compose exec -T "$SERVICE" test -d /workspace; then
        pass "workspace mount exists"
    else
        fail "workspace mount /workspace is missing"
        print_logs
        exit 1
    fi
}

check_logs() {
    log_output=$(compose logs --no-color "$SERVICE" 2>/dev/null)
    log_status=$?
    if [ "$log_status" -eq 0 ]; then
        pass "docker compose logs are available"
        if [ -z "$log_output" ]; then
            warn "docker compose logs are empty"
        fi
    else
        fail "docker compose logs are not available"
        exit 1
    fi
}

require_cmds
check_canonical_compose
check_port_free
make_isolated_dirs
start_runtime
wait_for_container
wait_for_http_health
check_state_dir
check_workspace_mount
check_logs

exit 0
