@echo off
echo Starting CORS Proxy and Flutter app...
echo.
echo 1. Starting proxy server on http://localhost:8080
start "CORS Proxy" cmd /c "dart run scripts/proxy_server.dart"
timeout /t 2 /nobreak >nul
echo.
echo 2. Starting Flutter app on Chrome...
flutter run -d chrome
