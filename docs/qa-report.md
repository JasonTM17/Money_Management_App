# iOS and Android QA Report

Date: 2026-07-04

Scope: release QA hardening for CashFlow Manager mobile UI/UX, privacy, and core finance business flows. Public screenshots and automated media use seeded fake data only. No real financial data, signing assets, local paths, secrets, or tokens are included in this report.

This report was refreshed after the July 2026 professional mobile UI pass:
shared home widgets were modularized, dashboard hero hierarchy was tightened,
transaction filtering gained a compact result-count/reset treatment, wallets
gained a portfolio summary, and repository ignore rules were expanded for
signing/build artifacts.

## Environment

| Platform | Device or runner | Status |
|---|---|---|
| Android emulator | `sdk gphone64 x86 64`, `emulator-5554`, Android 16 API 36 | Verified locally |
| Android real device | Not connected on this Windows machine | Release blocker until smoke and manual QA pass |
| iOS simulator | Requires macOS/Xcode runner | Release blocker until macOS smoke passes |
| iPhone real device | Requires physical iPhone with Face ID or Touch ID | Release blocker until device QA passes |

## Verified Automated Gates

| Gate | Result | Evidence |
|---|---|---|
| Flutter analyze | Pass | `flutter analyze --no-pub` |
| Unit/widget tests | Pass | `flutter test --no-pub -r expanded` (83 tests) |
| Demo media capture | Pass | `flutter test --no-pub scripts/capture_demo_media_test.dart -r expanded` |
| Android emulator smoke | Pass | `flutter test --no-pub integration_test/cashflow_smoke_test.dart -d emulator-5554 -r expanded --timeout 180s` |
| Android debug APK | Pass | `flutter build apk --debug --no-pub` |
| Android release APK | Pass | `flutter build apk --release --no-pub` |
| Android release AAB | Pass | `flutter build appbundle --release --no-pub` |
| Workflow YAML parse | Pass | `.github/workflows/ci.yml` and `.github/workflows/release.yml` parsed with PyYAML |
| Whitespace diff check | Pass | `git diff --check` |

## Automated Smoke Flow Coverage

`integration_test/cashflow_smoke_test.dart` is deterministic and uses fake finance/privacy stores. It currently covers:

- First-run PIN setup and privacy gate entry.
- Lifecycle relock path after app background/inactive state.
- Biometric opt-in UI path with PIN fallback still available.
- Five-tab navigation: Dashboard, Transactions, Wallets, Budgets, Reports.
- Invalid zero amount rejection, then valid expense creation.
- Transaction list reachability and search field presence.
- Wallet transfer between wallets.
- Saving goal creation.
- Budget warning visibility.
- Reports export preview entry with CSV text and PDF action visible.
- Backup/restore entry and reset-data confirmation entry.

## UI/UX Evidence

Public media was regenerated from deterministic fake data and reviewed through the passing media test:

- `docs/media/hero-dashboard.png`
- `docs/media/screenshot-dashboard.png`
- `docs/media/screenshot-transactions.png`
- `docs/media/screenshot-wallets.png`
- `docs/media/screenshot-wallets-budgets.png`
- `docs/media/screenshot-reports.png`
- `docs/media/screenshot-privacy-settings.png`

Current automated UI criteria covered locally: phone-sized surface, primary navigation reachability, settings/report sheet entry, and no framework exception during smoke. Manual pass is still required for compact/standard/large phone sizes, light/dark, Vietnamese/English/Japanese, large text scale, safe area/notch, keyboard covering, native file picker, share sheet, and biometric prompt behavior.

## Business Flow Status

| Flow | Automated status | Manual release status |
|---|---|---|
| PIN setup/unlock | Pass | Android real device and iPhone pending |
| Lifecycle relock | Pass in smoke | Native background/resume pending on real devices |
| Biometric opt-in and PIN fallback | UI path pass | Native Face ID/Touch ID and Android biometric prompt pending |
| Dashboard totals and finance shell | Pass through widget/smoke coverage | Real-device visual check pending |
| Transaction add invalid/valid | Pass | Real-device keyboard/sheet check pending |
| Wallet transfer | Pass | Real-device manual check pending |
| Budget warning at threshold | Pass | Real-device visual check pending |
| Saving goal create | Pass | Real-device manual check pending |
| Reports CSV/PDF preview entry | Pass | Native PDF/share sheet pending |
| Backup/restore entry | Pass | Native file picker/restore preview pending |
| Reset confirmation | Pass | Re-auth destructive-flow manual check pending |
| Offline local finance | Covered by local tests | Airplane/offline manual check pending |

## Release Blockers

- Android real-device smoke and manual QA are not complete because no Android phone is connected.
- iOS simulator smoke and `flutter build ios --release --no-codesign --no-pub` are not complete because this machine is Windows, not macOS with Xcode.
- Real iPhone smoke/manual QA is not complete because no iPhone is available in this environment.
- Signed iOS archive/IPA remains blocked until valid Apple signing certificate, provisioning profile, keychain password, and export options are available in Xcode/Fastlane or CI secrets.
- Android builds emit Flutter's future Kotlin Gradle Plugin migration warning for `file_picker` and `share_plus`; builds pass today, but plugin upgrades must be tracked.

## Next Required Platform Gates

```bash
flutter test --no-pub integration_test/cashflow_smoke_test.dart -d <android-device-id> -r expanded
flutter test --no-pub integration_test/cashflow_smoke_test.dart -d <ios-simulator-id> -r expanded
flutter test --no-pub integration_test/cashflow_smoke_test.dart -d <ios-device-id> -r expanded
flutter build ios --release --no-codesign --no-pub
```

Run signed archive/IPA only on macOS with valid Apple signing assets. Missing signing assets must stay an explicit release blocker.
