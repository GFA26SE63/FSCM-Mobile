# FSCM Mobile Client

Flutter client boundary for FSCM field and warehouse workflows. The product design includes role-specific experiences for Sales Representatives, Retail Store Managers, and Warehouse Keepers.

## Current status

The project is an application skeleton and still renders Flutter's starter counter screen. API environment mapping and a Dio client exist, and dependencies needed for routing, state management, local storage, background work, connectivity, secure storage, GraphQL, and image capture are declared. The planned role workflows and offline synchronization engine are not yet implemented.

Use the repository architecture guidance before building features:

- [Architecture assessment](../.docs/architecture/repository-skeleton.md) for boundaries and conventions

## Planned experiences

- **Sales:** cached retailer/catalog availability, offline order queue, detailed synchronization states, order tracking, promotions, retailer assessment, and KPI/revenue views.
- **Retailer:** order history, batch/quantity receipt reconciliation, photo evidence, complaints, and loyalty history/redemption. Retailers do not create orders or store-level inventory in the current scope.
- **Warehouse:** inbound receipt entry, batch/expiry capture, FEFO picking, label scanning/splitting, dispatch evidence, and damaged-stock reporting.

## Prerequisites

- Flutter 3.44 / Dart 3.12 or a compatible newer toolchain
- A configured Android, iOS, desktop, or web target supported by the project

## Configuration

The client reads compile-time values through `String.fromEnvironment`:

| Define | Default | Purpose |
| --- | --- | --- |
| `API_BASE_URL` | `https://localhost:7027` | REST/API base URL |
| `GRAPHQL_ENDPOINT` | `<API base URL>/graphql` | GraphQL endpoint |

Pass them directly when running:

```powershell
flutter run --dart-define=API_BASE_URL=https://localhost:7027 --dart-define=GRAPHQL_ENDPOINT=https://localhost:7027/graphql
```

Alternatively, create an ignored JSON file such as `env/appsettings.json` and run:

```powershell
flutter run --dart-define-from-file=env/appsettings.json
```

Example file shape:

```json
{
  "API_BASE_URL": "https://localhost:7027",
  "GRAPHQL_ENDPOINT": "https://localhost:7027/graphql"
}
```

`localhost` refers to the device itself. For an emulator or physical device, use an API address reachable from that device; Android Emulator commonly reaches the development host at `10.0.2.2`. Local HTTPS also requires a certificate trusted by the target device.

## Development and validation

```powershell
flutter pub get
flutter run
flutter analyze
flutter test
```

## Source layout

```text
lib/
|-- config/          Compile-time environment values
|-- core/network/    Shared Dio client
|-- features/        Feature modules (currently a template boundary)
|-- shared/rbac/     Reserved authorization conventions
`-- main.dart        Current application entry screen
```

Offline-first behavior is a business requirement, not a completed capability. Feature implementation must persist the required read models and order queue in SQLite, expose `not synced` / `syncing` / `synced` states, retry safely in background work, and let the server resolve inventory conflicts authoritatively during synchronization.
