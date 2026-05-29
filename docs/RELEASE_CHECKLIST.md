# Release Checklist

## Pre-release

- [ ] `flutter pub get`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `flutter build apk --debug`
- [ ] Verify `.gitignore` excludes `.claude/`, `.omc/`, `plans/`, `CLAUDE.md`, `.env*`.
- [ ] Verify no secrets in `git diff`.

## Android

Debug build:

```bash
flutter build apk --debug
```

Release build:

```bash
flutter build apk --release
flutter build appbundle --release
```

Release signing requires a local keystore or CI secret setup. Do not commit keystores, passwords, or signing configs with credentials.

## iOS

Requires macOS with Xcode:

```bash
flutter pub get
flutter build ios --release
```

Archive and upload through Xcode Organizer or Fastlane.

## Known Issues

- Supabase/Firebase sync deferred.
- Receipt image/OCR deferred.
- Dark/light mode setting persistence still needs a polish pass.
- Receipt image/OCR deferred.
- iOS archive must be verified on macOS/Xcode.

## Next Roadmap

1. Add dark/light mode persistence and stronger settings reset confirmation.
2. Split long widget tests into focused files and helper fixtures.
3. Add more report filters, line/yearly charts, and dedicated bill schedule rules.
4. Add cloud sync with encrypted user opt-in.
