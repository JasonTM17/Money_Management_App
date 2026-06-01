# Test Plan

## Automated Commands

```bash
flutter analyze --no-pub
flutter test --no-pub -r expanded
flutter test --no-pub scripts/capture_demo_media_test.dart -r expanded
flutter build apk --debug --no-pub
flutter build apk --release --no-pub
flutter build appbundle --release --no-pub
```

Backend/API checks:

```bash
npm --prefix api ci
npm --prefix api run prisma:generate
npm --prefix api run typecheck
npm --prefix api test
npm --prefix api run build
```

Docker readiness checks:

```bash
docker compose config --quiet
docker compose up --build -d postgres
docker compose --profile tools run --rm --build migrate
docker compose --profile tools run --rm --build seed
docker compose up --build -d api frontend
.\scripts\smoke-test-docker-stack.ps1 -ApiBaseUrl http://localhost:3001 -FrontendBaseUrl http://localhost:8081
```

n8n ChatbotAI smoke checks with a local mock provider:

```powershell
node scripts/mock-openai-compatible-provider.mjs
$env:N8N_AI_CHAT_COMPLETIONS_URL = 'http://host.docker.internal:4567/v1/chat/completions'
$env:N8N_AI_API_KEY = 'local-mock-token'
$env:N8N_AI_MODEL = 'local-mock-model'
$env:N8N_CHATBOT_WEBHOOK_SECRET = 'replace-with-local-webhook-hmac-secret'
docker compose --profile automation up --build -d n8n-postgres n8n
docker compose --profile automation run --rm n8n-import
docker compose --profile automation run --rm n8n-activate
.\scripts\smoke-test-n8n-ai.ps1
```

Expected result: invalid HMAC is rejected with zero mock-provider calls, then valid HMAC returns strict JSON `{ answer, suggestions }`, exactly one mock-provider call, and 3-5 non-empty suggestions. Run this mock-provider smoke before any real AI-provider token test.

Provider-bound data minimization:

- The API sends only `{ question, locale }` to the n8n webhook.
- The n8n provider prompt sends only `{ question, locale }` as the user message to the AI provider.
- ChatbotAI must respond as a conservative finance coach, not a bank/account data agent.
- Responses must not claim access to bank accounts, transactions, wallets, files, external services, or hidden app data.
- The workflow/API contract is strict JSON `{ answer, suggestions }`; `suggestions` must contain 3-5 short non-empty items.

## Unit Tests

| Area | Coverage |
|---|---|
| Money parsing | Empty, zero, formatted VND |
| Wallet balance | Income, expense, transfer |
| Budget warning | 90% threshold |
| Saving goals | Required monthly saving |
| Export | Empty CSV, selected-month report text, PDF payload |
| Forecast | Future recurring occurrences and month-end day clamping |
| Privacy lock | PBKDF2 PIN verify, invalid PIN rejection, legacy hash migration, failed-attempt cooldown reset/lockout, biometric opt-in storage/auth gating |
| Remote sync client | API DTO parsing and request validation boundaries |
| Remote account controller | Secure token persistence, login/register/logout, entitlement refresh, offline-safe local logout |

## Backend API Tests

| Area | Coverage |
|---|---|
| Auth/account | Invalid register, bearer requirements, refresh/logout boundaries |
| Finance CRUD | Wallet/category/transaction/budget/saving-goal create, patch, soft delete, user isolation, invalid references |
| Sync | Bootstrap, changes cursor, push idempotency, stale `baseRevision` conflict with `409 sync_conflict`, tombstone events |
| Households | Owner/member permissions, invite token validation, invite accept, member removal, shared budget owner-only writes |
| Entitlements | Premium true/false states and locked feature list |
| Store IAP | Disabled-by-default provider failure and mocked verification path |
| SePay | Store-build disabled order path, direct/off-store order idempotency, HMAC webhook rejection, paid webhook entitlement grant |
| n8n AI | HMAC signing, timeout, invalid JSON, invalid response shape, unavailable workflow |

## Widget Tests

- Privacy lock first-run PIN, existing PIN unlock, biometric opt-in visibility, and lifecycle relock flows.
- Data reset requires confirmation plus PIN re-authentication when a privacy PIN exists.
- Dashboard shell renders app title, app-bar add/settings actions, total balance section, and chart semantics.
- Budget create/delete and saving goal create/delete flows.
- Wallet transfer updates source and target balances and rejects same-wallet transfer.
- Transaction search, filter, edit, delete, and transfer-row behavior.
- Report insight, forecast, selected-month localized CSV/PDF preview, and backup/restore entry flows.
- Reset confirmation and sensitive-data warning copy.
- Privacy gate and Settings privacy status render polished PIN fallback plus biometric opt-in UI, not placeholder controls.
- Language switching across Vietnamese, English, and Japanese for core navigation/settings/report copy.
- Test overrides Riverpod store to avoid native plugin dependency.

## Demo Media Tests

`scripts/capture_demo_media_test.dart` captures README media from seeded fake financial data only:

- `docs/media/hero-dashboard.png`
- `docs/media/screenshot-dashboard.png`
- `docs/media/screenshot-transactions.png`
- `docs/media/screenshot-wallets.png`
- `docs/media/screenshot-wallets-budgets.png`
- `docs/media/screenshot-reports.png`
- `docs/media/screenshot-privacy-settings.png`

After capture, regenerate `docs/media/demo-cashflow-flow.gif` from fake-data screenshots only. Do not include real finance data, secrets, local paths, terminal output, or visible n8n credentials.

## Manual QA Checklist

- [ ] App launches on Android emulator/device.
- [ ] First-run PIN setup gates the dashboard.
- [ ] Existing PIN unlock works and lifecycle relock returns to the privacy gate.
- [ ] Wrong PIN cooldown shows localized copy instead of raw errors.
- [ ] Dashboard shows seeded balances and transactions.
- [ ] Add expense with invalid amount shows validation error.
- [ ] Add expense with valid amount closes sheet and refreshes list.
- [ ] Bottom navigation switches between the five primary tabs: Dashboard, Transactions, Wallets, Budgets, and Reports.
- [ ] App-bar Add opens the quick transaction sheet and app-bar Settings opens settings without covering scroll content.
- [ ] Reports chart, category pie, forecast cards, CSV preview, and PDF share render without crash.
- [ ] Settings screen shows privacy lock, biometric opt-in, account/sync, language/theme, backup/restore, and reset data entries.
- [ ] Settings account/sync panel opens login/register sheet, shows signed-in state, refreshes entitlement status, and logs out without touching local finance data.
- [ ] Backup restore preview appears before replacement and re-auth is required.
- [ ] Reset data requires confirmation and re-auth before deleting local data.
- [ ] iOS archive path is verified on macOS with Xcode and Swift installed before App Store packaging.

## Edge Cases

- Negative/zero amount rejected.
- Wallet transfer logic keeps total balance constant.
- Budget near limit triggers alert.
- Month without transactions returns zero income/expense.
- Export with empty data still has CSV headers.
- Selected report month excludes transactions from other months.
- Backup restore rejects unsupported schema and oversized files before replacing data.
- Backup restore requires re-authentication before confirmed replacement when a privacy PIN exists.
- VND formatting has zero decimals.
