$ErrorActionPreference = "Stop"
$scriptPath = Join-Path $PSScriptRoot "scripts\QuickStart-UI.ps1"
if (!(Test-Path -LiteralPath $scriptPath)) {
    throw "QuickStart script not found: $scriptPath"
}

& $scriptPath

