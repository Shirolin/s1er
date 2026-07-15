# 开发环境启动脚本
# 交互式菜单，支持 Web / Android / 无代理等模式
#
# 可选环境变量：
#   S1_SENTRY_DSN  - 设置 Sentry DSN（默认已内置）

# ── Sentry DSN ────────────────────────────────────────────
$script:SentryDsn = $env:S1_SENTRY_DSN
if (-not $script:SentryDsn) {
    $script:SentryDsn = 'https://7ea0cea034d3c0a13de3bbbf862e8ae7@o4511738264944640.ingest.us.sentry.io/4511738316128256'
}
function Start-Flutter {
    param([string[]]$Args)
    $allArgs = $Args + '--dart-define=SENTRY_DSN=' + $script:SentryDsn
    flutter $allArgs
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

    Write-Host '  [3] Web (no proxy)' -ForegroundColor Yellow
    Write-Host '      -> Direct Chrome, no proxy'
    Write-Host ''

    Write-Host '  [4] Android device' -ForegroundColor Magenta
    Write-Host '      -> Run on connected Android device/emulator'
    Write-Host ''

    Write-Host '  [5] Just Proxy' -ForegroundColor Cyan
    Write-Host '      -> Start CORS proxy only, no Flutter'
    Write-Host ''

    Write-Host '  [S] Toggle Sentry' -ForegroundColor White
    if ($script:SentryDsn) {
        Write-Host '      -> Currently: ENABLED' -ForegroundColor Green
    } else {
        Write-Host '      -> Currently: DISABLED' -ForegroundColor Red
    }
    Write-Host ''

    Write-Host '  [0] Exit' -ForegroundColor Gray
    Write-Host ''

    Write-Host '========================================' -ForegroundColor Cyan
}

function Start-Proxy {
    Write-Host ''
    Write-Host 'Starting CORS Proxy on http://localhost:19080...' -ForegroundColor Yellow
    $global:ProxyJob = Start-Process -FilePath 'dart' -ArgumentList 'run', 'scripts/proxy_server.dart' -PassThru -WindowStyle Minimized
    Start-Sleep -Seconds 2
    Write-Host '  Proxy started (PID: ' $global:ProxyJob.Id ')' -ForegroundColor Green
}

function Stop-Proxy {
    if ($global:ProxyJob -and -not $global:ProxyJob.HasExited) {
        Write-Host ''
        Write-Host 'Shutting down proxy...' -ForegroundColor Yellow
        Stop-Process -Id $global:ProxyJob.Id -Force -ErrorAction SilentlyContinue
        Write-Host '  Proxy stopped' -ForegroundColor Green
    }
}

function Start-FlutterWithProxy {
    param([string]$Device)

    Start-Proxy
    Write-Host ''
    Write-Host 'Starting Flutter on ' $Device '...' -ForegroundColor Yellow
    Start-Flutter @('run', '-d', $Device)
    Stop-Proxy
}

do {
    Show-Menu
    $choice = Read-Host 'Select (0-5, S)'

    switch ($choice) {
        '1' { Start-FlutterWithProxy 'chrome'; break }
        '2' { Start-FlutterWithProxy 'edge'; break }
        '3' {
            Write-Host ''
            Write-Host 'Starting Flutter on Chrome (no proxy)...' -ForegroundColor Yellow
            Start-Flutter @('run', '-d', 'chrome')
        }
        '4' {
            Write-Host ''
            Write-Host 'Starting Flutter on Android...' -ForegroundColor Yellow
            Start-Flutter @('run', '-d', 'android')
        }
        '5' {
            Start-Proxy
            Write-Host ''
            Write-Host 'Proxy running. Press Enter to stop...' -ForegroundColor Yellow
            Read-Host
            Stop-Proxy
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
