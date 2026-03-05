# 模型資料夾說明（請務必閱讀）

此資料夾在 Git 內應保持幾乎空白，模型檔禁止提交。

## 為什麼不能提交

- `weights.bin` 體積大且機器綁定，不適合進入 Git 歷史
- 模型版本可能依本機 Chrome 環境不同而不同

## 來源在哪裡（本機）

預設來源根目錄：

`%LOCALAPPDATA%\Google\Chrome\User Data\OptGuideOnDeviceModel\<version>`

`<version>` 會是版本資料夾，例如 `2025.8.8.1141`。

## 要放到哪裡（本專案）

請放到：

`model/<version>/`

應包含檔案：

- `model/<version>/weights.bin`
- `model/<version>/manifest.json`
- `model/<version>/on_device_model_execution_config.pb`
- `model/<version>/_metadata/verified_contents.json`

## 建議做法（自動匯入）

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Import-OptGuideModel.ps1
```

或手動指定來源：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Import-OptGuideModel.ps1 -SourceVersionDir "C:\Path\To\OptGuideOnDeviceModel\<version>"
```

## 提交前檢查

```powershell
git status --short
git check-ignore -v model\2025.8.8.1141\weights.bin
```

若模型檔出現在 `git status`，請先停止提交並修正忽略規則。
