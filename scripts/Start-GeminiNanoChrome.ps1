param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$ModelVersion,
    [string]$UserDataDir,
    [int]$RemoteDebuggingPort = 9222,
    [string]$StartPage = "probe/chat-window.html",
    [int]$ProbeHttpPort = 5610,
    [switch]$UseFileUrl,
    [switch]$DisableExperimentalAiFlags
)

$ErrorActionPreference = "Stop"

function Resolve-ChromePath {
    $candidates = @()
    if ($env:ProgramFiles) {
        $candidates += (Join-Path $env:ProgramFiles "Google\Chrome\Application\chrome.exe")
    }
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} "Google\Chrome\Application\chrome.exe")
    }
    if ($env:CHROME_PATH) {
        $candidates += $env:CHROME_PATH
    }

    foreach ($path in $candidates) {
        if (Test-Path -LiteralPath $path) { return $path }
    }
    throw "Chrome executable not found."
}

function Resolve-PathFromProject {
    param([string]$ProjectRootPath, [string]$InputPath)

    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        throw "Path cannot be empty."
    }

    if ([System.IO.Path]::IsPathRooted($InputPath)) {
        return [System.IO.Path]::GetFullPath($InputPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $ProjectRootPath $InputPath))
}

function Resolve-ModelDir {
    param([string]$ModelRoot, [string]$Version)
    if ($Version) {
        $versionDir = Join-Path $ModelRoot $Version
        if (!(Test-Path -LiteralPath $versionDir)) {
            throw "Model version folder not found: $versionDir"
        }
        return (Resolve-Path -LiteralPath $versionDir).Path
    }
    $dirs = Get-ChildItem -LiteralPath $ModelRoot -Directory | Sort-Object Name -Descending
    if ($dirs.Count -eq 0) {
        throw "No version folder found in: $ModelRoot. Run Import-OptGuideModel.ps1 first."
    }
    return $dirs[0].FullName
}

if (!(Test-Path -LiteralPath $ProjectRoot)) {
    throw "Project root not found: $ProjectRoot"
}
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path

$chromePath = Resolve-ChromePath
$modelRoot = Join-Path $ProjectRoot "model"
if (!(Test-Path -LiteralPath $modelRoot)) {
    throw "Model root not found: $modelRoot"
}

$modelDir = Resolve-ModelDir -ModelRoot $modelRoot -Version $ModelVersion
$resolvedModelVersion = Split-Path -Path $modelDir -Leaf

if (-not $UserDataDir) {
    $UserDataDir = Join-Path $ProjectRoot ".chrome-user-data"
}
$UserDataDir = Resolve-PathFromProject -ProjectRootPath $ProjectRoot -InputPath $UserDataDir
New-Item -ItemType Directory -Path $UserDataDir -Force | Out-Null

$targetModelRoot = Join-Path $UserDataDir "OptGuideOnDeviceModel"
$targetModelDir = Join-Path $targetModelRoot $resolvedModelVersion
New-Item -ItemType Directory -Path $targetModelDir -Force | Out-Null
Copy-Item -Path (Join-Path $modelDir "*") -Destination $targetModelDir -Recurse -Force

$startPagePath = Resolve-PathFromProject -ProjectRootPath $ProjectRoot -InputPath $StartPage
if (!(Test-Path -LiteralPath $startPagePath)) {
    throw "Start page not found: $startPagePath"
}
$resolvedStartPage = Resolve-Path -LiteralPath $startPagePath

if ($UseFileUrl.IsPresent) {
    $startUrl = [Uri]::new($resolvedStartPage.Path).AbsoluteUri
    $serveMode = "file"
} else {
    $probeDir = (Resolve-Path -LiteralPath (Join-Path $ProjectRoot "probe")).Path
    $probeRoot = [System.IO.Path]::GetFullPath($probeDir)
    if (-not $probeRoot.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $probeRoot += [System.IO.Path]::DirectorySeparatorChar
    }
    $startFullPath = [System.IO.Path]::GetFullPath($resolvedStartPage.Path)
    if (-not $startFullPath.StartsWith($probeRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Start page must be under '$probeDir' when UseFileUrl is not set."
    }
    $relativeFromProbe = $startFullPath.Substring($probeRoot.Length).Replace('\', '/')
    $startUrl = "http://localhost:$ProbeHttpPort/$relativeFromProbe"
    $serveMode = "http"
}

$args = @(
    "--user-data-dir=$UserDataDir",
    "--remote-debugging-port=$RemoteDebuggingPort",
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-fre",
    "--disable-popup-blocking"
)

if (-not $DisableExperimentalAiFlags.IsPresent) {
    $features = @(
        "OptimizationGuideOnDeviceModel",
        "OnDeviceModelExecution",
        "AIPromptAPI",
        "AIPromptAPIMultimodalInput",
        "PromptAPI"
    )
    $args += ("--enable-features=" + ($features -join ","))
}

$args += $startUrl

Start-Process -FilePath $chromePath -ArgumentList $args | Out-Null

$weightsPath = Join-Path $targetModelDir "weights.bin"
$weightsHash = if (Test-Path -LiteralPath $weightsPath) {
    (Get-FileHash -LiteralPath $weightsPath -Algorithm SHA256).Hash.ToLowerInvariant()
} else { $null }

$result = [ordered]@{
    chromePath = $chromePath
    projectRoot = $ProjectRoot
    modelSourceDir = $modelDir
    modelVersion = $resolvedModelVersion
    userDataDir = $UserDataDir
    targetModelDir = $targetModelDir
    weightsSha256 = $weightsHash
    startPage = $StartPage
    startUrl = $startUrl
    serveMode = $serveMode
    probeHttpPort = $ProbeHttpPort
    experimentalAiFlagsEnabled = (-not $DisableExperimentalAiFlags.IsPresent)
}

$result | ConvertTo-Json -Depth 4
