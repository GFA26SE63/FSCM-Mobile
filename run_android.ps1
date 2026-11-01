# Run FSCM Mobile on a physical Android phone (USB) against the local backend.
#
# Why: on a phone, "localhost" is the phone itself, not your PC.
# This script forwards ports 7027 (HTTPS) and 5246 (HTTP) from the phone
# to the PC over USB (`adb reverse`), then launches the app.
#
# Usage: .\run_android.ps1            (first connected device)
#        .\run_android.ps1 -Device <id>
param(
  [string]$Device = ""
)

$adb = Get-Command adb -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $adb) {
  $adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
}

& $adb reverse tcp:7027 tcp:7027
& $adb reverse tcp:5246 tcp:5246
if ($LASTEXITCODE -ne 0) {
  Write-Error "adb reverse failed. Is the phone connected with USB debugging enabled?"
  exit 1
}

$runArgs = @("run")
if ($Device -ne "") { $runArgs += @("-d", $Device) }
flutter @runArgs
