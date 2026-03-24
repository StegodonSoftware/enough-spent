# Currency Rates Configuration

This guide explains how to securely configure the Cloudflare Worker API key for currency rate fetching.

## Security Rules

⚠️ **NEVER:**
- Commit `.env` files to git
- Hardcode API keys in source code
- Share your API key with others (including AI)
- Post screenshots showing your API key

✅ **DO:**
- Keep API key in local environment only
- Rotate key if accidentally exposed
- Use strong, unique keys
- Regenerate periodically

## Setup Options

### Option 1: Build-Time Environment Variable (Recommended)

Pass the API key at build/run time. The key never touches the codebase.

**For Development (Local Run):**
```bash
flutter run --dart-define='CURRENCY_API_KEY=your_actual_key_here'
```

**For Release Build:**
```bash
flutter build apk --dart-define='CURRENCY_API_KEY=your_actual_key_here'
```

**For iOS:**
```bash
flutter run -d <device> --dart-define='CURRENCY_API_KEY=your_actual_key_here'
```

### Option 2: Local `.env` File (Development Only)

Create a local `.env` file that's automatically ignored by git:

**1. Create `.env` in project root:**
```
CURRENCY_API_KEY=your_actual_key_here
CURRENCY_WORKER_URL=https://your-worker.workers.dev/latest
```

**2. Verify it's in `.gitignore`:**
```bash
git check-ignore .env
```
Should output: `.env`

**3. Load at build time:**
You'll need to add a pre-build script or use a package like `flutter_dotenv` to load it.

### Option 3: CI/CD Environment Variables

For automated builds (GitHub Actions, etc.), set secrets in your CI platform:

**GitHub Actions Example:**
```yaml
env:
  CURRENCY_API_KEY: ${{ secrets.CURRENCY_API_KEY }}

script:
  - flutter build apk --dart-define='CURRENCY_API_KEY=${{ env.CURRENCY_API_KEY }}'
```

Then manage the actual key in **Settings > Secrets > Actions** (never in your code).

## Verifying Configuration

### Check if key is loaded:
Look for this log message when you run the app:
```
✅ CurrencyRateProvider: Fetched fresh rates from remote
```

Or this if key is missing:
```
⚠️ CurrencyRateProvider: CURRENCY_API_KEY not configured, skipping remote fetch
```

### In Production:
- App will automatically fall back to cached/bundled rates if key is missing
- No crashes or data loss, just uses offline rates

## Code Changes Made

- `CURRENCY_API_KEY` is now read from environment via `String.fromEnvironment()`
- No hardcoded secrets in source code
- Graceful fallback if key not configured
- 401 responses are logged (invalid key detected)

## If You Exposed Your Key

1. Go to Cloudflare Dashboard
2. Regenerate or delete the exposed API key
3. Never use that key again
4. No need to update code - just provide the new key at build time

## Questions?

- Key is missing but app works? ✅ Normal - using bundled/cached rates
- Getting 401 errors? ❌ Key is invalid - regenerate in Cloudflare
- Want to change endpoint? Use `--dart-define='CURRENCY_WORKER_URL=...'`
