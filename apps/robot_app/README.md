# Robot App

`robot_app` is the robot-side Flutter UI. It currently follows a camera-first flow with setup, connection state, and robot-facing telemetry scaffolding.

## Active Entry Path

```text
lib/main.dart
  -> lib/app/robot_app.dart
  -> lib/features/setup/presentation/setup_screen.dart
  -> lib/features/robot_camera/presentation/robot_camera_screen.dart
```

## Folder Structure

```text
robot_app/
  android/                  # Android platform config
  ios/                      # iOS platform config
  assets/                   # images and other static assets
  lib/
    app/                    # app composition, bootstrap, coordinators
    core/                   # theme, constants, shared app-level utilities
    features/
      connection/
      modes/
      robot_camera/
      setup/
      telemetry/
    services/               # camera, network, USB, bluetooth, OpenBene adapters
  test/
```

## Current Focus

- setup and connection flow
- camera-first robot UI
- drive / auto / track mode scaffolding
- telemetry and robot state presentation

## Collaboration Guide

- UI contributors: start in `lib/features/*/presentation`
- state contributors: start in `lib/features/*/state` and `lib/app`
- hardware/backend integration contributors: start in `lib/services`

## Run

```powershell
cd C:\Users\jiken\Desktop\openbot-ui\apps\robot_app
flutter pub get
flutter run
```

For repo-wide context, read `../../docs/architecture.md`.

