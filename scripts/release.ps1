# S1er release helper - run ONE step at a time (do not chain long uploads by default).
#
# Typical path A (recommended on slow GitHub upload links):
#   1) .\scripts\release.ps1 bump-build
#   2) .\scripts\release.ps1 build
#   3) .\scripts\release.ps1 create          # empty Release + open browser + dist\
#   4) Upload dist\* in the browser (often faster than gh CLI here)
#   5) .\scripts\release.ps1 manifest         # fill latest.json direct links
#   6) Commit pubspec.yaml + docs/release/latest.json yourself
#
# Path B (CLI upload - can take tens of minutes for large APK):
#   .\scripts\release.ps1 upload
#
# Options:
#   -Version 0.1.1     Set product name before bump-build / when creating tag
#   -BumpName patch|minor|major   Change name (and reset build to 1) instead of +build only
#   -SkipApk / -SkipWindows       Limit build platforms
#   -DryRun

param(
    [Parameter(Position = 0)]
    [ValidateSet(
        'help',
        'status',
        'bump-build',
        'bump-name',
        'build',
        'create',
        'upload',
        'manifest',
        'open'
    )]
    [string]$Step = 'help',

    [string]$Version,
    [ValidateSet('patch', 'minor', 'major')]
    [string]$BumpName,
    [switch]$SkipApk,
    [switch]$SkipWindows,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Pubspec = Join-Path $Root 'pubspec.yaml'
$Manifest = Join-Path $Root 'docs\release\latest.json'
$Dist = Join-Path $Root 'dist'
$RepoSlug = 'Shirolin/s1er'

function Get-PubspecVersion {
    $line = Select-String -Path $Pubspec -Pattern '^version:\s*(.+)$' | Select-Object -First 1
    if (-not $line) { throw 'pubspec.yaml: missing version:' }
    $raw = $line.Matches[0].Groups[1].Value.Trim()
    if ($raw -notmatch '^(\d+)\.(\d+)\.(\d+)\+(\d+)$') {
        throw "pubspec.yaml version must look like 0.1.0+1, got: $raw"
    }
    return [pscustomobject]@{
        Raw   = $raw
        Name  = "$($Matches[1]).$($Matches[2]).$($Matches[3])"
        Major = [int]$Matches[1]
        Minor = [int]$Matches[2]
        Patch = [int]$Matches[3]
        Build = [int]$Matches[4]
        Tag   = "v$($Matches[1]).$($Matches[2]).$($Matches[3])"
        Label = $raw
    }
}

function Set-PubspecVersion([string]$Name, [int]$Build) {
    $raw = "$Name+$Build"
    $content = Get-Content $Pubspec -Raw
    $updated = [regex]::Replace($content, '(?m)^version:\s*.+$', "version: $raw")
    if ($updated -eq $content) { throw 'Failed to rewrite pubspec version' }
    if ($DryRun) {
        Write-Host "[dry-run] would set version: $raw" -ForegroundColor Yellow
        return
    }
    Set-Content -Path $Pubspec -Value $updated -NoNewline
    Write-Host "pubspec.yaml -> version: $raw" -ForegroundColor Green
}

function Get-ArtifactPaths($v) {
    $label = $v.Label
    return [pscustomobject]@{
        # Naming: platform + variant. universal = all ABIs; others are single-ABI.
        Apk        = Join-Path $Dist "s1er-$label-android-universal.apk"
        ApkArm64   = Join-Path $Dist "s1er-$label-android-arm64-v8a.apk"
        ApkArmeabi = Join-Path $Dist "s1er-$label-android-armeabi-v7a.apk"
        ApkX64     = Join-Path $Dist "s1er-$label-android-x86_64.apk"
        Zip        = Join-Path $Dist "s1er-$label-windows-x64.zip"
        Notes      = Join-Path $Dist "release-notes-$($v.Tag).md"
    }
}

function Get-AndroidArtifactList($arts) {
    return @($arts.Apk, $arts.ApkArm64, $arts.ApkArmeabi, $arts.ApkX64)
}

function Show-Help {
    Write-Host @"
S1er release.ps1 - step-by-step (preferred)

  status       Show current version + dist artifacts
  bump-build   Only increase +build (parentheses). Does NOT change latest.json need.
  bump-name    Require -BumpName patch|minor|major (resets build to 1)
  build        fat APK + per-ABI APKs + windows -> dist\  (NO upload)
  create       gh release create TAG with notes only; opens browser + dist\
  upload       gh release upload dist artifacts (SLOW on some networks)
  manifest     Rewrite docs/release/latest.json (androidApk = fat universal)
  open         Open the GitHub Release page for current tag

Examples:
  .\scripts\release.ps1 bump-build
  .\scripts\release.ps1 build
  .\scripts\release.ps1 create
  # then drag-drop dist\*.apk / *.zip in the browser
  .\scripts\release.ps1 manifest

Raise product version (app update prompt):
  .\scripts\release.ps1 bump-name -BumpName patch
  .\scripts\release.ps1 build
  ...
"@
}

function Step-Status {
    $v = Get-PubspecVersion
    Write-Host "version: $($v.Raw)   name=$($v.Name)  build=$($v.Build)  tag=$($v.Tag)" -ForegroundColor Cyan
    $arts = Get-ArtifactPaths $v
    $paths = @(Get-AndroidArtifactList $arts) + @($arts.Zip, $arts.Notes)
    foreach ($p in $paths) {
        if (Test-Path $p) {
            $len = (Get-Item $p).Length
            Write-Host ("  OK  {0}  ({1:N1} MB)" -f (Split-Path $p -Leaf), ($len / 1MB)) -ForegroundColor Green
        } else {
            Write-Host ("  --  {0}" -f (Split-Path $p -Leaf)) -ForegroundColor DarkGray
        }
    }
    Write-Host "Release URL: https://github.com/$RepoSlug/releases/tag/$($v.Tag)"
    Write-Host "Next: if artifacts missing -> build; if Release empty -> create + browser upload"
}

function Step-BumpBuild {
    $v = Get-PubspecVersion
    if ($Version) {
        if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "-Version must be like 0.1.1 (no +build)" }
        Set-PubspecVersion -Name $Version -Build ($v.Build + 1)
    } else {
        Set-PubspecVersion -Name $v.Name -Build ($v.Build + 1)
    }
    Step-Status
}

function Step-BumpName {
    if (-not $BumpName) { throw 'bump-name requires -BumpName patch|minor|major' }
    $v = Get-PubspecVersion
    $major = $v.Major; $minor = $v.Minor; $patch = $v.Patch
    switch ($BumpName) {
        'patch' { $patch++ }
        'minor' { $minor++; $patch = 0 }
        'major' { $major++; $minor = 0; $patch = 0 }
    }
    $name = "$major.$minor.$patch"
    Set-PubspecVersion -Name $name -Build 1
    Write-Host "Remember: name changed -> update latest.json (use 'manifest') and commit." -ForegroundColor Yellow
    Step-Status
}

function Invoke-FlutterBuild([string[]]$Args) {
    Write-Host ("> flutter " + ($Args -join ' ')) -ForegroundColor DarkCyan
    if ($DryRun) { return }
    & flutter @Args
    if ($LASTEXITCODE -ne 0) { throw "flutter failed ($LASTEXITCODE)" }
}

function Step-Build {
    New-Item -ItemType Directory -Force -Path $Dist | Out-Null
    $v = Get-PubspecVersion
    $arts = Get-ArtifactPaths $v
    $apkOut = Join-Path $Root 'build\app\outputs\flutter-apk'

    if (-not $SkipApk) {
        # 1) Universal / fat (all ABIs in one file)
        Write-Host "`n[build] Android universal APK (all ABIs)..." -ForegroundColor Cyan
        Invoke-FlutterBuild @(
            'build', 'apk', '--release',
            '--obfuscate', "--split-debug-info=build/debug-info"
        )
        $fatSrc = Join-Path $apkOut 'app-release.apk'
        if (-not (Test-Path $fatSrc)) { throw "Missing $fatSrc" }
        if (-not $DryRun) {
            Copy-Item $fatSrc $arts.Apk -Force
            Write-Host "Wrote $($arts.Apk)" -ForegroundColor Green
        }

        # 2) Per-ABI splits (smaller downloads)
        Write-Host "`n[build] Android per-ABI APKs (--split-per-abi)..." -ForegroundColor Cyan
        Invoke-FlutterBuild @(
            'build', 'apk', '--release', '--split-per-abi',
            '--obfuscate', "--split-debug-info=build/debug-info"
        )
        $splitMap = @{
            'app-arm64-v8a-release.apk'   = $arts.ApkArm64
            'app-armeabi-v7a-release.apk' = $arts.ApkArmeabi
            'app-x86_64-release.apk'      = $arts.ApkX64
        }
        foreach ($name in $splitMap.Keys) {
            $src = Join-Path $apkOut $name
            if (-not (Test-Path $src)) { throw "Missing $src" }
            if (-not $DryRun) {
                Copy-Item $src $splitMap[$name] -Force
                Write-Host "Wrote $($splitMap[$name])" -ForegroundColor Green
            }
        }
    }

    if (-not $SkipWindows) {
        Write-Host "`n[build] Windows Release..." -ForegroundColor Cyan
        Invoke-FlutterBuild @('build', 'windows', '--release')
        $winDir = Join-Path $Root 'build\windows\x64\runner\Release'
        if (-not (Test-Path (Join-Path $winDir 's1er.exe'))) { throw "Missing s1er.exe under $winDir" }
        if (-not $DryRun) {
            if (Test-Path $arts.Zip) { Remove-Item $arts.Zip -Force }
            Compress-Archive -Path (Join-Path $winDir '*') -DestinationPath $arts.Zip -Force
            Write-Host "Wrote $($arts.Zip)" -ForegroundColor Green
        }
    }

    Write-Host "`nBuild done. Artifacts stay local under dist\ - NO upload yet." -ForegroundColor Green
    Write-Host "Next: .\scripts\release.ps1 create   (then upload in browser)" -ForegroundColor Yellow
    Step-Status
}

function Write-NotesFile($v, $path) {
    $arts = Get-ArtifactPaths $v
    $body = @"
## S1er $($v.Name)

Build ``$($v.Label)``（关于页：``$($v.Name) ($($v.Build))``）

### 下哪个包？（Android）

| 文件 | 选谁 |
|:---|:---|
| ``$(Split-Path $arts.Apk -Leaf)`` | **不确定就下这个**（universal，含全部架构，体积最大） |
| ``$(Split-Path $arts.ApkArm64 -Leaf)`` | 近 5 年大多数真机（arm64） |
| ``$(Split-Path $arts.ApkArmeabi -Leaf)`` | 较老的 32 位 ARM 机 |
| ``$(Split-Path $arts.ApkX64 -Leaf)`` | 模拟器 / 少数 x86 平板 |

装错架构会提示解析包失败或无法安装，换对应 ABI 或改下 universal 即可。

### 其它

- Windows：``$(Split-Path $arts.Zip -Leaf)``（解压后运行 ``s1er.exe``）

第三方 Stage1st 客户端；详见 CHANGELOG / README。
"@
    if ($DryRun) {
        Write-Host "[dry-run] notes -> $path" -ForegroundColor Yellow
        return
    }
    # UTF-8 without BOM for gh
    [System.IO.File]::WriteAllText($path, $body)
}

function Step-Create {
    $v = Get-PubspecVersion
    $arts = Get-ArtifactPaths $v
    New-Item -ItemType Directory -Force -Path $Dist | Out-Null
    Write-NotesFile $v $arts.Notes

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw 'gh CLI not found. Install GitHub CLI or create the Release manually on github.com'
    }

    $existing = gh release view $v.Tag 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Release $($v.Tag) already exists." -ForegroundColor Yellow
    } else {
        Write-Host "Creating Release $($v.Tag) (notes only, no assets)..." -ForegroundColor Cyan
        if (-not $DryRun) {
            gh release create $v.Tag --title "S1er $($v.Name)" --notes-file $arts.Notes --latest
            if ($LASTEXITCODE -ne 0) { throw "gh release create failed ($LASTEXITCODE)" }
        }
    }

    $url = "https://github.com/$RepoSlug/releases/tag/$($v.Tag)"
    Write-Host "`nOpen this page and attach files from dist\ (browser upload is often faster):" -ForegroundColor Green
    Write-Host "  $url"
    foreach ($p in @(Get-AndroidArtifactList $arts) + @($arts.Zip)) {
        if (Test-Path $p) { Write-Host "  - $p" }
    }
    if (-not $DryRun) {
        Start-Process $url
        if (Test-Path $Dist) { Start-Process explorer.exe $Dist }
    }
    Write-Host "`nAfter assets are up: .\scripts\release.ps1 manifest" -ForegroundColor Yellow
}

function Step-Upload {
    $v = Get-PubspecVersion
    $arts = Get-ArtifactPaths $v
    $files = @()
    foreach ($p in @(Get-AndroidArtifactList $arts) + @($arts.Zip)) {
        if (Test-Path $p) { $files += $p }
    }
    if ($files.Count -eq 0) { throw 'No dist artifacts. Run: .\scripts\release.ps1 build' }

    Write-Host "CLI upload can be VERY slow (several APKs). Prefer browser after 'create'." -ForegroundColor Yellow
    Write-Host "Uploading $($files.Count) file(s)..." -ForegroundColor Cyan
    if ($DryRun) { return }

    # Ensure release exists
    gh release view $v.Tag 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Step-Create
    }
    foreach ($f in $files) {
        Write-Host "-> $(Split-Path $f -Leaf) ..." -ForegroundColor DarkCyan
        gh release upload $v.Tag $f --clobber
        if ($LASTEXITCODE -ne 0) { throw "upload failed for $f ($LASTEXITCODE)" }
        Write-Host "   OK" -ForegroundColor Green
    }
    Write-Host "Upload finished. Next: .\scripts\release.ps1 manifest" -ForegroundColor Green
}

function Step-Manifest {
    $v = Get-PubspecVersion
    if (-not (Test-Path $Manifest)) { throw "Missing $Manifest" }

    # In-app update CTA uses the universal fat APK (no ABI pick needed).
    $apkFile = "s1er-$($v.Label)-android-universal.apk"
    $zipFile = "s1er-$($v.Label)-windows-x64.zip"
    $apkUrl = "https://github.com/$RepoSlug/releases/download/$($v.Tag)/$([uri]::EscapeDataString($apkFile))"
    $zipUrl = "https://github.com/$RepoSlug/releases/download/$($v.Tag)/$([uri]::EscapeDataString($zipFile))"
    $today = Get-Date -Format 'yyyy-MM-dd'

    $json = Get-Content $Manifest -Raw | ConvertFrom-Json
    $nameChanged = $json.latest -ne $v.Name
    $json.latest = $v.Name
    $json.publishedAt = $today
    if ($nameChanged -or [string]::IsNullOrWhiteSpace($json.notes)) {
        $json.notes = "Beta"
    }
    $json.channels.github = "https://github.com/$RepoSlug/releases/latest"
    $json.channels.androidApk = $apkUrl
    $json.channels.windows = $zipUrl

    $out = $json | ConvertTo-Json -Depth 6
    if ($DryRun) {
        Write-Host "[dry-run] latest.json would become:`n$out" -ForegroundColor Yellow
        return
    }
    # Prefer stable 2-space JSON without BOM
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Manifest, ($out.Trim() + "`n"), $utf8)
    Write-Host "Updated $Manifest" -ForegroundColor Green
    Write-Host "  latest=$($v.Name)  androidApk=universal fat; split APKs only on GitHub Release page"
    if ($nameChanged) {
        Write-Host "Name changed vs previous latest.json - commit pubspec.yaml + latest.json to main." -ForegroundColor Yellow
    } else {
        Write-Host "Name unchanged - committing latest.json is optional (direct links only)." -ForegroundColor DarkGray
    }
}

function Step-Open {
    $v = Get-PubspecVersion
    $url = "https://github.com/$RepoSlug/releases/tag/$($v.Tag)"
    Write-Host $url
    if (-not $DryRun) { Start-Process $url }
}

switch ($Step) {
    'help' { Show-Help }
    'status' { Step-Status }
    'bump-build' { Step-BumpBuild }
    'bump-name' { Step-BumpName }
    'build' { Step-Build }
    'create' { Step-Create }
    'upload' { Step-Upload }
    'manifest' { Step-Manifest }
    'open' { Step-Open }
}
