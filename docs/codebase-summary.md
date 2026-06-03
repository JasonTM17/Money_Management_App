# Codebase Summary / Tổng quan mã nguồn / コードベース概要

How the codebase is organized, where to find things, and conventions to follow.

## Project Tree

```
MoneyMangement_App/
├── lib/                          # Flutter application (Dart)
│   ├── main.dart                 # Entry point: ProviderScope + CashFlowManagerApp
│   ├── app/                      # App shell & shared infrastructure
│   │   ├── animated_balance.dart # Animated counter widget for balances
│   │   ├── app_localizations.dart# VI/EN/JA localization maps (AppLocalizations)
│   │   ├── app_theme.dart        # ThemeData, color scheme, text styles
│   │   └── shimmer_loading.dart  # Skeleton loading placeholders
│   ├── core/                     # Business logic & models (no Flutter UI dependency)
│   │   ├── finance_models.dart   # Wallet, Transaction, Budget, Goal, Category types
│   │   ├── money.dart            # Integer-based money arithmetic (VND)
│   │   ├── finance_calculator.dart# Derived: balances, forecasts, budget alerts
│   │   ├── export_service.dart   # CSV & PDF export (formula escaping)
│   │   ├── finance_backup_service.dart# Encrypted backup/restore (AES-GCM)
│   │   ├── privacy_lock_service.dart # PBKDF2 PIN + biometric unlock
│   │   ├── remote_sync_client.dart# OpenAPI sync client (HTTP + JWT)
│   │   ├── remote_session_store.dart# Secure token storage
│   │   ├── sync_models.dart      # Sync data types (cursor, revision, mutation)
│   │   ├── sync_auth_models.dart # Auth request/response types
│   │   └── sync_change_models.dart# Change event types for sync
│   ├── data/                     # Persistence layer (SQLite)
│   │   ├── local_finance_store.dart# Public API (facade over sub-modules)
│   │   ├── local_store_core.dart # DB open, schema create, helper methods
│   │   ├── local_store_budget_operations.dart
│   │   ├── local_store_goal_operations.dart
│   │   ├── local_store_transaction_operations.dart
│   │   ├── local_store_sync_operations.dart
│   │   ├── local_store_backup_restore.dart
│   │   ├── local_store_migration.dart
│   │   └── local_store_validation.dart
│   └── features/                 # Screen features (thin UI, delegates to core)
│       ├── home/                 # Dashboard, transactions, wallets, budgets, reports
│       ├── auth/                 # Login, register UI
│       └── account/              # Account settings, sync status
│
├── api/                          # Fastify API service (TypeScript)
│   ├── src/
│   │   ├── main.ts               # Server entry: listen on API_PORT
│   │   ├── app.ts                # App factory: buildApp(opts) → Fastify instance
│   │   ├── lib/
│   │   │   ├── env.ts            # Zod-validated environment config
│   │   │   └── prisma-client.ts  # Prisma client singleton factory
│   │   └── modules/
│   │       ├── auth/             # Register, login, refresh, logout, JWT/JWKS
│   │       ├── finance/          # CRUD wallets, categories, transactions, budgets, goals
│   │       ├── sync/             # Bootstrap, changes, push, conflict resolution
│   │       ├── ai/               # AI analysis proxy → HMAC webhook → n8n
│   │       ├── health/           # /healthz, /readyz
│   │       └── well-known/       # /.well-known/jwks.json
│   ├── prisma/
│   │   ├── schema.prisma         # Data model: User, Wallet, Transaction, etc.
│   │   ├── migrations/           # Prisma migration history
│   │   └── seed.ts               # Demo data seeder
│   ├── prisma.config.ts          # Prisma config (datasource URL)
│   ├── package.json              # Dependencies & scripts
│   ├── tsconfig.json             # TypeScript config
│   └── vitest.config.ts          # Vitest test runner config
│
├── docs/                         # Project documentation
│   ├── README.md                 # Doc index (VI/EN/JA)
│   ├── system-architecture.md    # C4 architecture diagrams
│   ├── project-overview-pdr.md   # Product requirements & scope
│   ├── technical-design.md       # Detailed technical design
│   ├── system-diagrams.md        # Mermaid.js sequence & flow diagrams
│   ├── codebase-summary.md       # This file
│   ├── code-standards.md         # Coding standards & conventions
│   ├── design-guidelines.md      # UI tokens & design system
│   ├── database-schema.md        # SQLite & PostgreSQL schema notes
│   ├── ui-flow.md                # Screen map & user journeys
│   ├── product-requirements.md   # Personas & MVP details
│   ├── project-roadmap.md        # Version timeline
│   ├── deployment-guide.md       # Deployment instructions
│   ├── test-plan.md              # Test strategy
│   ├── qa-report.md              # QA results & known issues
│   ├── release-checklist.md      # Release gates checklist
│   ├── openapi.yaml              # OpenAPI 3.1 contract
│   ├── adr/                      # Architectural Decision Records
│   └── media/                    # Screenshots & GIFs
│
├── test/                         # Flutter unit & widget tests
│   ├── widget_test.dart          # Smoke test
│   ├── features/                 # Widget tests per screen
│   └── helpers/                  # Test utilities
├── integration_test/             # Flutter integration tests
│   └── cashflow_smoke_test.dart  # Full flow: PIN → dashboard → transactions
├── scripts/                      # Utility scripts
│   ├── capture_demo_media_test.dart# Demo GIF/screenshot capture
│   ├── mock-openai-compatible-provider.mjs
│   ├── smoke-test-docker-stack.ps1
│   └── smoke-test-n8n-ai.ps1
├── assets/                       # Brand assets & fonts
│   ├── brand/                    # Logo (PNG)
│   └── fonts/                    # BeVietnamPro + Noto Sans JP
├── .github/workflows/            # CI/CD pipelines
│   ├── ci.yml                    # Main CI: Flutter, API, Docker, emulator
│   ├── release.yml               # Tagged release: APK, AAB, IPA
│   ├── docker-publish.yml        # GHCR + Docker Hub multi-arch push
│   ├── security.yml              # Gitleaks, Trivy, dependency audit
│   ├── codeql.yml                # GitHub CodeQL SAST
│   └── dependabot-auto-merge.yml # Auto-merge patch/minor Dependabot PRs
├── infra/n8n/workflows/          # n8n workflow JSON exports
├── docker-compose.yml            # Full stack (9 services)
├── docker-compose.local.yml      # Local port remap variant
├── Dockerfile.frontend           # Nginx APK artifact server
├── README.md                     # Project root README (VI/EN/JA)
└── README.vi.md / README.ja.md   # Localized READMEs
```

## Key Modules — What They Do

### Flutter: `lib/core/`
| File | Responsibility |
|------|---------------|
| `finance_models.dart` | All domain types: Wallet, Transaction, Budget, SavingGoal, Category, FinanceState |
| `money.dart` | `Money.fromVnd(int)`, `Money.zero`, arithmetic operators — all integer-based |
| `finance_calculator.dart` | Stateless: monthly totals, budget alerts, cashflow forecast, saving suggestions |
| `export_service.dart` | CSV export with `'` prefix for formula cells; PDF report generation |
| `finance_backup_service.dart` | Schema v2 AES-GCM encrypt + v1 plaintext import; 5 MB size limit |
| `privacy_lock_service.dart` | PBKDF2-HMAC-SHA256 hash, cooldown timer, biometric opt-in via `local_auth` |
| `remote_sync_client.dart` | HTTP client against OpenAPI contract; JWT auth header; conflict handling |

### Flutter: `lib/data/`
| File | Responsibility |
|------|---------------|
| `local_finance_store.dart` | Public API facade — delegates to domain sub-modules |
| `local_store_core.dart` | `openDatabase()`, schema DDL, foreign keys, helper queries |
| `local_store_budget_operations.dart` | Budget CRUD + monthly tracking |
| `local_store_goal_operations.dart` | SavingGoal CRUD + contribution tracking |
| `local_store_transaction_operations.dart` | Transaction CRUD + search + filters |
| `local_store_sync_operations.dart` | Dirty-row tracking, revision metadata |
| `local_store_backup_restore.dart` | Full DB export/import for backup |
| `local_store_migration.dart` | Schema version migrations |
| `local_store_validation.dart` | Referential integrity checks |

### API: `api/src/modules/`
| Module | Routes | Key Logic |
|--------|--------|-----------|
| `auth/` | register, login, refresh, logout | Ed25519 JWT sign/verify, refresh token rotation, rate limiting |
| `finance/` | CRUD wallets, categories, transactions, budgets, goals | Ownership validation, soft delete, revision increment |
| `sync/` | bootstrap, changes, push | Conflict detection (409 on stale baseRevision), idempotency |
| `ai/` | POST /v1/ai/analysis | HMAC sign payload → n8n webhook → return AI response |
| `health/` | GET /healthz, /readyz | Process + DB connectivity check |
| `well-known/` | GET /.well-known/jwks.json | Public key publication for JWT verification |

## Data Flow

```
User taps "Add Transaction"
  → Screen calls FinanceController.addTransaction()
    → Controller validates via FinanceCalculator
      → LocalFinanceStore.insertTransaction() writes to SQLite (immediate)
        → Store increments revision, marks row dirty
          → FinanceState rebuilds → UI updates
            → (Optional) RemoteSyncClient.pushChanges() sends to API
              → API validates ownership, checks baseRevision
                → 200: mark clean in local DB
                → 409: keep local data, surface conflict
```

## Conventions

- **File naming**: kebab-case with descriptive names (`local_store_budget_operations.dart`)
- **Modularization**: files >200 lines → split by domain concern
- **State management**: Riverpod `AsyncNotifierProvider` for async data; `StateProvider` for simple UI state
- **API design**: One module per domain; each module has routes + service + tests
- **Testing**: `test/` for unit/widget tests; `integration_test/` for full-flow smoke tests
- **Commits**: Conventional Commits (`feat(scope):`, `fix(scope):`, `test(scope):`, etc.)
- **Branching**: Single `master` branch; feature work via local only (solo contributor)

## Entry Points

| Environment | Entry | Command |
|-------------|-------|---------|
| Flutter dev | `lib/main.dart` | `flutter run` |
| Flutter test | `test/` | `flutter test` |
| Flutter integration | `integration_test/` | `flutter test integration_test/` |
| API dev | `api/src/main.ts` | `cd api && npm run dev` |
| API test | `api/src/**/*.test.ts` | `cd api && npm test` |
| Docker full stack | `docker-compose.yml` | `docker compose up -d` |
| Docker tools only | `docker-compose.yml` profiles | `docker compose --profile tools run migrate` |
