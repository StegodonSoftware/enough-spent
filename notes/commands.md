### Build AAB for upload
`flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info --dart-define=CURRENCY_API_KEY=[key] --dart-define=CURRENCY_WORKER_URL=https://currency-rates-worker.stegodonsoftware.workers.dev/latest`

### Build APK for testing
`flutter build apk --debug`

### Check AAP is signed
`jarsigner -verify build/app/outputs/bundle/release/app-release.aab`

### Create keystore for signing
`keytool -genkey -v -keystore enough-spent-play-store.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`

### Create launcher icons from pubspec.yaml
`dart run flutter_launcher_icons`

### Create splash screen from pubspec.yaml
`dart run flutter_native_splash:create`

### Remove previously built assets
`flutter clean`

### Update app based on pubspec.yaml
`flutter pub get`

### ffmpeg transcription
`ffmpeg -i clip1.webm -c:v libx264 -crf 18 -preset slow -c:a aac clip1.mp4`

### Run re-fetch of rates for worker
`curl.exe -X POST https://currency-rates-worker.stegodonsoftware.workers.dev/refresh -H "X-Admin-Key: [your-admin-key]"`
