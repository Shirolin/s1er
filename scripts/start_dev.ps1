# 开发环境启动脚本
# 启动 CORS 代理 + Flutter Web

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  S1 Forum App - Development Mode" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 启动 CORS 代理
Write-Host "[1/2] Starting CORS Proxy on http://localhost:8080..." -ForegroundColor Yellow
$proxyJob = Start-Process -FilePath "dart" -ArgumentList "run", "scripts/proxy_server.dart" -PassThru -WindowStyle Minimized
Start-Sleep -Seconds 2

Write-Host "[2/2] Starting Flutter on Chrome..." -ForegroundColor Yellow
Write-Host ""

# 启动 Flutter
flutter run -d chrome

# 退出时关闭代理
Write-Host ""
Write-Host "Shutting down proxy..." -ForegroundColor Yellow
Stop-Process -Id $proxyJob.Id -Force -ErrorAction SilentlyContinue
