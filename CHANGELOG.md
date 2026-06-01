# Changelog

All notable changes to CashFlow Manager are documented in this file.

## 1.0.0+1 - 2026-05-31

### Added

- Offline-first Flutter personal finance app with wallets, transactions, budgets, saving goals, reports, forecast cards, CSV/PDF export, and JSON backup/restore.
- Vietnamese, English, and Japanese localization.
- Privacy lock with salted PBKDF2-HMAC-SHA256 PIN hashing, opt-in biometric unlock, lifecycle relock, failed-attempt cooldown, and destructive-flow re-authentication.
- SQLite local persistence with integer VND money logic.
- Fastify/Prisma API foundation with PostgreSQL validation, auth/account routes, JWKS, OpenAPI contract, and optional remote sync client models.
- Docker Compose stack for PostgreSQL, API, migration/seed jobs, frontend artifact server, and optional n8n automation.
- n8n HMAC-protected AI analysis workflow using an OpenAI-compatible chat completions endpoint.
- GitHub Actions CI for Flutter, API, PostgreSQL migration/seed, Docker image builds, Android release artifacts, Docker Hub publishing, and GHCR package mirroring.
- README screenshots and demo GIF generated from deterministic fake financial data.

### Fixed

- Fixed multilingual starter/demo text encoding so Vietnamese and Japanese UI copy no longer renders as mojibake.

### Deferred

- Production cloud sync rollout; the 1.0 app remains offline-first with server foundations only.
- Receipt image/OCR.
- Supabase/Firebase sync.
- iOS signed archive verification until macOS/Xcode/Swift release packaging.
