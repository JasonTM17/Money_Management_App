# Technical Design

## Architecture

CashFlow Manager is an offline-first Flutter finance app with a separate Fastify/Prisma backend foundation for optional authenticated sync and AI-assisted analysis. The mobile app remains useful without an account, backend, network connection, PostgreSQL, or n8n.

```text
Flutter mobile app (offline-first)
  ├─ App shell, theme, localization
  ├─ FinanceController (Riverpod)
  ├─ LocalFinanceStore (SQLite)
  ├─ FinanceCalculator
  ├─ Export, backup, privacy lock services
  └─ Optional RemoteSyncClient
        ↓ HTTPS/OpenAPI
Fastify API service
  ├─ Auth, JWT, and JWKS
  ├─ Finance CRUD routes with soft deletes and revisions
  ├─ Sync bootstrap, changes, push, conflict, and idempotency routes
  ├─ Household, shared budget, entitlement, IAP, and SePay foundations
  ├─ Optional n8n AI analysis proxy
  ├─ Health/readiness checks
  └─ PostgreSQL persistence
        ↓ HMAC webhook
n8n automation
  └─ OpenAI-compatible chat completions workflow
```

Direct Flutter-to-PostgreSQL access is rejected. Mobile clients must use the API because direct database access would expose credentials, bypass validation, and fail under normal mobile network/security constraints.

## Runtime Flow

1. `main.dart` starts `ProviderScope` and `CashFlowManagerApp`.
2. `PrivacyGate` protects the app when a local PIN exists and relocks on lifecycle changes.
3. `HomeScreen` watches `financeControllerProvider`.
4. `FinanceController` loads and writes data through `LocalFinanceStore`.
5. `LocalFinanceStore` persists data in SQLite and seeds starter wallets/categories.
6. `FinanceCalculator` derives balances, monthly totals, budget alerts, future recurring forecast, and saving suggestions.
7. Optional remote sync uses `RemoteSyncClient` against the OpenAPI-backed API without blocking local writes.

## State Management

Riverpod `AsyncNotifierProvider` owns async loading and write commands. UI renders loading/error/data states. The sync boundary remains under the controller/client layer; UI state does not move directly to the backend.

## Localization

The app uses Flutter localization delegates plus a lightweight `AppLocalizations` map for Vietnamese, English, and Japanese. The selected locale is persisted through `LocaleController`, defaults to Vietnamese, and is switchable from Settings. New privacy/backend/sync/auth UI copy must be added for all three languages.

## Persistence

SQLite database file: `cashflow_manager.sqlite` in app documents directory. Schema is created with `create table if not exists`. Data reloads into `FinanceState`, including the active report month used by reports and forecast widgets. Foreign keys are enabled at connection level; stronger table-level FK/check constraints remain a hardening follow-up.

## Backend API

The backend is a separate API service with PostgreSQL behind it. It validates finance resources, owns authenticated account data, exposes readiness endpoints, and provides the server side of bidirectional sync plus foundations for households, entitlements, Store IAP verification, and off-store SePay orders. The mobile app release version and backend/API package version are versioned independently.

Current backend responsibilities:

- `GET /healthz` and `GET /readyz` for process/dependency checks.
- `GET /.well-known/jwks.json` for JWT verifier key discovery.
- Auth/account routes for optional sync accounts.
- Finance CRUD routes for wallets, categories, transactions, budgets, and saving goals.
- Sync bootstrap, changes, and push routes with revision conflict detection and client mutation idempotency.
- Household membership, invite, and shared budget foundations.
- Premium entitlement state, Store IAP verification hook, and SePay direct/off-store order/webhook foundations.
- Optional `/v1/ai/analysis` proxy to an HMAC-protected n8n workflow.
- Stable OpenAPI 3.1 contract in `docs/openapi.yaml` as the source of truth.

Current non-goals:

- Bank integrations.
- OCR receipts.
- Replacing Flutter with a web frontend.

## Sync Model

Sync is opt-in and must never be required for local app usage.

Implemented server-side sync rules:

- Local writes remain immediate.
- Server records include `user_id`, `created_at`, `updated_at`, `deleted_at`, and `revision`.
- Local dirty rows carry the base remote revision they were edited from.
- Server revision is authoritative for acknowledged remote state.
- `POST /v1/sync/push` rejects stale `baseRevision` with `409 sync_conflict`; no silent overwrite.
- `clientMutationId` deduplicates retried mutations.
- `GET /v1/sync/changes?since=...` returns ordered sync events after the cursor.
- Transfers must sync atomically so the source and target wallet effects cannot split.

## Security and Privacy

- Offline-first by default.
- PIN uses salted PBKDF2-HMAC-SHA256 before secure storage, with legacy SHA-256 PIN hashes migrated after successful unlock.
- Repeated failed PIN attempts trigger a 5-minute cooldown and reset after successful PIN verification.
- The privacy gate relocks when the app leaves foreground and requires unlock again on resume.
- Biometric auth is opt-in and uses `local_auth` with biometric-only authentication for privacy unlock and re-auth actions.
- Backup restore previews imported counts, requires confirmation, rejects files larger than 5 MB, and requires re-authentication before replacing local data.
- Data reset requires confirmation and re-authentication when a privacy PIN exists.
- CSV export escapes formula-leading values before spreadsheet use.
- Export and backup UI warns before sharing sensitive financial data.
- No secrets or user financial data are logged.
- Backend auth protects cloud data; local PIN and opt-in biometric preferences protect the device and are not synced.

## Platform Notes

Android uses `FlutterFragmentActivity` for biometric compatibility. iOS builds require macOS with Xcode and the Swift toolchain installed; the iOS project includes `NSFaceIDUsageDescription` for Face ID permission copy.

## Validation Gates

Release readiness requires:

- `flutter analyze`.
- `flutter test --no-pub -r expanded`.
- `flutter test --no-pub scripts/capture_demo_media_test.dart -r expanded` when refreshing README media.
- Android debug/release APK and app bundle builds as appropriate for the release lane; Android release is verified on Windows, while iOS archive remains macOS/Xcode-only.
- `npm --prefix api run prisma:generate` before API type checks.
- API tests against PostgreSQL through Docker Compose.
- Docker Compose config, migration, seed, health, readiness, and frontend artifact checks. Docker publish mirrors API/frontend images to Docker Hub and GHCR with `latest`, git SHA, and release semver tags.
- Optional n8n workflow import/activation check when automation is enabled.
- Private-file tracked check before commits must confirm internal agent, planning, local environment, keystore, and database files are not tracked.
