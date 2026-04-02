# Reference App Downloads

This folder is for installable reference builds that teammates can use to quickly understand the original apps and the current OpenBene-derived experience.

## Included Android APKs

### 1. Original OpenBot app

- local file: `downloads/android/openbot-original/OpenBot-0.8.0.apk`
- size: 41,149,683 bytes
- SHA-256: `E313F14FF3462EF3763AC9002D4E261299C66C1662041E0172AA0839B55474B0`
- purpose: baseline reference for the original OpenBot Android app experience

### 2. OpenBene app build

- local file: `downloads/android/openbene/openbene-mobile-control-v1.0.6-with-discovery.apk`
- size: 22,088,663 bytes
- SHA-256: `749FCC25D32057997F6E77AA89A4451528405D8C4E9C7F5B758EEF23C3FB9829`
- purpose: shareable OpenBene-based build for teammates to install and compare

## Official OpenBot Links

- OpenBot repository: <https://github.com/intel-isl/OpenBot>
- OpenBot releases: <https://github.com/intel-isl/OpenBot/releases>
- OpenBot `v0.8.0` release page: <https://github.com/intel-isl/OpenBot/releases/tag/v0.8.0>
- OpenBot `v0.7.0` release page: <https://github.com/intel-isl/OpenBot/releases/tag/v0.7.0>

## iOS / Mac Notes

### What I found

- the official OpenBot release history mentions iOS-related support and a newer controller implementation
- I did not find a public official `.ipa` download or App Store install link in the official release pages checked above

This means the most practical team option right now is usually Android-based testing, even for Mac users.

### Best option for Mac teammates

Use the official Android Studio Emulator:

- docs: <https://developer.android.com/studio/run/emulator>

This is useful for:

- opening the APK
- reviewing the UI
- demoing basic flows
- comparing OpenBot and OpenBene visually

This is not enough for:

- USB testing
- bluetooth behavior
- real hardware validation
- full backend/device integration

## Recommended Team Usage

### For UI-only teammates

- install one or both APKs
- compare layouts, navigation, and information density
- use screenshots and notes when proposing UI changes

### For hardware / integration teammates

- use the APKs only as a quick reference
- do real validation with local builds and device access

## Future Improvement

If this repository keeps growing, a better long-term option is:

- keep source code in the repo
- attach APKs to GitHub Releases instead of committing many binaries into the main branch

