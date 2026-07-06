$dart = "D:\flutter-sdk\bin\cache\dart-sdk\bin\dart.exe"
$script = Join-Path $PSScriptRoot "proxy_server.dart"

# 先杀掉占用端口的旧进程
$portCheck = Get-NetTCPConnection -LocalPort 19080 -ErrorAction SilentlyContinue
if ($portCheck) {
    $portCheck | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object {
        Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 1
}

$process = $null

function Start-Proxy {
    if ($script:process -and -not $script:process.HasExited) {
        $script:process | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
    Write-Host "[proxy] starting..." -ForegroundColor Green
    $script:process = Start-Process -FilePath $dart -ArgumentList "run", $script -PassThru
}

Start-Proxy

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $PSScriptRoot
$watcher.Filter = "proxy_server.dart"
$watcher.IncludeSubdirectories = $false
$watcher.EnableRaisingEvents = $true

$timer = New-Object System.Timers.Timer
$timer.Interval = 500
$timer.AutoReset = $false
$timer.Add_Elapsed({
    Write-Host "[proxy] restarting..." -ForegroundColor Yellow
    Start-Proxy
})

Register-ObjectEvent $watcher "Changed" -Action { $timer.Start() } | Out-Null

Write-Host "[proxy] watching scripts/proxy_server.dart, Ctrl+C to stop" -ForegroundColor Cyan

try {
    while ($true) { Start-Sleep -Seconds 1 }
} finally {
    if ($script:process -and -not $script:process.HasExited) {
        $script:process | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    $watcher.Dispose()
    $timer.Dispose()
}
