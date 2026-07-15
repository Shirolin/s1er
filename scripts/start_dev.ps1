# 开发环境启动脚本
# 交互式菜单，支持 Web / Android / 无代理等模式
#
# 可选环境变量：
#   S1_SENTRY_DSN   - 设置 Sentry DSN（默认已内置）
#
# 所有 flutter run 的输出同时写入 logs/ 目录的日志文件，
# 避免闪退后 Clear-Host 擦除或终端关闭后丢失错误信息。

param()

$projectRoot = Split-Path -Parent $PSScriptRoot

# ── Log directory ────────────────────────────────────────────
$logDir = Join-Path $projectRoot "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

function New-RunLog {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    return Join-Path $logDir "flutter_run_${timestamp}.log"
}

function Write-Message {
    param([string]$Message, [string]$Color = "White")
    $now = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$now] $Message" -ForegroundColor $Color
}

# ── Sentry DSN ────────────────────────────────────────────
$script:SentryDsn = $env:S1_SENTRY_DSN
if (-not $script:SentryDsn) {
    $script:SentryDsn = 'https://7ea0cea034d3c0a13de3bbbf862e8ae7@o4511738264944640.ingest.us.sentry.io/4511738316128256'
}
function Start-Flutter {
    param([string[]]$FlutterArgs)
    $dartDefine = '--dart-define=SENTRY_DSN=' + $script:SentryDsn
    $allArgs = @($FlutterArgs) + @($dartDefine)
    & flutter @allArgs
}

function Show-Menu {
    Clear-Host
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host '  S1 Forum App - Development Mode' -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ''

    Write-Host '  [1] Web + Proxy (Chrome)' -ForegroundColor Green
    Write-Host '      -> Start CORS proxy + Chrome browser'
    Write-Host ''

    Write-Host '  [2] Web + Proxy (Edge)' -ForegroundColor Yellow
    Write-Host '      -> Start CORS proxy + Edge browser'
    Write-Host ''

    Write-Host '  [3] Android device' -ForegroundColor Magenta
    Write-Host '      -> Run on connected Android device/emulator'
    Write-Host ''

    Write-Host '  [4] Just Proxy' -ForegroundColor Cyan
    Write-Host '      -> Start CORS proxy only, no Flutter'
    Write-Host ''

    Write-Host '  [C] Clean port 19080' -ForegroundColor DarkYellow
    Write-Host '      -> Kill any process on proxy port'
    Write-Host ''

    Write-Host '  [S] Toggle Sentry' -ForegroundColor White
    if ($script:SentryDsn) {
        Write-Host '      -> Currently: ENABLED' -ForegroundColor Green
    } else {
        Write-Host '      -> Currently: DISABLED' -ForegroundColor Red
    }
    Write-Host ''

    Write-Host '  Logs dir: ' -NoNewline; Write-Host $logDir -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  [0] Exit' -ForegroundColor Gray
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
}

function Start-Proxy {
    $proxyUrl = $null

    # ── 端口冲突强制清理 ────────────────────────────────────
    $cleaned = $false
    for ($try = 0; $try -lt 3; $try++) {
        $connections = Get-NetTCPConnection -LocalPort 19080 -ErrorAction SilentlyContinue
        if (-not $connections) { break }
        Write-Message "Port 19080 occupied, killing old process (attempt $($try+1))..." "DarkYellow"
        $connections |
            Select-Object -ExpandProperty OwningProcess -Unique |
            Where-Object { $_ -gt 0 } |
            ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 1
        $cleaned = $true
    }
    if ($cleaned) { Write-Message "Port 19080 freed" "Green" }

    # ── 上游代理自动检测 ────────────────────────────────────

    # ── 上游代理自动检测 ────────────────────────────────────
    if (-not ($env:HTTPS_PROXY -or $env:HTTP_PROXY -or $env:ALL_PROXY)) {
        $localProxy = Test-NetConnection 127.0.0.1 -Port 7890 -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($localProxy) {
            $proxyUrl = 'http://127.0.0.1:7890'
            $env:HTTP_PROXY = $proxyUrl
            $env:HTTPS_PROXY = $proxyUrl
            $env:ALL_PROXY = $proxyUrl
        }
    }

    $proxyLog = Join-Path $logDir "proxy_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $proxyErrLog = Join-Path $logDir "proxy_$(Get-Date -Format 'yyyyMMdd_HHmmss').err.log"

    Write-Message "Starting CORS Proxy on http://localhost:19080..." "Yellow"
    Write-Message "Proxy log: $proxyLog" "DarkGray"
    $global:ProxyJob = Start-Process -FilePath 'dart' -ArgumentList 'run', 'scripts/proxy_server.dart' -PassThru -WindowStyle Hidden -RedirectStandardOutput $proxyLog -RedirectStandardError $proxyErrLog
    if ($proxyUrl) {
        Write-Message "Upstream proxy: $proxyUrl" "Cyan"
    }
    Start-Sleep -Seconds 2
    if ($global:ProxyJob.HasExited) {
        Write-Message "Proxy failed to start (exit code: $($global:ProxyJob.ExitCode))" "Red"
    } else {
        Write-Message "Proxy started (PID: $($global:ProxyJob.Id))" "Green"
    }
}

function Stop-Proxy {
    if ($global:ProxyJob -and -not $global:ProxyJob.HasExited) {
        Write-Message "Shutting down proxy..." "Yellow"
        Stop-Process -Id $global:ProxyJob.Id -Force -ErrorAction SilentlyContinue
        Write-Message "Proxy stopped" "Green"
    }
}

function Wait-FlutterAndPause {
    param([string]$Device)

    $runLog = New-RunLog
    Write-Message "Starting Flutter on $Device..." "Yellow"
    Write-Message "All output also saved to: $runLog" "DarkGray"

    # Tee-Object: terminal 显示的同时写入文件
    # flutter run 是交互式的（r/R/q 等），用 Tee-Object 会阻塞 stdin。
    # 所以只启动交互式 flutter，退出后用 Get-Content 补一份日志到文件。
    # 当前终端已有完整输出，日志文件作为持久备份。
    try {
        Start-Transcript -Path $runLog -Force | Out-Null
        $script:TranscriptActive = $true
    } catch {
        Write-Message "Transcript not available (saving output directly)" "DarkYellow"
        $script:TranscriptActive = $false
    }

    Start-Flutter @('run', '-d', $Device)

    if ($script:TranscriptActive) {
        Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
        $script:TranscriptActive = $false
    }

    Write-Message "Flutter exited." "Yellow"
    if (Test-Path $runLog) {
        Write-Message "Full output saved to: $runLog" "Cyan"
    }
    Write-Host ''
    Write-Host 'Scroll up in this terminal to see the full output.' -ForegroundColor DarkGray
    Write-Host 'Press any key to return to menu...' -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

do {
    Show-Menu
    $choice = Read-Host 'Select (0-4, C, S)'

    switch ($choice) {
        '1' {
            Start-Proxy
            Wait-FlutterAndPause 'chrome'
            Stop-Proxy
            break
        }
        '2' {
            Start-Proxy
            Wait-FlutterAndPause 'edge'
            Stop-Proxy
            break
        }
        '3' { Wait-FlutterAndPause 'android'; break }
        '4' {
            Start-Proxy
            Write-Host ''
            Write-Host 'Proxy running in background (logs in $logDir).' -ForegroundColor Yellow
            Write-Host 'Press Enter to stop proxy and return to menu...' -ForegroundColor Gray
            Read-Host
            Stop-Proxy
        }
        'C' {
            Write-Message "Killing processes on port 19080..." "DarkYellow"
            $connections = Get-NetTCPConnection -LocalPort 19080 -ErrorAction SilentlyContinue
            if (-not $connections) {
                Write-Message "Port 19080 is free" "Green"
            } else {
                $connections |
                    Select-Object -ExpandProperty OwningProcess -Unique |
                    Where-Object { $_ -gt 0 } |
                    ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
                Start-Sleep -Seconds 1
                Write-Message "Port 19080 freed" "Green"
            }
            Write-Host 'Press any key to return to menu...' -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
        'S' {
            if ($script:SentryDsn) {
                $script:SentryDsn = ''
                Write-Host ''
                Write-Host 'Sentry DISABLED for next launch' -ForegroundColor Red
            } else {
                $script:SentryDsn = $env:S1_SENTRY_DSN
                if (-not $script:SentryDsn) {
                    $script:SentryDsn = 'https://7ea0cea034d3c0a13de3bbbf862e8ae7@o4511738264944640.ingest.us.sentry.io/4511738316128256'
                }
                Write-Host ''
                Write-Host 'Sentry ENABLED for next launch' -ForegroundColor Green
            }
            Write-Host ''
            Write-Host 'Press any key to return to menu...' -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
        '0' {
            Write-Host ''
            Write-Host 'Goodbye!' -ForegroundColor Cyan
            return
        }
        default {
            Write-Host ''
            Write-Host 'Invalid choice, please try again' -ForegroundColor Red
            Write-Host ''
            Write-Host 'Press any key to return to menu...' -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
    }
} while ($choice -ne '0')

# 退出时清理代理
Stop-Proxy
