# Contributing

CashFlow Manager is maintained as a portfolio-grade offline-first finance app. Contributions should keep the app secure, local-first, and easy to verify.

## Development Setup

```bash
flutter pub get
flutter analyze
flutter test --no-pub -r expanded
flutter build apk --release --no-pub
flutter build appbundle --release --no-pub
```

Backend checks:

```bash
npm --prefix api install
npm --prefix api run prisma:generate
npm --prefix api run typecheck
npm --prefix api test
```

Docker checks:

```bash
docker compose config --quiet
docker compose up --build -d postgres
docker compose --profile tools run --rm --build migrate
docker compose --profile tools run --rm --build seed
docker compose up --build -d api frontend
```

## Pull Request Expectations

- Keep changes focused and small enough to review.
- Update tests for behavior changes.
- Update `README.md`, `docs/`, and `docs/openapi.yaml` when public behavior or API contracts change.
- Use seeded fake data for screenshots and demos.
- Do not commit `.env*`, keystores, local databases, `.claude/`, `.omc/`, `plans/`, private notes, or real financial data.
- Run `git diff --check` before submitting.

## Commit Style

Use Conventional Commits:

```text
feat(scope): short imperative summary
fix(scope): short imperative summary
test(scope): short imperative summary
ci(scope): short imperative summary
```

Do not include generated-tool or AI co-author trailers in commit messages.

## iOS Packaging

iOS release verification requires macOS with Xcode and Swift installed. Windows can validate source and Android packaging but cannot complete the signed iOS archive.
