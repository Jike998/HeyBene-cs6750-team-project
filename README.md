# OpenBot UI Team Workspace

[中文说明](README.zh.md) | [English](README.md)

This repository is organized for the Georgia Tech CS6750 team project.

Current working baseline:

- active branch for robot runtime work: `backup/working-tree-20260428-1615`
- current active app focus: `apps/robot_app`

## Current app scope

- `apps/control_app`: merged Flutter app with role switching and controller-side UI work
- `apps/robot_app`: standalone robot-side Flutter app, independently runnable, currently the main runtime focus

## Start here

1. Read [README.zh.md](README.zh.md) if you want the Chinese overview.
2. Read [docs/status/robot_app_handoff.md](docs/status/robot_app_handoff.md) for the current English handoff.
3. Read [docs/status/robot_app_handoff_zh.md](docs/status/robot_app_handoff_zh.md) for the current Chinese handoff and device test steps.
4. Read [docs/architecture.md](docs/architecture.md).
5. Read [docs/onboarding.md](docs/onboarding.md).
6. Read [CONTRIBUTING.md](CONTRIBUTING.md).

## Repository map

```text
openbot-ui/
  apps/
    control_app/
    robot_app/
  docs/
    architecture.md
    onboarding.md
    run-modes.md
    design/
    migration/
    status/
  downloads/
    README.md
    android/
  packages/
    mock_services/
    openbene_bridge/
    shared_models/
```

## Run the apps

### robot_app

```powershell
cd C:\Users\jiken\Desktop\openbot-ui\apps\robot_app
flutter pub get
flutter run
```

### control_app

```powershell
cd C:\Users\jiken\Desktop\openbot-ui\apps\control_app
flutter pub get
flutter run
```

## Important current product rules

- `Robot` is the source-of-truth runtime.
- `Controller` is a remote control/view surface.
- `START / STOP` is the single runtime gate for `Drive / Auto / Track`.
- `START` stays visible but disabled until `Car USB` is connected.
- Video starts only after `START`.
- Remote control is accepted only after `START`.
- `Track` now means category-based automatic detection and following, not tap-to-select targeting.

## Key current docs

- [Robot App Handoff](docs/status/robot_app_handoff.md)
- [Robot App 中文交接文档](docs/status/robot_app_handoff_zh.md)
- [Architecture](docs/architecture.md)
- [Onboarding](docs/onboarding.md)

## Collaboration notes

- For current robot runtime work, prefer `apps/robot_app` as the main implementation surface.
- Use the handoff docs in `docs/status/` before starting UI, backend, or device testing work.
- The Chinese handoff doc includes the current step-by-step device testing flow.
