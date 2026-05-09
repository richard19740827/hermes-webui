#!/usr/bin/env bash
set -euo pipefail

# 1. 定義透明家園的根路徑 (對齊您的 .env)
HERMES_HOME="${HERMES_HOME:-$HOME/Hermes_Gion_Core}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PATH="${HERMES_HOME}/venv"

# 2. 自動載入您的全透明設定
if [[ -f "${REPO_ROOT}/.env" ]]; then
  set -a
  source "${REPO_ROOT}/.env"
  set +a
  echo "[OK] 已載入透明家園配置 (.env)"
fi

# 3. 智慧路徑偵測：優先使用透明家園裡的虛擬環境
if [[ -f "${VENV_PATH}/bin/python" ]]; then
  PYTHON="${VENV_PATH}/bin/python"
  echo "[OK] 使用透明環境啟動: ${VENV_PATH}"
else
  # 如果還沒安裝，才去找系統 Python 來跑 bootstrap
  PYTHON="$(command -v python3 || command -v python)"
  echo "[!!] 尚未偵測到透明環境，準備進行首次引導..."
fi

# 4. 正式點火
# 如果環境已就緒，直接啟動 server.py；若未就緒，則跑 bootstrap.py
if [[ -f "${REPO_ROOT}/server.py" && "${PYTHON}" == *"venv"* ]]; then
  exec "${PYTHON}" "${REPO_ROOT}/server.py" "$@"
else
  exec "${PYTHON}" "${REPO_ROOT}/bootstrap.py" "$@"
fi
