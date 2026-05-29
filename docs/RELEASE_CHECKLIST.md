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
- Edit/delete transaction screens need next iteration.
- Full PDF sharing UI is roadmap; export service foundation exists.

## Next Roadmap

1. Split large home UI into feature widgets.
2. Add transaction edit/delete.
3. Add import/backup flow.
4. Add PDF generation UI.
5. Add cloud sync with encrypted user opt-in.
