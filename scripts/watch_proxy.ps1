$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $PSScriptRoot "proxy_server.dart"
$stdoutLogPath = Join-Path $projectRoot "proxy.stdout.log"
$stderrLogPath = Join-Path $projectRoot "proxy.stderr.log"
$dartCommand = Get-Command "dart" -ErrorAction SilentlyContinue

if (-not $dartCommand) {
    throw "未找到 dart 命令，请确认 Flutter/Dart 已加入 PATH。"
}

$process = $null
$lastWriteTime = (Get-Item -LiteralPath $scriptPath).LastWriteTimeUtc

function Initialize-UpstreamProxy {
    if ($env:HTTPS_PROXY -or $env:HTTP_PROXY -or $env:ALL_PROXY) {
        Write-Host "[proxy] upstream proxy from environment" -ForegroundColor Cyan
        return
    }

    $localProxy = Test-NetConnection 127.0.0.1 -Port 7890 -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($localProxy) {
        $proxyUrl = "http://127.0.0.1:7890"
        $env:HTTP_PROXY = $proxyUrl
        $env:HTTPS_PROXY = $proxyUrl
        $env:ALL_PROXY = $proxyUrl
        Write-Host "[proxy] upstream proxy: $proxyUrl" -ForegroundColor Cyan
    } else {
        Write-Host "[proxy] upstream proxy: DIRECT" -ForegroundColor Cyan
    }
}

function Stop-Proxy {
    if ($script:process -and -not $script:process.HasExited) {
        $script:process | Stop-Process -Force -ErrorAction SilentlyContinue
        $script:process.WaitForExit(3000) | Out-Null
    }
    $script:process = $null
}

function Stop-ExistingProxyOnPort {
    $connections = Get-NetTCPConnection -LocalPort 19080 -ErrorAction SilentlyContinue
    if (-not $connections) {
        return
    }

    $connections |
        Select-Object -ExpandProperty OwningProcess -Unique |
        Where-Object { $_ -gt 0 } |
        ForEach-Object {
            Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
        }
    Start-Sleep -Seconds 1
}

function Start-Proxy {
    Stop-Proxy
    Write-Host "[proxy] starting..." -ForegroundColor Green
    foreach ($path in @($stdoutLogPath, $stderrLogPath)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    }
    $startArgs = @{
        FilePath = $script:dartCommand.Source
        ArgumentList = @("run", "scripts/proxy_server.dart")
        WorkingDirectory = $script:projectRoot
        PassThru = $true
        WindowStyle = "Hidden"
        RedirectStandardOutput = $script:stdoutLogPath
        RedirectStandardError = $script:stderrLogPath
    }
    $script:process = Start-Process @startArgs
}

function Show-ProxyLogTail {
    foreach ($path in @($stderrLogPath, $stdoutLogPath)) {
        if (Test-Path -LiteralPath $path) {
            Write-Host "[proxy] $([System.IO.Path]::GetFileName($path)) tail:" -ForegroundColor DarkYellow
            Get-Content -LiteralPath $path -Tail 40 -ErrorAction SilentlyContinue
        }
    }
}

Stop-ExistingProxyOnPort
Initialize-UpstreamProxy
Start-Proxy

Write-Host "[proxy] watching scripts/proxy_server.dart, Ctrl+C to stop" -ForegroundColor Cyan

try {
    while ($true) {
        Start-Sleep -Milliseconds 500
        $currentWriteTime = (Get-Item -LiteralPath $scriptPath).LastWriteTimeUtc
        if ($currentWriteTime -ne $lastWriteTime) {
            $lastWriteTime = $currentWriteTime
            Write-Host "[proxy] restarting..." -ForegroundColor Yellow
            Start-Proxy
        }

        if ($process -and $process.HasExited) {
            Write-Host "[proxy] exited with code $($process.ExitCode), restarting..." -ForegroundColor Yellow
            Show-ProxyLogTail
            Start-Proxy
        }
    }
} finally {
    Stop-Proxy
}
