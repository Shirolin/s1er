# S1 App Build Script
# Interactive menu for build options

# Auto-detect Java/keytool path
# ── Sentry DSN ────────────────────────────────────────────
$script:SentryDsn = $env:S1_SENTRY_DSN
if (-not $script:SentryDsn) {
    $script:SentryDsn = "https://7ea0cea034d3c0a13de3bbbf862e8ae7@o4511738264944640.ingest.us.sentry.io/4511738316128256"
}
function Build-WithDsn {
    param([string[]]$Args)
    $allArgs = $Args + "--dart-define=SENTRY_DSN=$script:SentryDsn"
    flutter $allArgs
}

function Find-Keytool {
    $paths = @(
        "$env:JAVA_HOME\bin\keytool.exe",
        "C:\Users\shiro\AppData\Local\Programs\CorrettoJDK17\jdk17.0.19_10\bin\keytool.exe",
        "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe",
        "C:\Program Files\Eclipse Adoptium\*\bin\keytool.exe"
    )
    
    foreach ($path in $paths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    $whereResult = where.exe keytool 2>$null
    if ($whereResult) {
        return $whereResult
    }
    
    return $null
}

function Find-Apksigner {
    $sdkPath = "$env:LOCALAPPDATA\Android\Sdk"
    $buildTools = Get-ChildItem "$sdkPath\build-tools" -Directory -ErrorAction SilentlyContinue | 
        Sort-Object Name -Descending | Select-Object -First 1
    
    if ($buildTools) {
        $apksigner = "$($buildTools.FullName)\apksigner.bat"
        if (Test-Path $apksigner) {
            return $apksigner
        }
    }
    
    return $null
}

$script:KeytoolPath = Find-Keytool
$script:ApksignerPath = Find-Apksigner

function Show-Menu {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  S1 Forum App - Build Menu" -ForegroundColor Cyan
    Write-Host "  (Release builds: obfuscate + split-debug-info)" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Check signing status
    $keystoreExists = Test-Path "android\key.jks"
    $keyPropsExists = Test-Path "android\app\key.properties"
    
    if ($keystoreExists -and $keyPropsExists) {
        Write-Host "  [Status] Signing configured" -ForegroundColor Green
    } else {
        Write-Host "  [Status] Signing NOT configured" -ForegroundColor Red
    }
    Write-Host ""
    
    Write-Host "  [1] Split APKs (Recommended)" -ForegroundColor Green
    Write-Host "      -> armeabi-v7a / arm64-v8a / x86_64"
    Write-Host ""
    Write-Host "  [2] Single APK (All architectures)" -ForegroundColor Yellow
    Write-Host "      -> For direct distribution, larger file"
    Write-Host ""
    Write-Host "  [3] Android App Bundle (AAB)" -ForegroundColor Yellow
    Write-Host "      -> For Google Play Store"
    Write-Host ""
    Write-Host "  [4] Debug Build" -ForegroundColor Yellow
    Write-Host "      -> For development and testing"
    Write-Host ""
    Write-Host "  [5] Analyze APK Size" -ForegroundColor Magenta
    Write-Host "      -> View size breakdown by component"
    Write-Host ""
    Write-Host "  [6] Web Build" -ForegroundColor Cyan
    Write-Host "      -> Build web version"
    Write-Host ""
    Write-Host "  [7] Verify APK Signature" -ForegroundColor White
    Write-Host "      -> Check if APK is properly signed"
    Write-Host ""
    Write-Host "  [0] Exit" -ForegroundColor Gray
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
}

function Test-SigningConfig {
    $keystorePath = "android\key.jks"
    $keyPropsPath = "android\app\key.properties"
    
    if (-not (Test-Path $keystorePath)) {
        Write-Host ""
        Write-Host "Error: Keystore not found at $keystorePath" -ForegroundColor Red
        Write-Host "Please contact admin to setup signing." -ForegroundColor Yellow
        return $false
    }
    
    if (-not (Test-Path $keyPropsPath)) {
        Write-Host ""
        Write-Host "Error: key.properties not found at $keyPropsPath" -ForegroundColor Red
        return $false
    }
    
    return $true
}

function Build-SplitAPK {
    if (-not (Test-SigningConfig)) { return }

    Write-Host ""
    Write-Host "Building Split APKs with release signing + obfuscate..." -ForegroundColor Green
    Build-WithDsn @("build", "apk", "--split-per-abi", "--obfuscate", "--split-debug-info=build/debug-info")
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Build successful!" -ForegroundColor Green
        Write-Host "Output location:" -ForegroundColor Yellow
        Write-Host "  build\app\outputs\flutter-apk\"
        Get-ChildItem build\app\outputs\flutter-apk\*.apk | ForEach-Object {
            $size = [math]::Round($_.Length / 1MB, 1)
            $name = $_.Name
            Write-Host "  $name - $size MB" -ForegroundColor White
        }
        Write-Host ""
        Write-Host "Debug symbols saved to: build\debug-info\" -ForegroundColor Gray
        Write-Host "  (Keep these for crash symbolication)" -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "Build failed!" -ForegroundColor Red
    }
}

function Build-SingleAPK {
    if (-not (Test-SigningConfig)) { return }

    Write-Host ""
    Write-Host "Building single APK with release signing + obfuscate..." -ForegroundColor Green
    Build-WithDsn @("build", "apk", "--obfuscate", "--split-debug-info=build/debug-info")
    if ($LASTEXITCODE -eq 0) {
        $apk = Get-ChildItem build\app\outputs\flutter-apk\app-release.apk -ErrorAction SilentlyContinue
        if ($apk) {
            $size = [math]::Round($apk.Length / 1MB, 1)
            $path = $apk.FullName
            Write-Host ""
            Write-Host "Build successful!" -ForegroundColor Green
            Write-Host "Output: $path - $size MB" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Debug symbols saved to: build\debug-info\" -ForegroundColor Gray
            Write-Host "  (Keep these for crash symbolication)" -ForegroundColor Gray
        }
    } else {
        Write-Host ""
        Write-Host "Build failed!" -ForegroundColor Red
    }
}

function Build-AAB {
    if (-not (Test-SigningConfig)) { return }

    Write-Host ""
    Write-Host "Building Android App Bundle with release signing + obfuscate..." -ForegroundColor Green
    Build-WithDsn @("build", "appbundle", "--obfuscate", "--split-debug-info=build/debug-info")
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Build successful!" -ForegroundColor Green
        Write-Host "Output location:" -ForegroundColor Yellow
        Write-Host "  build\app\outputs\bundle\release\"
        Get-ChildItem build\app\outputs\bundle\release\*.aab | ForEach-Object {
            $size = [math]::Round($_.Length / 1MB, 1)
            $name = $_.Name
            Write-Host "  $name - $size MB" -ForegroundColor White
        }
        Write-Host ""
        Write-Host "Debug symbols saved to: build\debug-info\" -ForegroundColor Gray
        Write-Host "  (Keep these for crash symbolication)" -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "Build failed!" -ForegroundColor Red
    }
}

function Build-Debug {
    Write-Host ""
    Write-Host "Building Debug version (auto-signed with debug key)..." -ForegroundColor Green
    Build-WithDsn @("build", "apk", "--debug")
    if ($LASTEXITCODE -eq 0) {
        $apk = Get-ChildItem build\app\outputs\flutter-apk\app-debug.apk -ErrorAction SilentlyContinue
        if ($apk) {
            $size = [math]::Round($apk.Length / 1MB, 1)
            $path = $apk.FullName
            Write-Host ""
            Write-Host "Build successful!" -ForegroundColor Green
            Write-Host "Output: $path - $size MB" -ForegroundColor Yellow
        }
    } else {
        Write-Host ""
        Write-Host "Build failed!" -ForegroundColor Red
    }
}

function Analyze-APK {
    Write-Host ""
    Write-Host "Analyzing APK size..." -ForegroundColor Magenta
    Write-Host "Building and analyzing arm64 version..." -ForegroundColor Gray
    Build-WithDsn @("build", "apk", "--target-platform", "android-arm64", "--analyze-size", "--obfuscate", "--split-debug-info=build/debug-info")
}

function Build-Web {
    Write-Host ""
    Write-Host "Building Web version..." -ForegroundColor Cyan
    Build-WithDsn @("build", "web", "--release")
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Build successful!" -ForegroundColor Green
        Write-Host "Output: build\web\" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "Build failed!" -ForegroundColor Red
    }
}

function Verify-Signature {
    Write-Host ""
    Write-Host "Verifying APK signature..." -ForegroundColor White
    
    # Find APK to verify
    $apkPath = $null
    
    # Try split APK first
    $splitApk = Get-ChildItem build\app\outputs\flutter-apk\app-arm64-v8a-release.apk -ErrorAction SilentlyContinue
    if ($splitApk) {
        $apkPath = $splitApk.FullName
    }
    
    # Try single APK
    if (-not $apkPath) {
        $singleApk = Get-ChildItem build\app\outputs\flutter-apk\app-release.apk -ErrorAction SilentlyContinue
        if ($singleApk) {
            $apkPath = $singleApk.FullName
        }
    }
    
    if (-not $apkPath) {
        Write-Host ""
        Write-Host "No APK found. Please build first (option 1 or 2)." -ForegroundColor Yellow
        return
    }
    
    Write-Host "Verifying: $apkPath" -ForegroundColor Gray
    Write-Host ""
    
    if ($script:ApksignerPath) {
        & $script:ApksignerPath verify --print-certs $apkPath
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "Signature is VALID" -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "Signature verification FAILED" -ForegroundColor Red
        }
    } else {
        Write-Host "apksigner not found. Using jarsigner..." -ForegroundColor Yellow
        if ($script:KeytoolPath) {
            $jarsignerPath = $script:KeytoolPath.Replace("keytool.exe", "jarsigner.exe")
            if (Test-Path $jarsignerPath) {
                & $jarsignerPath -verify -verbose $apkPath
            } else {
                Write-Host "jarsigner not found at: $jarsignerPath" -ForegroundColor Red
            }
        } else {
            Write-Host "No signing tools found. Please install Java/JDK." -ForegroundColor Red
        }
    }
}

# Main loop
do {
    Show-Menu
    $choice = Read-Host "Select (0-7)"
    
    switch ($choice) {
        "1" { Build-SplitAPK }
        "2" { Build-SingleAPK }
        "3" { Build-AAB }
        "4" { Build-Debug }
        "5" { Analyze-APK }
        "6" { Build-Web }
        "7" { Verify-Signature }
        "0" { 
            Write-Host ""
            Write-Host "Goodbye!" -ForegroundColor Cyan
            return 
        }
        default { 
            Write-Host ""
            Write-Host "Invalid choice, please try again" -ForegroundColor Red 
        }
    }
    
    if ($choice -ne "0") {
        Write-Host ""
        Write-Host "Press any key to return to menu..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
} while ($choice -ne "0")
