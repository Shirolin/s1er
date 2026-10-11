<#
.SYNOPSIS
  本地端到端验证 Windows 覆盖更新，不触碰线上发布。

.DESCRIPTION
  1. flutter build windows --debug（非 release → 逃生阀生效）
     注入 UPDATE_ALLOW_LOCAL_HOST=true 与指向本地服务器的 UPDATE_MANIFEST_URL
  2. 把构建产物拷到普通「安装目录」（debug 包在 build\...\runner\Debug，
     该路径会被 assertSafeInstallDir 拒绝，故必须拷出）
  3. 打包一份绿色 zip（模拟发布包，作为「新版本」）
  4. 打印两步操作：起本地升级服务器 + 直接运行安装目录里的 exe

  仅本机环回地址；逃生阀只在非 release 构建生效，线上发布不受影响。

.EXAMPLE
  pwsh -File scripts/test_update_local.ps1
  pwsh -File scripts/test_update_local.ps1 -Version 0.9.0 -Port 8099 -Mode profile
#>
[CmdletBinding()]
param(
    [string]$Version = '0.9.0',
    [int]$Port = 8099,
    [ValidateSet('debug', 'profile')]
    [string]$Mode = 'profile',
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$BuildDir = Join-Path $Root "build\windows\x64\runner\$(if ($Mode -eq 'profile') { 'Profile' } else { 'Debug' })"
$DistDir = Join-Path $Root 'dist\local-update-test'
$InstallDir = Join-Path $DistDir 'install'
$Zip = Join-Path $DistDir "s1er-$Version-windows-x64.zip"
$ManifestUrl = "http://127.0.0.1:$Port/latest.json"

if (-not $SkipBuild) {
    Write-Host "[1/4] flutter build windows --$Mode (local-update defines) ..." -ForegroundColor Cyan
    & flutter build windows "--$Mode" `
        '--dart-define=UPDATE_ALLOW_LOCAL_HOST=true' `
        "--dart-define=UPDATE_MANIFEST_URL=$ManifestUrl"
    if ($LASTEXITCODE -ne 0) { throw "flutter build failed ($LASTEXITCODE)" }
} else {
    Write-Host '[1/4] skip build' -ForegroundColor DarkGray
}

if (-not (Test-Path (Join-Path $BuildDir 's1er.exe'))) {
    throw "Missing s1er.exe under $BuildDir"
}

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

Write-Host '[2/4] staging install dir (copy off build\) ...' -ForegroundColor Cyan
if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -Path (Join-Path $BuildDir '*') -Destination $InstallDir -Recurse -Force

Write-Host '[3/4] packaging zip (the "new version") ...' -ForegroundColor Cyan
if (Test-Path $Zip) { Remove-Item $Zip -Force }
Compress-Archive -Path (Join-Path $BuildDir '*') -DestinationPath $Zip -Force

Write-Host ''
Write-Host 'Artifacts:' -ForegroundColor Green
Write-Host "  install dir : $InstallDir"
Write-Host "  zip         : $Zip"
Write-Host ''
Write-Host '[4/4] two terminals:' -ForegroundColor Yellow
Write-Host "  A) serve:  dart run scripts/serve_update_local.dart --zip `"$Zip`" --version $Version --port $Port"
Write-Host "  B) run  :  & `"$InstallDir\s1er.exe`""
Write-Host ''
Write-Host 'Then: 关于 → 检查更新 → 立即更新。观察是否闪一下即重启到新版。' -ForegroundColor DarkGray
Write-Host "Escape hatch is baked into this $Mode build only; release ignores it." -ForegroundColor DarkGray
