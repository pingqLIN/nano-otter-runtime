param(
    [string]$DefaultSourceVersionDir
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Resolve-DefaultSourceVersionDir {
    if (-not [string]::IsNullOrWhiteSpace($DefaultSourceVersionDir)) {
        if (!(Test-Path -LiteralPath $DefaultSourceVersionDir)) {
            throw "Configured default source folder not found: $DefaultSourceVersionDir"
        }
        return (Resolve-Path -LiteralPath $DefaultSourceVersionDir).Path
    }

    $optGuideRoot = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\OptGuideOnDeviceModel"
    if (!(Test-Path -LiteralPath $optGuideRoot)) {
        return $null
    }

    $versionDirs = Get-ChildItem -LiteralPath $optGuideRoot -Directory | Sort-Object Name -Descending
    if ($versionDirs.Count -eq 0) {
        return $null
    }

    return $versionDirs[0].FullName
}

$ResolvedDefaultSourceVersionDir = Resolve-DefaultSourceVersionDir

function Write-Header {
    Clear-Host
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host " Gemini Nano Local Launcher (Beginner UI)" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "Project: $ProjectRoot" -ForegroundColor DarkGray
    if ($ResolvedDefaultSourceVersionDir) {
        Write-Host "Default model source: $ResolvedDefaultSourceVersionDir" -ForegroundColor DarkGray
    } else {
        Write-Host "Default model source: not found (paste full path in Step 1)" -ForegroundColor DarkYellow
    }
    Write-Host ""
}

function Pause-Continue {
    Write-Host ""
    Read-Host "Press Enter to return to menu"
}

function Run-ImportModel {
    Write-Host "[1/3] Import local model package" -ForegroundColor Yellow
    if ($ResolvedDefaultSourceVersionDir) {
        $inputPath = Read-Host "Source folder (Enter for default: $ResolvedDefaultSourceVersionDir)"
        if ([string]::IsNullOrWhiteSpace($inputPath)) {
            $inputPath = $ResolvedDefaultSourceVersionDir
        }
    } else {
        $inputPath = Read-Host "Source folder (no auto default found; paste full path)"
        if ([string]::IsNullOrWhiteSpace($inputPath)) {
            throw "Source folder is required because no default source was detected."
        }
    }

    & (Join-Path $PSScriptRoot "Import-OptGuideModel.ps1") -SourceVersionDir $inputPath -ProjectRoot $ProjectRoot
}

function Run-CheckModel {
    Write-Host "[2/3] Check model package integrity" -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot "Check-ModelPack.ps1") -ProjectRoot $ProjectRoot
}

function Test-LocalPortAvailable {
    param([int]$Port)
    $listener = $null
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
        $listener.Start()
        return $true
    } catch {
        return $false
    } finally {
        if ($null -ne $listener) {
            $listener.Stop()
        }
    }
}

function Resolve-ProbePort {
    param([int]$PreferredPort = 5610)

    if (Test-LocalPortAvailable -Port $PreferredPort) {
        return $PreferredPort
    }

    for ($port = ($PreferredPort + 1); $port -le ($PreferredPort + 100); $port++) {
        if (Test-LocalPortAvailable -Port $port) {
            Write-Host "Preferred probe port $PreferredPort is unavailable. Using $port." -ForegroundColor DarkYellow
            return $port
        }
    }

    $listener = $null
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $dynamicPort = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
        Write-Host "Preferred probe port range is unavailable. Using dynamic port $dynamicPort." -ForegroundColor DarkYellow
        return $dynamicPort
    } finally {
        if ($null -ne $listener) {
            $listener.Stop()
        }
    }
}

function Ensure-ProbeServer {
    param([int]$PreferredPort = 5610)

    $port = $PreferredPort
    $probeDir = Join-Path $ProjectRoot "probe"
    $listening = $false

    try {
        $tcp = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        $listening = $null -ne $tcp
    } catch {
        $listening = $false
    }

    if (-not $listening) {
        $port = Resolve-ProbePort -PreferredPort $PreferredPort
        $proc = Start-Process -FilePath "python" -ArgumentList @("-m", "http.server", "$port", "--directory", $probeDir) -WindowStyle Hidden -PassThru
        Start-Sleep -Milliseconds 900
        $tcp = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if ($null -eq $tcp) {
            if ($proc -and (-not $proc.HasExited)) {
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
            throw "Probe server failed to start on port $port."
        }
        Write-Host "Probe server started: http://localhost:$port/" -ForegroundColor DarkGray
    }

    return $port
}

function Run-StartChrome {
    Write-Host "[3/3] Start Chrome + Chat test window (啟動 Chrome + 聊天測試視窗)" -ForegroundColor Yellow
    $probePort = Ensure-ProbeServer
    & (Join-Path $PSScriptRoot "Start-GeminiNanoChrome.ps1") -ProjectRoot $ProjectRoot -ProbeHttpPort $probePort
}

function Open-GuidePage {
    $guide = Join-Path $ProjectRoot "guide\index.html"
    if (!(Test-Path -LiteralPath $guide)) {
        throw "Guide page not found: $guide"
    }
    Start-Process -FilePath $guide | Out-Null
    Write-Host "Guide opened: $guide" -ForegroundColor Green
}

while ($true) {
    try {
        Write-Header
        Write-Host "Select an action:" -ForegroundColor White
        Write-Host "  1) Import model package"
        Write-Host "  2) Check model package"
        Write-Host "  3) Start Chrome + Chat Window"
        Write-Host "  4) Open beginner guide page"
        Write-Host "  5) Run all (Import -> Check -> Start)"
        Write-Host "  0) Exit"
        Write-Host ""
        $choice = Read-Host "Choice"

        switch ($choice) {
            "1" {
                Run-ImportModel
                Pause-Continue
            }
            "2" {
                Run-CheckModel
                Pause-Continue
            }
            "3" {
                Run-StartChrome
                Pause-Continue
            }
            "4" {
                Open-GuidePage
                Pause-Continue
            }
            "5" {
                Run-ImportModel
                Run-CheckModel
                Run-StartChrome
                Pause-Continue
            }
            "0" {
                break
            }
            default {
                Write-Host "Invalid option: $choice" -ForegroundColor Red
                Pause-Continue
            }
        }
    } catch {
        Write-Host ""
        Write-Host ("Execution failed: " + $_.Exception.Message) -ForegroundColor Red
        Pause-Continue
    }
}
