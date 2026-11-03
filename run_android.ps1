$ErrorActionPreference = "Stop"
$port = 7027

$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$adb = Join-Path $sdk "platform-tools\adb.exe"

if (-not (Test-Path $adb)) {
    throw "adb not found: $adb. Install Android SDK Platform-Tools or set ANDROID_HOME."
}

& $adb wait-for-device
& $adb reverse "tcp:$port" "tcp:$port"
flutter run --dart-define-from-file=config/dev.json