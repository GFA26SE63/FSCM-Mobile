# FSCM Mobile Client

[![Mobile CI](https://github.com/GFA26SE63/FSCM-Mobile/actions/workflows/mobile-ci.yml/badge.svg)](https://github.com/GFA26SE63/FSCM-Mobile/actions/workflows/mobile-ci.yml)

Flutter client boundary for FSCM field and warehouse workflows. The product design includes role-specific experiences for Sales Representatives, Retail Store Managers, and Warehouse Keepers.

## Current status

The Sales Representative, Retail Store Manager, and Warehouse Keeper experiences are implemented as interactive Flutter feature slices backed by in-memory demonstration data. Sales includes authentication and onboarding, online/offline ordering, promotion-aware cart totals, synchronization states, notifications, KPI/revenue views, rankings, promotions, and potential-retailer declarations. Retailer includes order and payment history, delivery details, QR ownership checks, batch/quantity receipt reconciliation, receipt confirmation, complaints with evidence, loyalty, and notifications. Warehouse includes FEFO picking lists, source-label validation, pallet-label splitting, dispatch confirmation, label traceability, expiry visibility, and inbound receipt/label generation.

The current synchronization, QR scanning, printing, image capture, payment, receipt, picking, and dispatch flows are UI/domain simulations. SQLite persistence, camera/scanner and printer plugins, background WorkManager execution, authentication/API integration, and authoritative server-side inventory conflict handling remain integration work.

Cross-system architecture documentation is stored beside the local repositories under `FSCM/.docs` and `FSCM/diagram`.

## Related repositories

- [FSCM Backend](https://github.com/GFA26SE63/FSCM-Backend)
- [FSCM Frontend](https://github.com/GFA26SE63/FSCM-Frontend)

## Role experiences

- **Sales:** interactive component implementation available under `lib/features/sales`; API and durable offline integration remain pending.
- **Retailer:** interactive component implementation available under `lib/features/retailer`; API, camera/scanner, and durable receipt-evidence integration remain pending. Retailers do not create orders or store-level inventory.
- **Warehouse:** interactive component implementation available under `lib/features/warehouse`; inbound receipt entry, batch/expiry capture, FEFO picking, label scanning/splitting, dispatch confirmation, and traceability are implemented with demonstration state. API, scanner, printer, and durable inventory integration remain pending.

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
|-- core/theme/      FSCM visual tokens and Material theme
|-- core/widgets/    Reusable cards, status, search, and metric components
|-- features/sales/  Sales domain models, demo data, controller, and screens
|-- features/retailer/ Retailer receipt, complaint, payment, and loyalty flows
|-- features/warehouse/ Warehouse receiving, picking, labels, and dispatch flows
|-- shared/domain/   Cross-role business models
|-- shared/widgets/  Cross-role composed business widgets
|-- shared/rbac/     Reserved authorization conventions
`-- main.dart        Current application entry screen
```

The Sales UI exposes `not synced` / `syncing` / `synced` states. Production offline-first behavior must persist the required read models and order queue in SQLite, retry safely in background work, and let the server resolve inventory conflicts authoritatively during synchronization.

## Continuous integration

GitHub Actions verifies formatting, static analysis, automated tests, and an Android debug build for pushes and pull requests targeting `main` or `develop`. A separate workflow mirrors every GitHub branch to the `FSCM-Mobile` Azure Repo.
