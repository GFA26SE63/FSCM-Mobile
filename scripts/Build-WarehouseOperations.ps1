[CmdletBinding()]
param([string]$ApiBaseUrl = 'https://app-fmcg-api-dev-e4f6bdg2h2bfehbq.southeastasia-01.azurewebsites.net/api/v1')
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
Push-Location $project
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Could not restore mobile dependencies.' }
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'Mobile analysis failed.' }
    flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Mobile tests failed.' }
    flutter build apk --debug "--dart-define=API_BASE_URL=$ApiBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
    Write-Host ('APK READY: ' + (Join-Path $project 'build/app/outputs/flutter-apk/app-debug.apk'))
    Write-Host 'Install this APK on the warehouse phone to use the new workflows. Updating the website does not update an installed app.'
} finally { Pop-Location }
