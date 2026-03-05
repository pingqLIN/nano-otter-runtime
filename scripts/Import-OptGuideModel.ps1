param(
    [string]$SourceVersionDir,
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Resolve-DefaultSourceVersionDir {
    $optGuideRoot = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\OptGuideOnDeviceModel"
    if (!(Test-Path -LiteralPath $optGuideRoot)) {
        throw "Default OptGuide root not found: $optGuideRoot"
    }

    $versionDirs = Get-ChildItem -LiteralPath $optGuideRoot -Directory | Sort-Object Name -Descending
    if ($versionDirs.Count -eq 0) {
        throw "No model version folders found under: $optGuideRoot"
    }

    return $versionDirs[0].FullName
}

if (!(Test-Path -LiteralPath $ProjectRoot)) {
    throw "Project root not found: $ProjectRoot"
}
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path

if ([string]::IsNullOrWhiteSpace($SourceVersionDir)) {
    $SourceVersionDir = Resolve-DefaultSourceVersionDir
}

if (!(Test-Path -LiteralPath $SourceVersionDir)) {
    throw "Source version directory not found: $SourceVersionDir"
}
$SourceVersionDir = (Resolve-Path -LiteralPath $SourceVersionDir).Path

$version = Split-Path -Path $SourceVersionDir -Leaf
$destVersionDir = Join-Path (Join-Path $ProjectRoot "model") $version
New-Item -ItemType Directory -Path $destVersionDir -Force | Out-Null

Copy-Item -Path (Join-Path $SourceVersionDir "*") -Destination $destVersionDir -Recurse -Force

$weightsPath = Join-Path $destVersionDir "weights.bin"
if (!(Test-Path -LiteralPath $weightsPath)) {
    throw "Import failed: weights.bin not found in destination"
}

$hash = (Get-FileHash -LiteralPath $weightsPath -Algorithm SHA256).Hash.ToLowerInvariant()
$manifestPath = Join-Path $destVersionDir "manifest.json"
$manifestVersion = $null
if (Test-Path -LiteralPath $manifestPath) {
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $manifestVersion = $manifest.version
    } catch {}
}

Write-Output ("IMPORTED_VERSION=" + $version)
Write-Output ("SOURCE_DIR=" + $SourceVersionDir)
Write-Output ("DEST_DIR=" + $destVersionDir)
Write-Output ("WEIGHTS_SHA256=" + $hash)
Write-Output ("MANIFEST_VERSION=" + $manifestVersion)
