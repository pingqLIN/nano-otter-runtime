param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$TargetDir,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

if (!(Test-Path -LiteralPath $ProjectRoot)) {
    throw "Project root not found: $ProjectRoot"
}
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path

if ([string]::IsNullOrWhiteSpace($TargetDir)) {
    $projectParent = Split-Path -Path $ProjectRoot -Parent
    $projectName = Split-Path -Path $ProjectRoot -Leaf
    $TargetDir = Join-Path $projectParent ($projectName + "-export")
} elseif ([System.IO.Path]::IsPathRooted($TargetDir)) {
    $TargetDir = [System.IO.Path]::GetFullPath($TargetDir)
} else {
    $TargetDir = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $TargetDir))
}

if ($TargetDir -eq $ProjectRoot) {
    throw "TargetDir cannot be the same as ProjectRoot: $TargetDir"
}

if (Test-Path -LiteralPath $TargetDir) {
    if (-not $Force.IsPresent) {
        throw "Target already exists: $TargetDir (use -Force to overwrite)"
    }
    Remove-Item -LiteralPath $TargetDir -Recurse -Force
}

New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

$includeFiles = @(
    ".gitignore",
    "README.md",
    "Start-QuickStart.ps1",
    "start.cmd",
    "guide/index.html",
    "model/.gitkeep",
    "model/README.md",
    "probe/prompt-api-probe.html",
    "probe/chat-window.html",
    "scripts/Import-OptGuideModel.ps1",
    "scripts/Check-ModelPack.ps1",
    "scripts/Start-GeminiNanoChrome.ps1",
    "scripts/QuickStart-UI.ps1",
    "scripts/Export-GitHubRepo.ps1"
)

foreach ($relPath in $includeFiles) {
    $src = Join-Path $ProjectRoot $relPath
    if (!(Test-Path -LiteralPath $src)) {
        throw "Required file missing: $src"
    }
    $dst = Join-Path $TargetDir $relPath
    $dstParent = Split-Path -Path $dst -Parent
    New-Item -ItemType Directory -Path $dstParent -Force | Out-Null
    Copy-Item -LiteralPath $src -Destination $dst -Force
}

$gitExists = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
if ($gitExists) {
    Push-Location $TargetDir
    try {
        git init | Out-Null
        git add . | Out-Null
    } finally {
        Pop-Location
    }
}

$result = [ordered]@{
    source = $ProjectRoot
    target = $TargetDir
    initializedGit = [bool]$gitExists
}
$result | ConvertTo-Json -Depth 3
