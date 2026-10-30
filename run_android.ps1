# Run FSCM Mobile on any Android phone (USB or Wi-Fi) against the local backend.
#
# Automatically configures `adb reverse` (ports 7027 and 5246) for ALL connected
# Android devices so `localhost:7027` on every phone forwards to your PC.
# Also detects your PC's Wi-Fi/LAN IP and passes it via `--dart-define=LAN_HOST=...`
# as an automatic fallback when the USB cable is unplugged.
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

if (Test-Path $adb) {
  $serials = & $adb devices |
    Select-String "\tdevice$" |
    ForEach-Object { ($_ -split "\t")[0].Trim() }
  foreach ($s in $serials) {
    & $adb -s $s reverse tcp:7027 tcp:7027 | Out-Null
    & $adb -s $s reverse tcp:5246 tcp:5246 | Out-Null
    Write-Host "Configured adb reverse (7027, 5246) for device $s"
  }
}

$lanIp = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object {
    $_.IPAddress -notlike '127.*' -and
    $_.IPAddress -notlike '169.254.*' -and
    $_.InterfaceAlias -notlike '*VMware*' -and
    $_.InterfaceAlias -notlike '*vEthernet*' -and
    $_.InterfaceAlias -notlike '*Loopback*'
  } |
  Select-Object -First 1 -ExpandProperty IPAddress

$runArgs = @("run")
if ($lanIp) {
  $runArgs += "--dart-define=LAN_HOST=$lanIp"
}
if ($Device -ne "") { $runArgs += @("-d", $Device) }
flutter @runArgs
