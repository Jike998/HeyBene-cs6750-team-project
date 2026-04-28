# Control App

`control_app` is the current mainline Flutter app. It now hosts the merged `FusionApp` experience while still containing the standalone controller-side flow.

## Active Entry Path

```text
lib/main.dart
  -> lib/app/fusion_app.dart
     -> host role
        -> lib/legacy/robot_shell/...
     -> controller role
        -> lib/features/control/presentation/control_screen.dart
```

## Folder Structure

```text
control_app/
  android/                  # Android platform config
  ios/                      # iOS platform config
  assets/                   # images and other static assets
  lib/
    app/                    # app composition and bootstrap
    core/                   # theme, constants, shared UI primitives
    features/
      control/              # active controller UI flow
      connection/           # emerging shared controller-side domain models
      telemetry/            # emerging shared controller-side domain models
    legacy/                 # transitional host-role dependency and older archive code
    services/               # camera, USB, bluetooth, OpenBene adapters
  test/
```

## Current Focus

- one-phone role switching through `FusionApp`
- landscape controller UI
- dual-stick and arrow-throttle layouts
- camera preview when available
- USB/gamepad driven robot control path

## Collaboration Guide

- UI contributors: start in `lib/features/control` and `lib/core`.
- integration contributors: start in `lib/services`.
- if you do not have hardware access, prioritize layout, state flow, assets, and interaction polish.

## Notes

- `lib/main.dart` currently launches `FusionApp`
- `lib/legacy/robot_shell` is still used by the host role as a temporary active dependency
- new shared logic should prefer active paths or shared packages over deeper coupling to `lib/legacy/robot_shell`
- for repo-wide context, read `../../docs/architecture.md` and `../../CONTRIBUTING.md`

## Run

```powershell
cd C:\Users\jiken\Desktop\openbot-ui\apps\control_app
flutter pub get
flutter run
```
