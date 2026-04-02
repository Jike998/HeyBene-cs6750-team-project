# OpenBot UI Team Workspace

This repository is organized for the Georgia Tech CS6750 team project.

The current mainline scope is:

- `apps/control_app`: controller-side Flutter UI
- `apps/robot_app`: robot-side Flutter UI

`apps/controller_app` is intentionally kept out of the team-project mainline for now. It remains local as an archive/reference, but it is not part of the first GitHub push.

## Repository Map

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

## Why This Layout

- `control_app` and `robot_app` are both active UI workstreams.
- `docs/` is the shared entry point for teammates who need context quickly.
- `packages/` is reserved for shared code, mock implementations, and the later OpenBene APK migration.
- design artifacts were moved into `docs/design/` so the repository root stays readable.

## Start Here

1. Read `docs/architecture.md`.
2. Read `docs/onboarding.md`.
3. Read `CONTRIBUTING.md`.
4. Pick one app as your primary area.
5. Use `docs/status/team-sync-template.md` when syncing progress with teammates.
6. Use `downloads/README.md` if you want installable reference apps for demos or team onboarding.
7. Use `docs/releases/team-build-release-checklist.md` when publishing team APKs through GitHub Releases.

## Run The Apps

### `control_app`

```powershell
cd C:\Users\jiken\Desktop\openbot-ui\apps\control_app
flutter pub get
flutter run
```

### `robot_app`

```powershell
cd C:\Users\jiken\Desktop\openbot-ui\apps\robot_app
flutter pub get
flutter run
```

## Collaboration Notes

- UI-first contributors should spend most of their time in `lib/features` and `lib/core`.
- hardware/backend integration should be isolated behind `lib/services` and later `packages/openbene_bridge`.
- teammates without hardware should still be able to contribute through UI, state, design review, and mock-oriented planning.
- `apps/control_app/lib/legacy` is archive code, not a mainline feature area.

## References

Reference repositories that informed this workspace but were not modified here:

- `C:/Users/jiken/Desktop/OpenBene/openbot-mobile-control`
- `C:/Users/jiken/Desktop/Openbot/OpenBot-master/OpenBot-master`
