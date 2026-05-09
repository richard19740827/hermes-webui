# 祇園守護者介面 (Hermes WebUI)

[Hermes 代理人](https://hermes-agent.nousresearch.com/) 是一個住在您設備中的聰明自主助手。它透過終端機或通訊軟體與您連結，它會記住學習到的內容，並且運行得越久，能力就越強。

這套 WebUI 是為該代理人設計的輕量級、深色主題網頁介面。
**功能完全對等** —— 凡是您在技術黑視窗（終端機）能做的事，都能在這個精美的網頁介面上完成。它不需要複雜的安裝步驟，也沒有冗餘的軟體框架。它是純粹的 Python 指令與最原始的網頁技術結晶，這代表它反應迅速且不浪費您的硬體效能。

**介面佈局：三欄式設計**
- **左側欄**：用於對話紀錄管理與導航。
- **中間區**：主要的對話聊天室。
- **右側欄**：工作區檔案瀏覽，讓您隨時查看 AI 處理的檔案。
所有的模型切換與工作區控制都在下方的**「輸入框頁尾」**，讓您在打字時一目了然。

<img width="2448" height="1748" alt="Hermes Web UI — three-panel layout" src="https://github.com/user-attachments/assets/6bf8af4c-209d-441e-8b92-6515d7a0c369" />

<table>
  <tr>
    <td width="50%" align="center">
      <img width="2940" height="1848" alt="Light mode with full profile support" src="https://github.com/user-attachments/assets/4ef3a59c-7a66-4705-b4e7-cb9148fe4c47" />
      <br /><sub>Light mode with full profile support</sub>
    </td>
    <td width="50%" align="center">
      <img alt="Customize your settings, configure a password" src="https://github.com/user-attachments/assets/941f3156-21e3-41fd-bcc8-f975d5000cb8" />
      <br /><sub>Customize your settings, configure a password</sub>
    </td>
  </tr>
</table>

<table>
  <tr>
    <td width="50%" align="center">
      <img alt="Workspace file browser with inline preview" src="docs/images/ui-workspace.png" />
      <br /><sub>Workspace file browser with inline preview</sub>
    </td>
    <td width="50%" align="center">
      <img alt="Session projects, tags, and tool call cards" src="docs/images/ui-sessions.png" />
      <br /><sub>Session projects, tags, and tool call cards</sub>
    </td>
  </tr>
</table>

This gives you nearly **1:1 parity with Hermes CLI from a convenient web UI** which you can access securely through an SSH tunnel from your Hermes setup. Single command to start this up, and a single command to SSH tunnel for access on your computer. Every single part of the web UI uses your existing Hermes agent and existing models, without requiring any additional setup.

---

## 為什麼選擇祇園守護者 (Gion Guardian)

大多數人工智慧工具在每次對話結束後都會「重置」。它們不記得您是誰、不記得您處理過的公益專案，也不了解您的工作慣例。導致您每次都要重新解釋、重複教導。

**祇園守護者（Hermes）** 則完全不同：它會跨會話保留背景資訊。它能在您離線時執行預定任務，且運行的時間越長，它就越熟悉您的環境，變得越聰明。它直接使用您在 M4 上的設定，無需繁瑣配置即可啟動。

###  是什麼讓它與眾不同？

- **持久記憶 (Persistent Memory)**：它擁有使用者配置檔案、代理筆記與技能系統。它會不斷學習您的環境，不需要您重複教導。
- **自動排程 (Self-hosted Scheduling)**：即使您離線，它也能執行預定的「定時任務」，並將結果傳送到您的手機、電子郵件或通訊軟體。
- **多平台連結**：同一個 AI 助手，您可以透過電腦終端機、網頁介面，甚至手機隨時聯繫。
- **自動進化的技能**：它能根據經驗自動編寫並儲存新技能，不需要安裝複雜的外掛。
- **不分品牌 (Provider-agnostic)**：它能同時支援 OpenAI、Google、Claude、DeepSeek 等各大模型，靈活切換。
- **指揮其他 AI**：它可以調動更強大的模型（如 Claude Code）來處理繁重的編碼任務，並將結果收回到自己的記憶中。
- **絕對自主 (Self-hosted)**：您的對話、您的記憶、您的硬體。這就是對您隱私與數據主權的最高承諾。

###  同類工具對比

| 功能特性 | 其他常見 AI | 專業開發工具 | **祇園守護者 (Hermes)** |
|---|---|---|---|
| **自動持久記憶** | ❌ 每次重置 | ⚠️ 部分支援 | ✅ **完整保留** |
| **自託管定時任務** | ❌ 無 | ❌ 無 | ✅ **完整支援** |
| **通訊軟體串接** | ⚠️ 需複雜設定 | ❌ 無 | ✅ **原生支援** |
| **自我改進技能** | ❌ 無 | ❌ 無 | ✅ **具備** |
| **數據自主權** | ❌ 存於雲端 | ✅ 存於本地 | ✅ **存於本地** |

## 完整安裝 (Mac 本地專屬)

### 第一步：打開 Mac 的「終端機 (Terminal)」，完整複製並貼上指令：

```bash
git clone https://github.com/richard19740827/hermes-webui.git
cd hermes-webui
python3 bootstrap.py
```

### 第二步：未來的日常啟動
當您完成第一次安裝後，未來每天想呼叫 AI 教授時，只需要進入資料夾並按下啟動開關：

```bash
cd hermes-webui
./start.sh
```

(啟動後，只要不關閉這個黑視窗，您的 AI 守護者就會持續在背景為您服務。)

###  自動引導程序將為您完成：
1. **自動偵測**：檢查您的 M4 Mac 是否已安裝 Hermes 代理人。
2. **環境建置**：自動準備好 Python 執行環境，您不需要手動安裝零件。
3. **健康檢查**：啟動網頁伺服器並確保運作正常。
4. **自動導航**：完成後自動幫您打開瀏覽器，進入「新手引導教學」。

---

##  自動偵測機制 (start.sh)

守護者的啟動腳本非常聰明，它會自動尋找以下零件：
- **大腦路徑**：自動尋找您的 `~/Hermes_Gion_Core/hermes-agent` 資料夾。
- **執行引擎**：自動定位 Python 的位置。
- **記憶目錄**：預設已鎖定為 `~/Hermes_Gion_Core/webui_history`。

---

## 環境開關 (Overrides)

如果您有特殊需求（例如想換個連接埠），可以在啟動時手動輸入開關：
- `HERMES_WEBUI_PORT=9000`：把網頁大門改到 9000 號。
- `HERMES_WEBUI_BOT_NAME`：為您的 AI 助手取個響亮的名字。

---

## 如何連線存取守護者？

根據您的所在位置，有三種簡單的存取方式：

### 1. 在本地主機 (Mac) 直接使用 (最推薦)
啟動後，在瀏覽器輸入 `http://localhost:8787` 即可開始對話。

### 2. 在區域網路使用：如手機/平板
只要行動裝置與主機連接相同 Wi-Fi，在行動裝置瀏覽器輸入主機的區網 IP (如 `http://192.168.x.x:8787`) 即可。
*(提示：本系統已預設開啟區域網路共享，您無需額外設定指令。)*

### 3. 出門在外遠端存取 (免 VPN 方案)
若您人在戶外，建議透過您的 **群暉 (Synology) NAS** 設定「反向代理」：
- **操作路徑**：群暉控制面板 > 登錄門戶 > 進階 > 反向代理伺服器。
- **優點**：全中文設定，支援 HTTPS 加密連線，手機無需安裝任何軟體。
- **核心設定**：將來源 `HTTPS:443` 轉接至目的端（Mac 主機）的 `HTTP:8787`，**請務必在「自訂標頭」中開啟 WebSocket 支援。**

---

## 手動啟動 (進階檢修)

如果您在啟動過程中遇到問題，或是想查看詳細的後台日誌，可以使用手動模式：

```bash
# 進入透明路徑中的大腦目錄
cd ~/Hermes_Gion_Core/hermes-agent

# 使用透明路徑中的環境與路徑啟動伺服器
~/Hermes_Gion_Core/hermes-agent/venv/bin/python ~/Hermes_Gion_Core/hermes-webui/server.py

## 核心功能 (Features)

### 對話與智慧助手 (Chat and Agent)
- **即時串流響應**：對話像打字一樣即時顯示，不需要等待整個段落生成。
- **多模型支持**：支持 OpenAI、Google (Gemini)、Claude、DeepSeek 等主流模型，隨時切換。
- **消息隊列**：在 AI 思考時，您可以繼續傳送下一條訊息，它會自動排隊處理。
- **歷史修正**：您可以直接修改過去的訊息，AI 會從該點重新開始對話。
- **思考過程顯示**：支持顯示 AI 的「推理過程」（例如 O3 或 Claude 的思考區塊），讓您知道它是怎麼想的。
- **內建繪圖功能**：自動渲染 Mermaid 流程圖、序列圖與甘特圖。
- **工具調用卡片**：當 AI 使用搜尋、讀取檔案等工具時，會以簡潔的卡片顯示進度與結果。
- **安全性審核**：執行危險的指令（如刪除檔案）前，會彈出卡片請求您的批准。

### 會話紀錄管理 (Sessions)
- **不遺忘的記憶**：所有的對話都會自動存檔，支持更名、搜尋、釘選與分類。
- **專案與標籤**：可以使用 #標籤 來分類您的公益項目，方便快速檢索。
- **CLI 橋接器**：如果您以前用過黑視窗 (Terminal) 版本，這裡會自動同步那些舊的紀錄。
- **數據導出**：支持將對話導出為 Markdown 格式（方便寫文章）或 JSON 格式（方便備份）。

### 工作空間檔案瀏覽 (Workspace)
- ** Finder 式體驗**：直接在瀏覽器中查看您的 Mac 檔案夾，支持點擊展開與導航。
- **在線預覽與編輯**：直接查看程式碼、文本、Markdown 甚至圖片，並能直接在網頁修改。
- **Git 狀態顯示**：如果您在做網頁開發，它會顯示目前的代碼分支與修改數量。

### 語音與身分 (Voice and Profiles)
- **語音輸入**：內建麥克風按鈕，點擊即可對話，支持自動斷句（目前僅限支持的瀏覽器）。
- **身分切換 (Profiles)**：您可以為 AI 設定不同的「身分」（例如：公益秘書、技術顧問），切換身分時會同步切換記憶與規則。

### 安全與外觀 (Security and Themes)
- **密碼保護**：可選的登入密碼功能，確保即使您在手機上遙控，別人也進不去。
- **豐富主題**：內建 7 種主題，包括「純黑 OLED」護眼模式。
- **斜槓指令 (Slash Commands)**：在輸入框打 `/` 即可快速執行功能，如 `/help`、`/clear` 或 `/theme`。

### 專門控制面板 (Panels)
- **定時任務 (Tasks)**：管理您的自動化腳本，設定 AI 在特定時間執行公益任務。
- **技能系統 (Skills)**：查看 AI 已經學會的技能，並能直接編輯其運作邏輯。
- **核心記憶 (Memory)**：直接編輯 `MEMORY.md` 與 `USER.md`。這是 AI 永遠記住「您是誰」以及「您的公益目標」的核心文件。

---

##  系統架構：家園的零件清單

為了讓系統保持清淨、透明，我們將零件分為以下幾個核心區塊：

### 1. 後台大腦 (api/ 資料夾) —— 負責思考與邏輯
- `server.py`：**大門守衛**，負責處理所有的網路連線請求。
- `auth.py`：**保險櫃鎖**，負責您的密碼與安全性。
- `config.py`：**記憶管家**，負責偵測您的模型與設定檔。
- `streaming.py`：**對話流水**，負責讓 AI 說話像流水一樣順暢地顯示。
- `workspace.py`：**檔案工頭**，負責管理您在 Finder 看到的那些檔案。

### 2. 前台皮囊 (static/ 資料夾) —— 您看到的網頁介面
- `index.html`：**房屋骨架**。
- `style.css`：**裝潢設計**，決定了深色主題或 OLED 護眼模式。
- `ui.js` & `messages.js`：**動作行為**，處理您點擊按鈕、傳送訊息的反應。

### 3. 數據落腳處 (State)
- **記憶不遺忘**：預設存放在 `~/Hermes_Gion_Core`。
- 這裡存著您的會話紀錄、設定檔與工作空間，即使您更新了程式碼，這些「生命之書」的內容也不會消失。

---

##  開發指南 (Docs)

如果您想更深入研究這座腳架，可以翻閱這些文件：
- `HERMES.md`：為什麼選擇此系統與同類工具的深度對比。
- `ROADMAP.md`：未來的開發藍圖與計畫。
- `ARCHITECTURE.md`：更詳細的技術架構與數據接口說明。
- `THEMES.md`：如何客製化您喜歡的網頁外觀。

---

##  頂尖貢獻者排行榜 (依修改次數)

這份清單記錄了最常來幫我們修繕家園的數位志工：

| 排名 | 貢獻者 | 修改次數 | 活躍時間 |
|---|---|---:|---|
| 1 | [@franksong2702] | 22 次 | 最勤奮，優化了介面各種細節 |
| 2 | [@bergeouss] | 18 次 | 強化了 Docker 與後台管理 |
| 3 | [@aronprins] | 8 次 | 系統大翻修的首席設計師 |
| 4 | [@iRonin] | 6 次 | 安全性守護神 |

*查看 [`CONTRIBUTORS.md`](CONTRIBUTORS.md) 了解完整的 66 位志工名單。*

### 顯著貢獻者 (致謝)

這座守護者家園能有今天的樣貌，要感謝全球 66 位志工的無私奉獻。以下是幾位關鍵的建築師：

- **[@aronprins]** — **介面大翻修**：他重新設計了輸入框與控制面板，讓系統變得更直觀，這也是您現在看到的美麗外貌。
- **[@iRonin]** — **安全性加固**：他進行了六次重大的安全升級，包含防止數據洩漏與加密通訊，讓這套「自託管」系統變得真正安全可靠。
- **[@DavidSchuchert]** — **多語系支持**：他完善了翻譯系統，這也是我們現在能將它「中文化」的技術基石。
- **[@Jordan-SkyLF]** — **對話恢復與記憶強化**：他開發了讓對話在斷線後能自動找回的技術，確保您的「生命之書」不會因為網頁重新整理而中斷。

### 功能與特性貢獻

- **[@franksong2702]** — **最勤奮的守護者**：貢獻了 22 次修改，優化了移動端佈局與工作區導航，讓您在手機上也能流暢使用。
- **[@Argonaut790]** — **繁體中文支持**：他親手為我們準備了繁體中文的翻譯包，讓這座家園對我們來說不再陌生。
- **[@kevin-ho]** — **護眼黑漆 (OLED 主題)**：專門為 OLED 螢幕設計了純黑主題，減少耗電也保護您的眼睛。
- **[@gabogabucho]** — **新手引導精靈**：設計了第一次啟動時的導引畫面，降低了大家進入 AI 世界的門檻。

### 錯誤修復與安全防護

- **[@Hinotoi-agent]**：修復了不同帳號間的秘密洩漏問題，確保隱私。
- **[@lawrencel1ng]**：系統性地掃描並修復了多處代碼漏洞，讓系統更健壯。
- **[@shaoxianbilly]**：修復了中文、日文檔名下載時會亂碼或當機的問題。
- **[@zenc-cp]**：增加了「反幻覺」機制，防止 AI 隨口胡說八道，確保資訊的真實性。

---

## 參與貢獻
如果您也想為「祇園守護者」出一份力，歡迎查看 ARCHITECTURE.md 了解我們的建築藍圖。最好的貢獻就是解決一個真實存在的問題。
儲存庫連結

## 儲存庫連結
```bash
git@github.com:richard19740827/hermes-webui.git
