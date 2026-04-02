# Control App

`control_app` is the controller-side Flutter UI. It is optimized for landscape use and currently focuses on the gamepad-inspired control interface.

## Active Entry Path

```text
lib/main.dart
  -> lib/app/control_app.dart
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
    services/               # camera, USB, bluetooth, OpenBene adapters
  test/
```

## Current Focus

- landscape controller UI
- dual-stick and arrow-throttle layouts
- camera preview when available
- USB/gamepad driven robot control path

## Collaboration Guide

- UI contributors: start in `lib/features/control` and `lib/core`.
- integration contributors: start in `lib/services`.
- if you do not have hardware access, prioritize layout, state flow, assets, and interaction polish.

## Notes

- some earlier robot-side scaffolding still exists in this app folder from past experiments, but the active team-project entry path is the control flow listed above
- for repo-wide context, read `../../docs/architecture.md`

## Run

```powershell
cd C:\Users\jiken\Desktop\openbot-ui\apps\control_app
flutter pub get
flutter run
```

