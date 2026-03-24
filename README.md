# Enough Spent.

A Flutter-based personal expense tracker for Android. Quickly log daily expenses with categories, locations, and multi-currency support.

## Building

The Cloudflare Worker API key is injected at build time via `--dart-define` — it is never bundled in the APK.

**Debug:**
```bash
flutter run --dart-define=CURRENCY_API_KEY=your_key_here
```

**Release APK:**
```bash
flutter build apk --dart-define=CURRENCY_API_KEY=your_key_here
```

**Release App Bundle (Play Store):**
```bash
flutter build appbundle --dart-define=CURRENCY_API_KEY=your_key_here
```

> Store the key in your CI/CD secrets (e.g. GitHub Actions `secrets.CURRENCY_API_KEY`) and pass it via `--dart-define`. Without the key the app falls back to cached or bundled exchange rates — all other features work normally.

## Tech Stack

- **Flutter** / Dart 3.10.4+
- **Hive** — local storage
- **Provider** — state management
- **Google Mobile Ads** — banner & interstitial ads
- **Cloudflare Workers** — currency rate endpoint
