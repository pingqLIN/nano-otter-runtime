# Gemini Nano Local Starter

將本機 Chrome 的 Gemini Nano（OptGuide On-Device Model）整理成可重複啟動、可驗證、可分享的專案模板。

## 事件背景

2025 年，安全專家 **Zephyrianna** 在 X 平台揭露：Google Chrome PC 版會在**未通知使用者**的情況下，靜默下載約 **4 GB** 的 AI 模型檔案（`weights.bin`），存放於：

```text
%LOCALAPPDATA%\Google\Chrome\User Data\OptGuideOnDeviceModel\
```

經分析確認，該檔案正是 **Gemini Nano**——Chrome 用於驅動內建 AI API（Prompt API）的本機推論模型。由於檔案設為唯讀，就算手動刪除，Chrome 仍會自動重新下載。

此事件由香港科技媒體 [HKEPC](https://www.facebook.com/hkepc/posts/pfbid02CKkYaqJoHQQLRjPPAfohQWHmWMqCgpMxTjr257K1d57GfinvxuAVMdHdbpCtPDyil) 及 [Winaero](https://winaero.com/) 報道，引發廣泛討論。

> **本專案的出發點**：既然模型已經在你硬碟裡，不如把它用好——在受控環境下啟動、驗證、並實際對話測試，而非讓它靜默佔用空間。

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

## 模型檔案（重要：禁止提交到 Git）

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

## 匯出 GitHub Repo

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Export-GitHubRepo.ps1
```

- 預設輸出：`<project_parent>\<project_name>-export`
- 可用 `-TargetDir` 指定輸出位置
- 目標路徑已存在時可加 `-Force` 覆蓋

## Git 忽略與檔案大小

- `model/**` 已忽略（避免推送大型模型檔）
- `.chrome-user-data/` 已忽略（本機執行快取）
- clone 後請先重新匯入模型包到 `model/<version>/`

## 操作導覽

- 開啟 `guide/index.html`
