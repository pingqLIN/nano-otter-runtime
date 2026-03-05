<p align="center">
  <img src="nano-otter-runtime.png" alt="nano-otter-runtime banner" width="100%">
</p>

# Gemini Nano Local Starter

> **[English Version](README.md)**

將本機 Chrome 的 Gemini Nano（OptGuide On-Device Model）整理成可重複啟動、可驗證、可分享的專案模板。

## 事件背景

近年，有資安研究者公開揭露：Google Chrome PC 版會在**未通知使用者**的情況下，靜默下載約 **4 GB** 的 AI 模型檔案（`weights.bin`），存放於：

```text
%LOCALAPPDATA%\Google\Chrome\User Data\OptGuideOnDeviceModel\
```

經分析確認，該檔案正是 **Gemini Nano**——Chrome 用於驅動內建 AI API（Prompt API）的本機推論模型。由於檔案設為唯讀，就算手動刪除，Chrome 仍會自動重新下載。

此行為曝光後引發社群廣泛討論，Google 亦未就此公開正式回應。

> **本專案的出發點**：既然模型已經在你硬碟裡，不如把它用好——在受控環境下啟動、驗證、並實際對話測試，而非讓它靜默佔用空間。

## 截圖預覽

<p align="center">
  <img src="screenshot-menu.png" alt="終端機選單" width="48%">&nbsp;
  <img src="screenshot-chat.png" alt="聊天測試介面" width="48%">
</p>
<p align="center"><sub>左：互動式終端機選單 &nbsp;｜&nbsp; 右：聊天測試介面</sub></p>

## 功能摘要

- 匯入本機模型包（`weights.bin` + metadata）
- 檢查模型完整性與 SHA256
- 啟動獨立 Chrome Profile（不污染日常資料）
- 自動開啟聊天測試頁（含 Echo fallback）
- 提供選單與導覽頁，降低初次使用的操作門檻

## 路徑常態化規則

本專案已統一路徑策略，避免機器綁定。

1. 文件一律使用專案相對路徑，例如 `scripts/Import-OptGuideModel.ps1`、`probe/chat-window.html`。
2. 腳本輸入支援相對路徑與絕對路徑，執行時會自動轉為絕對路徑。
3. 預設模型來源改為自動偵測：
   `%LOCALAPPDATA%\Google\Chrome\User Data\OptGuideOnDeviceModel\<latest_version>`
4. Probe HTTP Port 不再依賴固定值，會自動選可用埠並顯示實際網址。
5. HTTP 模式下，啟動頁必須位於 `probe/` 目錄內，確保 URL 與本機伺服器路徑一致。

## 快速開始

1. 在專案根目錄執行 `start.cmd`。
2. 選擇 `5`（Import -> Check -> Start），或依序執行 `1`、`2`、`3`。
3. 開啟終端機輸出的網址：`http://localhost:<port>/chat-window.html`。

## 模型檔案

模型檔（特別是 `weights.bin`）必須只留在本機，不可提交到任何 Git commit。

本專案已透過 `.gitignore` 忽略以下路徑：

- `model/**`
- 僅保留 `model/.gitkeep` 與 `model/README.md` 追蹤

### 模型取得來源（本機）

1. 來源資料夾在本機 Chrome 使用者資料內：
   `%LOCALAPPDATA%\Google\Chrome\User Data\OptGuideOnDeviceModel\<version>`
2. `<version>` 例如 `2025.8.8.1141`，可有多個版本資料夾。

### 模型放置位置（本專案）

請放在：

`model/<version>/`

至少應包含：

- `model/<version>/weights.bin`
- `model/<version>/manifest.json`
- `model/<version>/on_device_model_execution_config.pb`
- `model/<version>/_metadata/verified_contents.json`

### 建議操作（自動匯入）

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Import-OptGuideModel.ps1
```

或指定來源：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Import-OptGuideModel.ps1 -SourceVersionDir "C:\Path\To\OptGuideOnDeviceModel\<version>"
```

### 提交前檢查（避免誤上傳）

```powershell
git status --short
git check-ignore -v model\2025.8.8.1141\weights.bin
```

若 `git status` 顯示 `model/<version>/weights.bin`，請中止提交並確認 `.gitignore` 設定是否正確。

## 模式判讀

- `Model mode`：已偵測可用模型 API，回覆來自本機模型。
- `Echo mode`：目前未偵測到可用模型 API，先用 Echo 驗證輸入輸出流程。

若顯示 `Echo mode`，請依序確認：

1. 重新執行 `start.cmd`，透過專案腳本重啟 Chrome。
2. 確認網址格式為 `http://localhost:<port>/chat-window.html`（不可使用 `file://` 開啟）。
3. 若問題持續，請開啟 `probe/prompt-api-probe.html` 進一步診斷 API 路徑。

## 主要檔案

- `start.cmd`：Windows 一鍵入口
- `Start-QuickStart.ps1`：選單啟動入口
- `scripts/QuickStart-UI.ps1`：互動選單流程
- `scripts/Import-OptGuideModel.ps1`：匯入模型包
- `scripts/Check-ModelPack.ps1`：檢查模型完整性
- `scripts/Start-GeminiNanoChrome.ps1`：啟動 Chrome + 測試頁
- `scripts/Export-GitHubRepo.ps1`：匯出乾淨 repo
- `probe/chat-window.html`：聊天測試頁
- `probe/prompt-api-probe.html`：Prompt API 探測頁
- `guide/index.html`：圖文操作導覽

## 手動命令（進階）

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Import-OptGuideModel.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\Check-ModelPack.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\Start-GeminiNanoChrome.ps1
```

如需手動提供模型來源：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Import-OptGuideModel.ps1 -SourceVersionDir "C:\Path\To\OptGuideOnDeviceModel\<version>"
```

## AI 輔助開發聲明

本專案在開發過程中使用 AI 工具輔助。

**使用的 AI 模型 / 服務：**

- Gemini 2.5 Pro（Google Antigravity）

> ⚠️ **免責聲明：** 雖然作者已盡力審查與驗證 AI 生成的內容，但無法保證其正確性、安全性或適用性。使用者需自行承擔風險。

## License

[MIT License](https://opensource.org/licenses/MIT)
