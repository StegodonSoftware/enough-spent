# Enough Spent — Release Checklist

## Pre-Build

- [ ] Bump `version` in `pubspec.yaml` (name + versionCode, e.g. `1.1.0+2`)
- [ ] Remove any leftover debug code / print statements
- [ ] Test on a real device with `flutter run --release`
- [ ] Verify core flows: expense entry, currency conversion, offline mode, ads loading

## Build

- [ ] Run `flutter build appbundle --release`
- [ ] Verify signed: `jarsigner -verify build/app/outputs/bundle/release/app-release.aab`

## Upload

- [ ] Play Console → correct track → Create new release
- [ ] Upload AAB
- [ ] Write release notes
- [ ] Update store listing if UI or features changed (screenshots, description)
- [ ] Update data safety section if new data collected or new SDKs added
- [ ] Submit for review

## Post-Release

- [ ] Install from Play Store and smoke test
- [ ] Check Android Vitals for new crashes
- [ ] Respond to any new reviews