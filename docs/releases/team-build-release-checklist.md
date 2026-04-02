# Team Build Release Checklist

Use this when publishing the current `control_app` and `robot_app` APKs through GitHub Releases.

## Why Releases

The debug APKs are too large for normal repository storage, so they should be uploaded as Release assets instead of being committed into the repo tree.

## Recommended Release Title

- tag: `team-builds-2026-04-02`
- title: `Team Builds 2026-04-02`

You can change the date if you publish later.

## Assets To Upload

### 1. `control_app`

- asset name: `control_app-debug.apk`
- local source: `C:\Users\jiken\Desktop\openbot-ui\apps\control_app\build\app\outputs\apk\debug\app-debug.apk`

### 2. `robot_app`

- asset name: `robot_app-debug.apk`
- local source: `C:\Users\jiken\Desktop\openbot-ui\apps\robot_app\build\app\outputs\apk\debug\app-debug.apk`

## Suggested Release Notes

```text
This release contains the current team debug APKs for quick review and comparison.

Assets:
- control_app-debug.apk
- robot_app-debug.apk

Notes:
- These are team debug builds for demo and review.
- Hardware-specific behavior still requires real-device validation.
- For baseline comparison, see the APKs stored in downloads/android/.
```

## Manual GitHub Steps

1. Open `https://github.com/Jike998/HeyBene-cs6750-team-project/releases`
2. Click `Draft a new release`
3. Create the tag
4. Set the release title
5. Upload the two APK files listed above
6. Paste the suggested release notes
7. Publish the release

## Temporary Fallback

If GitHub Release upload fails in the current network environment, use the existing Google Drive links for teammates:

- `control_app`: <https://drive.google.com/file/d/155Xqbi4ChW1p0FqazVg9a3PDAoNcy21A/view?usp=sharing>
- `robot_app`: <https://drive.google.com/file/d/19NxdyigiTyACQJaqd52NI3z4Qv1NgxVv/view?usp=sharing>
