# Hermes WebUI — canonical Docker 設定

main branch 只有一個支援的 Docker install source：root 的 `docker-compose.yml`。
這是 single-container、單人本地使用的 canonical flow。文件目標是可理解、可回溯、可手動修復、可 rollback，而不是建立新的 Docker 架構。

`archive/docker/` 內的 two-container / three-container Compose files 只作 historical reference。它們不支援、不作 install source，也不應用於 main branch 安裝。

## 5 分鐘 quickstart

```bash
git clone https://github.com/richard19740827/hermes-webui.git
cd hermes-webui
cp .env.docker.example .env
# macOS 請編輯 .env，設定 UID=$(id -u) 與 GID=$(id -g)
docker compose up -d
open http://localhost:8787
```

canonical compose file 會把 WebUI publish 到 `127.0.0.1:8787`，預設只供本機使用。container 內部仍使用 `0.0.0.0:8787`，讓 Docker port forwarding 正常運作。

## canonical compose file

只使用：

- [`../docker-compose.yml`](../docker-compose.yml) — single-container canonical Docker Compose file

不要把 archived Compose variants 當成 install source。它們只保留作歷史參考：

- [`../archive/docker/docker-compose.two-container.yml`](../archive/docker/docker-compose.two-container.yml)
- [`../archive/docker/docker-compose.three-container.yml`](../archive/docker/docker-compose.three-container.yml)

## 本機路徑

canonical compose file 使用這些預設值：

| Host path | Container path | 用途 |
|---|---|---|
| `${HERMES_HOME:-${HOME}/Hermes_Gion_Core}` | `/home/hermeswebui/.hermes` | Hermes config、sessions、credentials、WebUI state |
| `${HERMES_WORKSPACE:-${HOME}/Hermes_Gion_Core/Public_Welfare_Project}` | `/workspace` | WebUI 內看到的 workspace |

container 內的 canonical WebUI state path 是：

```text
/home/hermeswebui/.hermes/webui_history
```

因為 `/home/hermeswebui/.hermes` 來自 `HERMES_HOME` bind mount，所以 host 上對應：

```text
${HERMES_HOME:-${HOME}/Hermes_Gion_Core}/webui_history
```

## macOS UID/GID 設定

macOS 使用既有 Hermes home 做 bind mount 時，請在 `.env` 中設定 `UID` 與 `GID`，讓 container 使用與 host 相同的使用者身份讀寫檔案：

```bash
echo "UID=$(id -u)" >> .env
echo "GID=$(id -g)" >> .env
docker compose down && docker compose up -d
```

macOS 的 UID 常見從 `501` 開始；Linux 第一個互動使用者常見是 `1000`。請以 `id -u` / `id -g` 的實際輸出為準。

## 本地 Docker + Ollama

本地 Docker + Ollama 情境下，Ollama 留在 host 執行；Hermes 的設定、credentials 與狀態放在 mounted `HERMES_HOME`。這個 repo 仍只支援一個 WebUI container。

## 安全提醒

canonical compose file 預設只 expose localhost。如果您刻意把 WebUI 暴露到 `127.0.0.1` 以外，請先在 `.env` 設定強密碼 `HERMES_WEBUI_PASSWORD`。

Docker image 以單人本地 container threat model 設計。啟動時只在狹窄的 bind-mount 準備階段使用 root，之後以非特權 runtime user 執行 WebUI；不要把它當成多租戶雲端服務邊界。

## 常見手動修復

### 啟動時 Permission denied

如果 container 啟動後在 `/home/hermeswebui/.hermes` 出現 permission error，通常是 host 檔案 owner 與 container UID/GID 不一致。請設定 `.env` 後重啟：

```bash
echo "UID=$(id -u)" >> .env
echo "GID=$(id -g)" >> .env
docker compose down && docker compose up -d
```

### WebUI health check

```bash
curl http://127.0.0.1:8787/health
```

WebUI ready 後應回報 `status` 為 `ok`。

### 查看 logs

```bash
docker compose logs --tail=200 hermes-webui
```

### 乾淨 rollback

```bash
docker compose down --volumes --remove-orphans
```

## 本地治理檢查

repo 提供兩個本機腳本，方便單人長期維護：

```bash
./scripts/validate.sh
./scripts/smoke.sh
```

- `scripts/validate.sh`：檢查 repo governance、Python syntax、canonical compose render、root 是否只有 canonical compose、startup wrapper 是否走 `bootstrap.py`。
- `scripts/smoke.sh`：用 temporary `HERMES_HOME`、temporary `HERMES_WORKSPACE`、unique `COMPOSE_PROJECT_NAME` 啟動 canonical Docker runtime，驗證 `/health`、state dir、workspace mount、logs，最後 rollback 並確認沒有 orphan containers。

## archive policy

`archive/` 不是 install source。

- 只作 historical reference
- not supported
- 不屬於 main branch canonical flow
- 不保證能與目前 runtime 行為相容

詳見 [`../archive/README.md`](../archive/README.md)。
