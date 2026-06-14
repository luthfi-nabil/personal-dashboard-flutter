# Personal Dashboard (Flutter)

A cross-platform (mobile/desktop/web) Flutter client for the **personal-dashboard**
suite — a personal finance and insulin-tracking dashboard. It is an offline-first
port of an earlier PWA, backed by [`transaction-api`](../transaction-api) and
[`health-api`](../health-api).

## Purpose

- **Dashboard** — overview of balances, recent transactions, and quick stats.
- **Transactions** — add/edit earnings and spendings, organized by source and category.
- **Reports** — charts/summaries of income vs. spending (via `fl_chart`).
- **Insulin** — track insulin items, batch assignments, and dose usage (via `health-api`).
- **Settings** — configure API endpoints, username, theme, density, currency
  format, and contact info (email/phone/Telegram username).
- **API Watcher** — an in-app log of recent API calls (method, path, status,
  duration, errors) to diagnose connectivity issues, especially on mobile.

## Architecture

- **State management**: Riverpod (`flutter_riverpod`)
- **Routing**: `go_router` (see `lib/app.dart`)
- **Local storage**: `sqflite` (mobile) / `sqflite_common_ffi` (desktop) — the
  app works fully offline against a local SQLite cache (`lib/core/db.dart`)
- **Sync**: `lib/core/sync.dart` (`SyncService`) periodically pushes/pulls
  local changes to/from `transaction-api` (`/api/flutter/sync*`) and
  `health-api` (`/api/flutter/health-sync*`) when online (via `connectivity_plus`)
- **Remote API client**: `lib/core/remote_api.dart` (`RemoteApi`) — thin REST
  wrapper around `/api/user/{created_by}/...` endpoints, with a 10s request
  timeout and call logging to `lib/core/api_log.dart`
- **Config**: `lib/core/config.dart` (`ConfigService`) — persists `AppConfig`
  (API URLs, username, theme, etc.) via `shared_preferences`

```
lib/
  main.dart        # entrypoint: DB init, config load, seed, sync start
  app.dart         # MaterialApp.router + route table
  core/            # config, db, models, remote_api, sync, repo, api_log
  screens/         # dashboard, transactions, reports, insulin, settings,
                    # source/category detail, add-transaction, onboarding,
                    # api-log (API Watcher)
  providers/       # Riverpod providers
  theme/           # app theming
```

## Configuration

On first launch, the **onboarding** screen requires a `username` to be set —
this is used as the `created_by` path segment for all `transaction-api` /
`health-api` calls. Until a username is set, the app redirects to `/onboarding`.

All settings are editable later from the **Settings** screen and persisted
locally (`shared_preferences`):

| Setting | Default | Description |
|---|---|---|
| API base URL | `http://127.0.0.1:8080` | Base URL for `transaction-api` (default deployment uses port `3000`) |
| Health API base URL | `http://127.0.0.1:8082` | Base URL for `health-api` (default deployment uses port `4000`) |
| Username | _(empty)_ | Used as `created_by` for all API calls |
| Auto sync | `true` | Periodically sync local cache with the backends |
| Sync interval | `30s` | How often `SyncService` syncs when online |
| Theme | `ink` | UI theme |
| Density | `regular` | UI density |
| Currency format | `full` | Number/currency display format |
| Email / Phone / Telegram username | _(empty)_ | Contact info, used by `telegram-bot` integrations |

> **Running on a physical mobile device**: `127.0.0.1` refers to the device
> itself, not your development machine. Set the API base URLs to your
> machine's LAN IP (e.g. `http://192.168.1.x:3000` and `http://192.168.1.x:4000`),
> ensure both Rust APIs are started with `HOST=0.0.0.0` in their `.env`, and
> that your firewall allows inbound connections on those ports. Use the
> **API Watcher** (Settings → API Watcher) to confirm calls are succeeding.

## Running locally

```bash
flutter pub get
flutter run            # pick a connected device/emulator, or
flutter run -d chrome  # web
flutter run -d windows # desktop
```

Make sure `transaction-api` and `health-api` are running first (see their
READMEs), and that the API base URLs in Settings (or onboarding) point to them.

## Building / Deployment

```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS (on macOS)
flutter build ios --release

# Desktop
flutter build windows --release
flutter build linux --release
flutter build macos --release

# Web
flutter build web --release
```

For web builds, the backend APIs must have CORS enabled (already configured
on `transaction-api` via `actix-cors`; see [health-api README](../health-api/README.md#cors-and-logging)
for its current status) and be reachable from the browser's origin.

Deploy the built artifacts (APK/IPA for mobile, the `build/web` output behind
a static file server for web, or the platform executable for desktop) as
appropriate for your distribution channel. Update the API base URLs in
Settings to point at your deployed `transaction-api` / `health-api` instances.
