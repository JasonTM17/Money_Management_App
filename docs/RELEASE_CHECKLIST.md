# Release Checklist

## Pre-release

- [ ] `flutter pub get`
- [ ] `flutter analyze --no-pub`
- [ ] `flutter test --no-pub -r expanded`
- [ ] `flutter test --no-pub scripts/capture_demo_media_test.dart -r expanded` if README media changed
- [ ] `flutter build apk --release --no-pub`
- [ ] `flutter build appbundle --release --no-pub`
- [ ] Verify `.gitignore` excludes private agent/workflow files, internal planning notes, `.env*`, keystores, and local database files.
- [ ] Verify no secrets or private paths in `git diff`.
- [ ] Verify no private agent/workflow files or internal planning notes are tracked by git.
- [ ] Verify README screenshots/GIF use seeded fake data only.
- [ ] Verify Vietnamese, English, and Japanese language switching in Settings and Reports export copy.
- [ ] Verify PrivacyGate and Settings privacy status render as polished release UI, including biometric opt-in, not placeholder controls.
- [ ] Create/unlock PIN, toggle biometric opt-in, background the app, resume, and verify the privacy gate relocks with PIN fallback.
- [ ] Enter an incorrect PIN repeatedly and verify cooldown copy appears instead of raw errors.
- [ ] Verify reset data requires confirmation plus PIN re-authentication before deleting local data.
- [ ] Verify backup restore shows preview and requires PIN re-authentication before replacing local data.
- [ ] `npm --prefix api ci`
- [ ] `npm --prefix api run prisma:generate`
- [ ] `npm --prefix api run typecheck`
- [ ] `npm --prefix api test`
- [ ] `npm --prefix api run build`
- [ ] Verify `docs/openapi.yaml` includes finance PATCH/DELETE, sync changes/push, household/shared-budget, entitlement, IAP, and SePay routes.
- [ ] Verify Store IAP is used for App Store/Play Store builds and SePay UI is disabled in store builds.
- [ ] Verify direct APK/web builds set `SEPAY_ENABLED=true` only with deployment secrets outside the repo.
- [ ] Verify `SEPAY_WEBHOOK_SECRET`, Docker Hub secrets, Android signing secrets, and iOS signing secrets are present only in CI/deployment secret stores.
- [ ] `docker compose config --quiet`
- [ ] `docker compose up --build -d postgres`
- [ ] `docker compose --profile tools run --rm --build migrate`
- [ ] `docker compose --profile tools run --rm --build seed`
- [ ] `docker compose up --build -d api frontend`
- [ ] Verify `/healthz`, `/readyz`, and `/.well-known/jwks.json` from the API host port.
- [ ] Verify the frontend artifact server serves `cashflow-manager.apk` from the frontend host port.
- [ ] Verify `.github/workflows/ci.yml` covers Flutter, API, PostgreSQL migration/seed, Docker Compose config, and image builds.
- [ ] Verify `.github/workflows/release.yml` uploads Android APK/AAB artifacts from tag or manual runs.
- [ ] Verify `.github/workflows/docker-publish.yml` grants `packages: write`, always publishes GHCR with `GITHUB_TOKEN`, and publishes Docker Hub only when `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN` are configured.
- [ ] Run `gh repo view JasonTM17/Money_Management_App --json description,homepageUrl,repositoryTopics,isPrivate,url` and verify the repo is public at `https://github.com/JasonTM17/Money_Management_App`.
- [ ] Verify GitHub About description is exactly `Offline-first Flutter personal finance manager with privacy lock, SQLite, Docker/PostgreSQL API, OpenAPI, and n8n HMAC automation.`.
- [ ] Verify GitHub homepage is `https://github.com/JasonTM17/Money_Management_App#readme` until a real public release/download page exists.
- [ ] Verify GitHub topics are exactly `dart`, `docker`, `fastify`, `flutter`, `n8n`, `openapi`, `personal-finance`, `postgresql`, `prisma`, `riverpod`, `sqlite`.
- [ ] Run `gh release list --repo JasonTM17/Money_Management_App --limit 10`; no GitHub Releases are published yet, so docs must not claim downloadable release artifacts are live before the first signed release.
- [ ] Publish GitHub Release `CashFlow Manager 1.0.0+1` from tag `v1.0.0` only after release gates pass; attach APK/AAB artifacts and release notes. Add SBOM/checksums when the security scanning lane is finalized.
- [ ] Verify Packages/containers only after Docker publish succeeds: GHCR images `ghcr.io/jasontm17/cashflow-manager-api`, `ghcr.io/jasontm17/cashflow-manager-frontend` must have `latest`, git SHA, and semver tags on release builds. Docker Hub images `nguyenson1710/cashflow-manager-api` and `nguyenson1710/cashflow-manager-frontend` should mirror the same tags when Docker Hub secrets are configured. Before publish, document packages as unpublished/not visible.
- [ ] Verify GHCR package visibility after Docker publish in GitHub Packages UI or with `gh api /users/JasonTM17/packages?package_type=container` when auth permits.
- [ ] Launch the app locally on an Android device or emulator after release gates pass so the user can manually test the main flows.
- [ ] Commit README/docs updates together with referenced public artifacts such as `api/`, `docs/openapi.yaml`, `docs/media/`, `infra/`, Docker files, and workflow files.
- [ ] Import and activate the n8n workflow only with local placeholder/demo secrets or deployment secrets.
- [ ] Run `node scripts/mock-openai-compatible-provider.mjs` and `./scripts/smoke-test-n8n-ai.ps1` against n8n before any real AI-provider token test.
- [ ] Verify n8n webhook HMAC rejection produces zero mock-provider calls, then valid HMAC produces exactly one mock-provider call without printing provider tokens.
- [ ] Confirm the mock-provider smoke passes before any real AI-provider token test.
- [ ] Verify provider-bound data minimization: the n8n AI-provider user message contains only `{ question, locale }`.
- [ ] Verify ChatbotAI responses stay conservative and educational, do not claim bank/account/transaction/wallet/file/external-service access, and return strict JSON `{ answer, suggestions }` with 3-5 non-empty suggestions.

## Android

Debug build:

```bash
flutter build apk --debug
flutter build appbundle --debug
```

Release build:

```bash
flutter build apk --release
flutter build appbundle --release
```

Release signing requires a local keystore or CI secret setup. Do not commit keystores, passwords, or signing configs with credentials.

Suggested artifact names:

- `cashflow-manager-v1.0.0-android.apk`
- `cashflow-manager-v1.0.0-android.aab`

## iOS

Requires macOS with Xcode and Swift installed:

```bash
flutter pub get
flutter build ios --release
```

Archive and upload through Xcode Organizer or Fastlane. Windows can verify source structure but cannot complete the signed iOS archive.

## Docker Images

Target public image names:

- Docker Hub: `nguyenson1710/cashflow-manager-api`
- Docker Hub: `nguyenson1710/cashflow-manager-frontend`
- GHCR: `ghcr.io/jasontm17/cashflow-manager-api`
- GHCR: `ghcr.io/jasontm17/cashflow-manager-frontend`

Publish `latest`, git SHA, and semver tags only after CI/release gates and secret scanning are in place. Until the first successful publish, packages are intentionally unpublished/not visible.

## Known Issues

- No production cloud sync yet; local-first use remains complete while account/sync server pieces stay in a separate rollout lane.
- Supabase/Firebase sync intentionally out of MVP scope.
- Receipt image/OCR remains local-first work for the next product phase.
- iOS archive must be verified on macOS/Xcode with Swift installed.
- `file_picker` and `share_plus` still emit Flutter's future Kotlin Gradle Plugin migration warning during Android release build.

## Next Roadmap

1. Verify first strict release security gates and Docker image publish workflow run: Trivy, gitleaks, SBOM, and Docker Hub image publish.
2. Wire mobile account screens, secure token storage, sync queue replay, conflict review, household entry, premium state, and OCR correction UX.
3. Verify iOS archive on macOS/Xcode.
4. Track plugin updates for Flutter built-in Kotlin migration.
