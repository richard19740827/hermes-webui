#!/usr/bin/env bash
set -euo pipefail

# Thin local wrapper: keep the terminal attached while delegating all startup
# policy (env loading, agent discovery, dependency checks, state path setup,
# and final server exec) to bootstrap.py.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "${HERMES_WEBUI_PYTHON:-}" ]]; then
  PYTHON="${HERMES_WEBUI_PYTHON}"
elif command -v python3 >/dev/null 2>&1; then
  PYTHON="$(command -v python3)"
elif command -v python >/dev/null 2>&1; then
  PYTHON="$(command -v python)"
else
  echo "[start] Python 3 is required to run bootstrap.py" >&2
  exit 1
fi

echo "[start] Delegating startup to bootstrap.py --foreground"
exec "${PYTHON}" "${REPO_ROOT}/bootstrap.py" --foreground "$@"
