# Project Overview — Product Development Requirements / Tổng quan dự án / プロジェクト概要

## Purpose / Mục đích / 目的

CashFlow Manager is an **offline-first personal finance app** for Vietnamese, English, and Japanese users. It manages expenses, wallets, budgets, cashflow forecasts, saving goals, and monthly reports — entirely offline. An optional Fastify API + PostgreSQL backend enables authenticated sync and AI-assisted analysis when the user chooses to connect.

## Target Users / Người dùng mục tiêu / 対象ユーザー

| Persona | Needs |
|---------|-------|
| 🧑‍💼 Vietnamese professional | Track daily expenses in VND, manage multiple wallets (cash, bank, e-wallet) |
| 👩‍🎓 Vietnamese student | Budget monthly allowance, set saving goals |
| 🌏 Japanese/Vietnamese expat | Multi-language support, familiar UI patterns |
| 👪 Household budgeter | Shared budget tracking, transfer between wallets |

## Product Scope / Phạm vi sản phẩm / 製品範囲

### MVP v1.0 (Shipped ✅)

| Module | Features |
|--------|----------|
| **Dashboard** | Balance, income/expense, net cashflow, chart, recent transactions, budget alerts |
| **Transactions** | Income, expense, transfer; category, wallet, date, note, recurring flag |
| **Wallets** | Cash, bank, e-wallet, credit card models; transfer between wallets |
| **Budgets** | Monthly create/edit/delete; warning threshold; spent tracking |
| **Saving Goals** | Create/edit/delete; monthly saving suggestions; progress tracking |
| **Reports** | Monthly income/expense chart; category pie; top spending; forecasts |
| **Export** | CSV (formula-escaped), PDF sharing |
| **Backup** | Encrypted backup v2 (AES-GCM) + legacy v1 import; restore preview |
| **Privacy** | PIN (PBKDF2-HMAC-SHA256), biometric opt-in, lifecycle relock, cooldown |
| **Localization** | Vietnamese, English, Japanese (AppLocalizations) |
| **API** | Fastify + Prisma + PostgreSQL; JWT/JWKS; auth, finance, sync, AI proxy |
| **CI/CD** | GitHub Actions: Flutter analyze/test/build, Android emulator smoke, iOS validate, API test, Docker publish, security scans |
| **Infra** | Docker Compose: PostgreSQL, API, nginx frontend, n8n, migrate, seed |

### v1.1 (Planned)

- Multi-currency (VND, USD, JPY)
- Recurring transaction automation
- Data sync via API with offline queue

### v1.2 (Planned)

- Multi-device sync
- Web dashboard (PWA)
- Push notifications for budget alerts

### Non-Goals (explicit)

- Bank integrations
- OCR receipts
- Web frontend replacing Flutter
- Real-time collaboration

## Technical Decisions / Quyết định kỹ thuật / 技術的決定

| Decision | Rationale |
|----------|-----------|
| **Offline-first** | App must work fully without network/account/backend |
| **Flutter** | Single codebase for Android + iOS; strong local DB support |
| **SQLite local** | No server dependency for core finance operations |
| **Riverpod** | Type-safe, testable state management; compile-time safety |
| **Fastify** | High-performance Node.js HTTP framework; plugin architecture |
| **Prisma** | Type-safe database access; declarative schema; migration tooling |
| **Ed25519 JWT** | Asymmetric signing; public key discoverable via JWKS; no shared secret |
| **Integer money** | All amounts stored as integers (VND); no floating-point precision loss |
| **OpenAPI 3.1** | Canonical API contract; enables client generation and validation |
| **Docker Compose** | Reproducible local dev; 1-command full stack boot |
| **n8n** | No LLM SDK in app code; AI workflows externalized to n8n |
| **3 languages** | Target Vietnamese (primary), English, Japanese |

## Project Structure / Cấu trúc dự án / プロジェクト構造

```
MoneyMangement_App/
├── lib/                    # Flutter app source
│   ├── app/                # App shell, theme, localization, widgets
│   ├── core/               # Business logic: models, calculator, export, backup, sync
│   ├── data/               # SQLite store (modularized per domain)
│   └── features/           # Screen features (home, auth, account)
├── api/                    # Fastify API service
│   ├── src/
│   │   ├── app.ts          # Server factory
│   │   ├── lib/            # Prisma client, env validation
│   │   └── modules/        # auth, finance, sync, ai, health, well-known
│   └── prisma/             # Schema, migrations, seed
├── docs/                   # Documentation (ADRs, specs, diagrams)
├── assets/                 # Brand assets, fonts
├── scripts/                # Demo capture, mock servers, smoke tests
├── test/                   # Flutter unit & widget tests
├── integration_test/       # Flutter integration smoke test
├── infra/n8n/              # n8n workflow definitions
├── .github/workflows/      # CI/CD pipeline definitions
├── docker-compose.yml      # Full stack orchestration
├── Dockerfile.frontend     # Nginx APK artifact server
└── README.md               # Entry point (3 languages)
```

## Quality Gates / Cổng chất lượng / 品質ゲート

| Gate | Tool | Threshold |
|------|------|-----------|
| Static analysis | `flutter analyze` | zero issues |
| Unit/widget tests | `flutter test` | all passing |
| Integration smoke | Flutter integration_test | Android emulator + iOS simulator |
| API typecheck | `tsc --noEmit` | zero errors |
| API tests | Vitest | all passing |
| Secret scan | Gitleaks | zero findings |
| Container scan | Trivy | zero CRITICAL/HIGH |
| SAST | CodeQL | zero alerts |
| SBOM | Syft | generated per build |
| OpenAPI lint | Redocly | pass |

## References / Tham khảo / 参照

- [System Architecture](system-architecture.md) — C4 diagrams
- [Technical Design](technical-design.md) — detailed architecture
- [ADR Index](adr/) — architectural decision records
- [Project Roadmap](project-roadmap.md) — version timeline
- [Database Schema](database-schema.md) — data model
- [UI Flow](ui-flow.md) — screen map
- [Test Plan](test-plan.md) — test strategy
- [Release Checklist](release-checklist.md) — release gates
