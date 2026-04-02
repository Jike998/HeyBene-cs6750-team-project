# Reference App Downloads

This folder keeps the APKs that are safe and useful to store directly in the repository.

## Included In The Repo

### Baseline reference

| APK | Path | Size (bytes) | SHA-256 | Purpose |
| --- | --- | ---: | --- | --- |
| OpenBot 0.8.0 | `downloads/android/openbot-original/OpenBot-0.8.0.apk` | 41,149,683 | `E313F14FF3462EF3763AC9002D4E261299C66C1662041E0172AA0839B55474B0` | Original OpenBot app for baseline comparison |

### OpenBene reference

| APK | Path | Size (bytes) | SHA-256 | Purpose |
| --- | --- | ---: | --- | --- |
| OpenBene v1.0.6 with discovery | `downloads/android/openbene/openbene-mobile-control-v1.0.6-with-discovery.apk` | 22,088,663 | `749FCC25D32057997F6E77AA89A4451528405D8C4E9C7F5B758EEF23C3FB9829` | Shareable OpenBene-based reference build |

## Team Builds

The current `control_app` and `robot_app` APKs are too large for normal repository storage, so they should be shared through GitHub Releases instead of being committed into the repo tree.

Use:

- Releases page: <https://github.com/Jike998/HeyBene-cs6750-team-project/releases>
- release instructions: `docs/releases/team-build-release-checklist.md`

Expected release assets:

- `control_app-debug.apk`
- `robot_app-debug.apk`

## Official OpenBot Links

- OpenBot repository: <https://github.com/intel-isl/OpenBot>
- OpenBot releases: <https://github.com/intel-isl/OpenBot/releases>
- OpenBot `v0.8.0` release page: <https://github.com/intel-isl/OpenBot/releases/tag/v0.8.0>

## iOS / Mac Notes

- I did not find a public official `.ipa` download or App Store install link in the official OpenBot release pages I checked
- for Mac teammates, the most practical option is the Android Studio Emulator:
  <https://developer.android.com/studio/run/emulator>
- emulator use is good for UI review and basic flow demos, but not for USB, bluetooth, or real hardware validation

