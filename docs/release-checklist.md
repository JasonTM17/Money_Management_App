# Release Checklist

## Pre-release

- [ ] `flutter pub get`
- [ ] `flutter analyze --no-pub`
- [ ] `flutter test --no-pub -r expanded`
- [ ] `flutter test --no-pub scripts/capture_demo_media_test.dart -r expanded` if README media changed
- [ ] `flutter build apk --release --no-pub`
- [ ] `flutter build appbundle --release --no-pub`
- [ ] Run `flutter test --no-pub integration_test/cashflow_smoke_test.dart -d <android-emulator-id> -r expanded` on `Medium_Phone_API_36.1` or equivalent.
- [ ] Run `flutter test --no-pub integration_test/cashflow_smoke_test.dart -d <android-device-id> -r expanded` on a real Android device before release.
- [ ] On macOS, run `flutter test --no-pub integration_test/cashflow_smoke_test.dart -d <ios-simulator-id> -r expanded`.
- [ ] On macOS, run `flutter test --no-pub integration_test/cashflow_smoke_test.dart -d <ios-device-id> -r expanded` on a real iPhone before App Store/TestFlight handoff.
- [ ] On macOS, run `flutter build ios --release --no-codesign --no-pub`.
- [ ] Produce signed iOS archive/IPA only when Apple signing assets are present; otherwise record this as a release blocker.
- [ ] Verify `.gitignore` excludes private agent/workflow files, internal planning notes, `.env*`, keystores, and local database files.
- [ ] Verify no secrets or private paths in `git diff`.
- [ ] Verify no private agent/workflow files or internal planning notes are tracked by git.
- [ ] Run or verify `.github/workflows/security.yml`: npm audit, Flutter dependency review, redacted Gitleaks scan, Trivy filesystem scan, container image scans, and SBOM artifact generation.
- [ ] Verify release workflow attaches `checksums.sha256` and `sbom.spdx.json` with APK/AAB artifacts.
- [ ] Verify encrypted backup v2 roundtrip, wrong passphrase, tamper rejection, and legacy plaintext JSON restore compatibility.
- [ ] Verify release account/sync stays disabled unless `CASHFLOW_SYNC_ENABLED=true` and `CASHFLOW_API_BASE_URL` is HTTPS.
- [ ] Verify README screenshots/GIF use seeded fake data only.
- [ ] Verify Vietnamese, English, and Japanese language switching in Settings and Reports export copy.
- [ ] Verify PrivacyGate and Settings privacy status render as polished release UI, including biometric opt-in, not placeholder controls.
- [ ] Create/unlock PIN, toggle biometric opt-in, background the app, resume, and verify the privacy gate relocks with PIN fallback.
- [ ] Enter an incorrect PIN repeatedly and verify cooldown copy appears instead of raw errors.
- [ ] Verify reset data requires confirmation plus PIN re-authentication before deleting local data.
- [ ] Verify backup restore UI previews data before replacement and requires PIN re-authentication before replacing local data.
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
- [ ] Verify `.github/workflows/ci.yml` and `.github/workflows/release.yml` cover Android emulator smoke plus iOS simulator smoke/no-codesign build before tagged release artifacts are attached.
- [ ] Verify `.github/workflows/release.yml` uploads Android APK/AAB artifacts from tag or manual runs and supports manual signed iOS IPA builds with fail-fast secret validation.
- [ ] Verify `.github/workflows/docker-publish.yml` grants `packages: write`, always publishes GHCR with `GITHUB_TOKEN`, and publishes Docker Hub only when `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN` are configured.
- [ ] Verify GitHub Actions quota/token is available before rerunning CI/CD workflows; if exhausted, mark remote CI as deferred and rely on local gates until capacity is restored.
- [ ] Run `gh repo view JasonTM17/Money_Management_App --json description,homepageUrl,repositoryTopics,visibility,url` and verify repo visibility is intentional. Current target is public with homepage empty until a dedicated release/download page exists.
- [ ] Verify GitHub About description is exactly `Professional offline-first Flutter personal finance app with PIN/biometrics, SQLite, Riverpod 3, Node 26 Fastify/PostgreSQL API, OpenAPI, Docker Hub/GHCR packages, and n8n HMAC automation.`.
- [ ] Verify GitHub homepage is empty until a real public release/download page exists.
- [ ] Verify GitHub topics are exactly `android`, `android-app`, `dart`, `docker`, `fastify`, `finance-app`, `flutter`, `flutter-app`, `mobile-app`, `n8n`, `offline-finance`, `offline-first`, `openapi`, `personal-finance`, `postgresql`, `prisma`, `riverpod`, `security`, `sqlite`, `vietnamese`.
- [ ] Run `gh release view v1.0.0 --repo JasonTM17/Money_Management_App --json tagName,name,isDraft,isPrerelease,publishedAt,url,assets` and verify published release `CashFlow Manager 1.0.0+1` includes APK `cashflow-manager-v1.0.0-android.apk` and App Bundle `cashflow-manager-v1.0.0-android.aab`.
- [ ] Verify release workflow uploads SBOM and SHA256 checksum artifacts and attaches them to tagged GitHub Releases.
- [ ] Verify GHCR package visibility after Docker publish with `docker manifest inspect ghcr.io/jasontm17/cashflow-manager-api:1.0.0` and `docker manifest inspect ghcr.io/jasontm17/cashflow-manager-frontend:1.0.0`; both public manifests must resolve.
- [ ] Verify Docker Hub images `nguyenson1710/cashflow-manager-api:latest` and `nguyenson1710/cashflow-manager-frontend:latest` with `docker manifest inspect`.
- [ ] Launch the app locally on an Android device or emulator after release gates pass so the user can manually test the main flows.
- [ ] Launch the app locally on an iPhone or iOS simulator after release gates pass so the user can manually test the main flows.
- [ ] Commit README/docs updates together with referenced public artifacts such as `api/`, `docs/openapi.yaml`, `docs/media/`, `infra/`, Docker files, and workflow files.
- [ ] Import and activate the n8n workflow only with local placeholder/demo secrets or deployment secrets.
- [ ] Verify n8n is private/internal in production behind TLS and a reverse proxy or private network boundary; do not expose the editor publicly.
- [ ] Run `node scripts/mock-openai-compatible-provider.mjs` and `./scripts/smoke-test-n8n-ai.ps1` against n8n before any real AI-provider token test.
- [ ] Verify n8n webhook HMAC rejection produces zero mock-provider calls, then valid HMAC produces exactly one mock-provider call without printing provider tokens.
- [ ] Confirm the mock-provider smoke passes before any real AI-provider token test.
- [ ] Verify provider-bound data minimization: the n8n AI-provider user message contains only `{ question, locale }`.
- [ ] Verify ChatbotAI responses stay conservative and educational, do not claim bank/account/transaction/wallet/file/external-service access, and return strict JSON `{ answer, suggestions }` with 3-5 non-empty suggestions.

## Android

Preflight:

```bash
flutter doctor --android-licenses
flutter emulators --launch Medium_Phone_API_36.1
flutter devices
```

On Windows, use the Android Studio bundled JBR/JDK 21 for local Gradle builds when `JAVA_HOME` points to a newer JDK. For PowerShell sessions:

```powershell
$env:JAVA_HOME = 'D:\Android Studio\jbr'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
```

Debug build:

```bash
flutter build apk --debug
flutter build appbundle --debug
flutter test --no-pub integration_test/cashflow_smoke_test.dart -d <android-emulator-id> -r expanded
flutter test --no-pub integration_test/cashflow_smoke_test.dart -d <android-device-id> -r expanded
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

Manual Android QA must cover gesture navigation, soft keyboard behavior in sheets, file picker, share sheet, PDF/CSV export entry, lifecycle relock, biometric opt-in with PIN fallback, backup restore preview, and reset re-auth.

## iOS

Requires macOS with Xcode and Swift installed:

```bash
flutter pub get
flutter doctor -v
flutter analyze --no-pub
flutter test --no-pub -r expanded
flutter test --no-pub integration_test/cashflow_smoke_test.dart -d <ios-simulator-id> -r expanded
flutter test --no-pub integration_test/cashflow_smoke_test.dart -d <ios-device-id> -r expanded
flutter build ios --release --no-codesign --no-pub
```

Archive and upload through Xcode Organizer, Fastlane, or the manual signed CI lane. The signed CI lane requires these secrets: `IOS_CERTIFICATE_BASE64`, `IOS_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64`, `IOS_KEYCHAIN_PASSWORD`, and `IOS_EXPORT_OPTIONS_PLIST_BASE64`. Windows can verify source structure but cannot complete the signed iOS archive.

Manual iOS QA must cover compact/standard/large iPhone safe areas, Face ID/Touch ID opt-in, PIN fallback, secure storage persistence, lifecycle relock, keyboard behavior in sheets, file/share sheets, PDF preview/share, backup restore preview, and reset re-auth.

## Docker Images

Target public image names:

- Docker Hub: `nguyenson1710/cashflow-manager-api`
- Docker Hub: `nguyenson1710/cashflow-manager-frontend`
- GHCR: `ghcr.io/jasontm17/cashflow-manager-api`
- GHCR: `ghcr.io/jasontm17/cashflow-manager-frontend`

The verified Docker Publish workflow run published public GHCR manifests for `ghcr.io/jasontm17/cashflow-manager-api:1.0.0` and `ghcr.io/jasontm17/cashflow-manager-frontend:1.0.0`. Release builds also tag images with `v1.0.0`, git SHA, and `latest`. Docker Hub `latest` manifests are available for `nguyenson1710/cashflow-manager-api` and `nguyenson1710/cashflow-manager-frontend`.

## Known Issues

- No production cloud sync yet; local-first use remains complete while account/sync server pieces stay in a separate rollout lane.
- Supabase/Firebase sync intentionally out of MVP scope.
- Receipt image/OCR remains local-first work for the next product phase.
- iOS archive must be verified on macOS/Xcode with Swift installed.
- GitHub Actions remote CI/CD must be rerun after quota/token capacity is restored.
- `file_picker` and `share_plus` still emit Flutter's future Kotlin Gradle Plugin migration warning during Android release build.

## Next Roadmap

1. Verify first strict release security gates and Docker image publish workflow run: Trivy, gitleaks, SBOM, and Docker Hub image publish.
2. Wire mobile account screens, secure token storage, sync queue replay, conflict review, household entry, premium state, and OCR correction UX.
3. Verify iOS archive on macOS/Xcode.
4. Track plugin updates for Flutter built-in Kotlin migration.
