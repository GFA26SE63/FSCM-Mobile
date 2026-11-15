$ErrorActionPreference = "Stop"
$webPort = 5174

flutter run `
    -d chrome `
    --web-hostname=localhost `
    --web-port=$webPort `
    --dart-define-from-file=env/appsettings.json