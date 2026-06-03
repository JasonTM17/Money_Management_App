# Code Standards / Tiêu chuẩn code / コード規約

Extracted from project `CLAUDE.md`, `.claude/rules/`, and established patterns. These standards apply to all contributions.

## General Principles

**YAGNI** — You Aren't Gonna Need It. Don't build for hypothetical futures.
**KISS** — Keep It Simple, Stupid. Prefer clarity over cleverness.
**DRY** — Don't Repeat Yourself. Three similar lines → extract.

## File Conventions

| Rule | Detail |
|------|--------|
| **Naming** | kebab-case with descriptive names (`local_store_budget_operations.dart`). Long names are fine — self-documenting for LLM tools |
| **Size** | Files ≤ 200 lines. Split by logical boundary when exceeded |
| **Organization** | One concern per file. Check for existing modules before creating new ones |
| **Comments** | Explain WHY, not WHAT. No docstrings >1 line. No plan/phase references in code |

## Flutter/Dart

### Architecture
```
lib/
├── app/          # App shell, theme, localization, shared widgets
├── core/         # Pure Dart: models, services, calculators — no Flutter imports
├── data/         # Persistence: SQLite store (modularized by domain)
└── features/     # Screens: thin UI delegates to core/data
```

### State Management
- **Riverpod** for all state: `AsyncNotifierProvider` for async loads, `StateProvider` for simple state
- Providers named with `Provider` suffix: `financeControllerProvider`
- UI renders three states: loading → data → error (no silent failures)

### Testing
- `test/` for unit and widget tests; `integration_test/` for full-flow
- Widget tests use `pumpWidget` with real Riverpod overrides
- Test files mirror source structure: `lib/core/foo.dart` → `test/foo_test.dart`
- No mocks for SQLite — use in-memory database

### Money Math
- ALL financial amounts use integers (`int` representing VND)
- `Money` class wraps arithmetic: no raw `int` in UI
- Never use `double` for money

## TypeScript (API)

### Project Structure
```
api/src/
├── main.ts        # Entry point
├── app.ts         # App factory: buildApp(opts) → FastifyInstance
├── lib/           # Shared: Prisma client, env config, utilities
└── modules/       # Domain modules (auth, finance, sync, ai, health, well-known)
    └── <name>/
        ├── <name>-routes.ts      # Fastify route registration
        ├── <name>-routes.test.ts # Vitest tests
        └── <name>-service.ts     # Business logic (if complex)
```

### Conventions
- **Zod** for all input validation: `Schema.safeParse(body)` before touching DB
- **Prisma** for database access: no raw SQL unless performance-critical
- `buildApp(opts)` pattern: accept overrides (e.g., databaseUrl) for testing
- Test with real PostgreSQL via `vitest` + Docker service container
- No `.skip` on tests; no fake data to pass build

### Type Safety
- `strict: true` in tsconfig
- No `any` types (use `unknown` and narrow)
- Prisma-generated types are source of truth for DB models
- Zod schemas are source of truth for input validation

## Commit Standards

### Format: Conventional Commits
```
<type>(<scope>): <subject>

<body — explain WHY, not WHAT>
```

| Type | Use |
|------|-----|
| `feat` | New feature |
| `fix` | Bug fix |
| `test` | Test addition or fix |
| `refactor` | Code restructure (no behavior change) |
| `perf` | Performance improvement |
| `build` | Build system, dependencies |
| `ci` | CI/CD configuration |
| `docs` | Documentation (not `.claude/` changes) |
| `style` | Formatting, whitespace |

### Rules
- Subject ≤ 72 chars, imperative mood, no trailing period
- Body at 100 cols max, explains WHY
- NO `Co-Authored-By: Claude` or AI reference in any commit
- Stage explicit files; never `git add .` blindly
- No `.env*`, secrets, or private files in commits

## Security Standards

### Input Validation
- All user input validated at boundary (Zod schema, form validation)
- CSV export escapes formula-leading characters (`=`, `@`, `+`, `-`)
- Backup files validated before restore: size ≤ 5 MB, shape check

### Authentication
- Ed25519 JWT for production; HMAC HS256 for dev only
- JWKS published at `/.well-known/jwks.json`
- Refresh tokens: rotating, opaque random 32 bytes, hash-stored
- PIN: salted PBKDF2-HMAC-SHA256 (never plaintext or SHA-256)
- Rate limiting: per-route in-memory with account lockout pairing

### Data Protection
- Backup encryption: passphrase-derived AES-GCM (schema v2)
- No secrets or financial data in logs
- HMAC sign all outbound third-party webhooks (n8n, SePay)
- Timing-safe comparison for all HMAC verification

### CI Security Gates
| Gate | Tool | Severity |
|------|------|----------|
| Secret scan | Gitleaks | block on any finding |
| Container scan | Trivy | block CRITICAL+HIGH |
| SAST | CodeQL | block on alerts |
| Dependency audit | npm audit | advisory only |
| SBOM | Syft | generate per build |

## Documentation Standards

- Per-service README with 6 sections: Purpose, API Surface, Env Vars, Run Locally, Test, Runbook
- ADRs under `docs/adr/` — one decision per file, append-only
- OpenAPI 3.1 contract is canonical; no hand-written fetch wrappers
- Diagrams use Mermaid.js v11; export to SVG/PNG for external use
- No stale plan references in code comments or file names

## Pre-Commit Checklist

- [ ] `flutter analyze --no-pub` passes
- [ ] `flutter test --no-pub -r expanded` passes
- [ ] `cd api && npm run typecheck` passes
- [ ] `cd api && npm test` passes
- [ ] No `.env`, secrets, or private files staged
- [ ] Commit message has no AI references
- [ ] Proper conventional commit format
- [ ] Files follow kebab-case naming

## Pre-Push Checklist

- [ ] All pre-commit checks pass
- [ ] Integration smoke test passes (Android emulator or device)
- [ ] Git diff reviewed — no accidental file inclusions
- [ ] Docs updated if API contract, env vars, or behavior changed
