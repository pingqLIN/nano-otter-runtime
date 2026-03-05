param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$ModelVersion
)

$ErrorActionPreference = "Stop"

$modelRoot = Join-Path $ProjectRoot "model"
if (!(Test-Path -LiteralPath $modelRoot)) {
    throw "Model root not found: $modelRoot"
}

function Resolve-ModelDir {
    param([string]$Root, [string]$Version)
    if ($Version) {
        $byVersion = Join-Path $Root $Version
        if (Test-Path -LiteralPath $byVersion) { return (Resolve-Path -LiteralPath $byVersion).Path }
        throw "Model version folder not found: $byVersion"
    }

    $dirs = Get-ChildItem -LiteralPath $Root -Directory | Sort-Object Name -Descending
    if ($dirs.Count -gt 0) { return $dirs[0].FullName }

    if (Test-Path -LiteralPath (Join-Path $Root "weights.bin")) {
        return $Root
    }

    throw "No model package found under: $Root"
}

$modelDir = Resolve-ModelDir -Root $modelRoot -Version $ModelVersion

$required = @("weights.bin", "manifest.json", "on_device_model_execution_config.pb")
$missing = @()
foreach ($name in $required) {
    if (!(Test-Path -LiteralPath (Join-Path $modelDir $name))) {
        $missing += $name
    }
}

$weightsPath = Join-Path $modelDir "weights.bin"
$hash = if (Test-Path -LiteralPath $weightsPath) {
    (Get-FileHash -LiteralPath $weightsPath -Algorithm SHA256).Hash.ToLowerInvariant()
} else {
    $null
}

$manifestVersion = $null
$manifestPath = Join-Path $modelDir "manifest.json"
if (Test-Path -LiteralPath $manifestPath) {
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $manifestVersion = $manifest.version
    } catch {}
}

$result = [ordered]@{
    modelDir = $modelDir
    modelVersion = Split-Path -Path $modelDir -Leaf
    manifestVersion = $manifestVersion
    missingRequiredFiles = $missing
    weightsExists = (Test-Path -LiteralPath $weightsPath)
    weightsBytes = if (Test-Path -LiteralPath $weightsPath) { (Get-Item -LiteralPath $weightsPath).Length } else { 0 }
    weightsSha256 = $hash
}

$result | ConvertTo-Json -Depth 4

if ($missing.Count -gt 0) {
    exit 2
}

