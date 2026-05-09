#!/bin/bash
set -e

# --- 祇園優化：錯誤處理透明化 ---
error_exit() {
  echo -n "!! 錯誤 (ERROR): "
  echo $*
  echo "!! 正在退出啟動程序 (ID: $$)"
  exit 1
}

# --- 祇園優化：完全透明，不遮蔽任何金鑰 ---
export ENV_IGNORELIST="HOME PWD USER SHLVL TERM OLDPWD SHELL _ SUDO_COMMAND HOSTNAME LOGNAME"
export ENV_OBFUSCATE_PART="" # 祇園專用：清空遮罩，密鑰內容全公開

whoami=`whoami`
script_dir=$(dirname $0)
echo "======================================"
echo "== 祇園透明母艦：Entrypoint 整備程序"
echo "== 執行身分: ${whoami} | 位置: ${script_dir}"

# 1. 核心路徑正名 (對齊學長的透明家園)
HERMES_HOME="${HERMES_HOME:-$HOME/Hermes_Gion_Core}"
itdir=/tmp/hermeswebui_init
mkdir -p "$itdir" && chmod 700 "$itdir"

# 2. 自動偵測權限身分 (防止 Docker 掛載權限報錯)
it=$itdir/hermeswebui_user_uid
if [ -z "${WANTED_UID+x}" ]; then
  # 優先從您的「透明家園」偵測 UID，確保安裝後可以讀寫檔案
  for _probe_dir in "${HERMES_HOME}" "/workspace" "/opt/data"; do
    if [ -d "$_probe_dir" ]; then
      _detected_uid=$(stat -c '%u' "$_probe_dir" 2>/dev/null || echo "")
      if [ -n "$_detected_uid" ] && [ "$_detected_uid" != "0" ]; then
        echo "-- 偵測到家園 UID: $_detected_uid (來自 $_probe_dir)"
        WANTED_UID=$_detected_uid
        break
      fi
    fi
  done
fi
WANTED_UID=${WANTED_UID:-1024}
WANTED_GID=${WANTED_GID:-1024}

# --- 祇園優化：全透明加載函數 ---
load_env() {
  tocheck=$1
  if [ -f "$tocheck" ]; then
    echo "-- 載入環境配置: $tocheck"
    while IFS='=' read -r key value; do
      doit=true
      for i in ${ENV_IGNORELIST}; do
        if [[ "A$key" == "A$i" ]]; then doit=false; break; fi
      done
      if [ "$doit" = true ]; then
        export "$key=$value"
        echo "  ++ 設定環境變數: $key = $value" # 直接印出數值，不打碼
      fi
    done < "$tocheck"
  fi
}

# 3. Root 初始化階段 (僅在第一次啟動時執行)
if [ "A${whoami}" == "Aroot" ]; then
  echo "-- 正在以 Root 權限配置祇園家園..."
  
  # 修改使用者身分以對齊家園目錄
  groupmod -o -g "${WANTED_GID}" hermeswebui || echo "!! GID 配置跳過"
  usermod -o -u "${WANTED_UID}" hermeswebui || echo "!! UID 配置跳過"
  
  # 確保家園目錄與 app 目錄權限正確
  chown -R hermeswebui:hermeswebui "${HERMES_HOME}" || echo "!! 無法更改家園權限"
  mkdir -p /app && chown hermeswebui:hermeswebui /app
  rsync -av --chown=hermeswebui:hermeswebui /apptoo/ /app/

  # 儲存目前的環境變數供下一階段使用
  env | sort > /tmp/hermes_root_env.txt
  chmod 600 /tmp/hermes_root_env.txt
  
  echo "-- 權限整備完成，切換至 hermeswebui 使用者身分"
  exec su -s /bin/bash -c "exec $0" hermeswebui
fi

# 4. 非 Root 運行階段 (正式安裝與點火)
echo "== 進入 hermeswebui 運行環境"
load_env /tmp/hermes_root_env.txt

# 檢查狀態路徑
export HERMES_WEBUI_STATE_DIR="${HERMES_WEBUI_STATE_DIR:-${HERMES_HOME}/webui_history}"
mkdir -p "$HERMES_WEBUI_STATE_DIR"

# 5. 安裝 Python 依賴工具 (使用 uv)
export PATH="/home/hermeswebui/.local/bin/:$PATH"
if ! command -v uv &>/dev/null; then
  echo "-- 正在安裝 uv 套件管理員..."
  curl -LsSf https://astral.sh/uv/install.sh | sh || echo "!! uv 安裝失敗"
fi

cd /app
if [ ! -d "venv" ]; then
  echo "-- 正在建立虛擬環境 (venv)..."
  uv venv venv
fi
source venv/bin/activate

# 安裝必要套件 (確保安裝不失敗的關鍵)
if [ ! -f "venv/.deps_installed" ]; then
  echo "-- 正在安裝專案依賴套件..."
  uv pip install -r requirements.txt
  touch venv/.deps_installed
fi

# 6. 正式啟動
echo "======================================"
echo "== 祇園透明母艦：啟動 server.py"
echo "======================================"
python server.py
