# WMS Mobile (Flutter)

Mobile + Web client for the InventorOS-based WMS backend. Scope-first on
**inspection (検品)** and **attachment upload** (image / PDF / Office / video),
with an offline queue that replays mutations when connectivity returns.

## Requirements

- Flutter SDK `>=3.4.0 <4.0.0` (Dart 3). Not bundled in this repo — install from
  https://docs.flutter.dev/get-started/install.
- The backend running and reachable (see `../backend`). Default API base URL is
  `http://localhost/api/v1`.

## Setup

```bash
cd mobile
flutter pub get

# Drift generates offline_database.g.dart from the table definitions.
dart run build_runner build --delete-conflicting-outputs
```

Without the code generation step the app will not compile: `offline_database.dart`
references the generated `_$OfflineDatabase` and companion classes.

## Web (Drift/SQLite) assets — required for `-d chrome` / `flutter build web`

On the web target Drift runs SQLite as WebAssembly, so two version-matched
binaries must be present in `web/` before the app can start. Without them the
first `driftDatabase()` call throws at runtime and the app renders a blank page
(unit tests do **not** catch this — they use `NativeDatabase.memory()` directly).

- `web/sqlite3.wasm` — match the installed `sqlite3` package version.
- `web/drift_worker.js` — match the installed `drift` package version.

Fetch the exact versions listed in `pubspec.lock` (currently `sqlite3 2.9.4`,
`drift 2.31.0`) from the upstream GitHub releases:

```bash
cd mobile/web
gh release download sqlite3-2.9.4 -R simolus3/sqlite3.dart -p "sqlite3.wasm"
gh release download drift-2.31.0  -R simolus3/drift        -p "drift_worker.js"
```

`OfflineDatabase` passes these paths via `DriftWebOptions(sqlite3Wasm: ...,
driftWorker: ...)` — the `web:` argument is mandatory on the web build.

## Configuring the API base URL

`lib/core/config/app_config.dart` reads `API_BASE_URL` from the Dart environment:

```bash
# Web
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost/api/v1

# Device / emulator (Android emulator reaches host via 10.0.2.2)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2/api/v1
```

## Platform folders

Only `lib/` and `pubspec.yaml` are checked in. Generate the platform scaffolding
once with the SDK:

```bash
flutter create --platforms=android,ios,web .
```

## Tests

```bash
flutter test
```

Coverage targets the offline sync worker, the inspection repository, domain JSON
parsing, and the list screen widget:

| Test | What it covers |
|------|----------------|
| `test/core/offline/offline_sync_service_test.dart` | FIFO drain, offline retry, 4xx poison-drop, auto-flush on reconnect (in-memory Drift) |
| `test/features/inspection/data/inspection_repository_test.dart` | Response mapping + Laravel error/`null`-status handling (mocked Dio) |
| `test/features/inspection/domain/inspection_parsing_test.dart` | `fromJson` for nested items/attachments |
| `test/features/inspection/presentation/inspection_list_screen_test.dart` | List tiles + empty state (provider override) |

## Offline queue

Mutations (record item / complete / upload attachment) are attempted online
first. On a network failure (no HTTP status) they are appended to the Drift
`QueuedMutations` table. `OfflineSyncService` drains the queue in FIFO order on
app start (if online) and whenever `connectivity_plus` reports connectivity is
regained. Server-side 4xx rejections are dropped so they cannot block the queue;
5xx and network errors are retried.
