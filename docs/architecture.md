# Architecture

## Mainline Scope

The current team-project mainline includes only two apps:

- `apps/control_app`
- `apps/robot_app`

`apps/controller_app` is not part of the initial GitHub mainline.

## Repository Layout

```text
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

packages/
  mock_services/
  openbene_bridge/
  shared_models/
```

## Active Vs Archived Paths

### Active

- `apps/control_app/lib/app/control_app.dart`
- `apps/control_app/lib/features/control`
- `apps/robot_app/lib/app`
- `apps/robot_app/lib/features`
- `apps/*/lib/services`
- `packages/*`

### Archived

- `apps/control_app/lib/legacy/robot_shell`
- `apps/controller_app`
- `docs/design`

## App-Level Structure

Both Flutter apps follow the same high-level layering:

```text
lib/
  main.dart
  app/          # app shell, bootstrap, coordinators
  core/         # theme, constants, shared UI helpers
  features/     # feature-first folders
  services/     # boundary to hardware, network, bluetooth, OpenBene
```

## Team Boundaries

### UI and Interaction

- work in `lib/features/*/presentation`
- work in `lib/core/theme`
- keep UI-specific state readable and testable

### App State and Flow

- work in `lib/features/*/state`
- work in `lib/app`
- keep feature boundaries clear

### Hardware / Backend Integration

- work in `lib/services`
- avoid leaking hardware-specific code directly into `presentation`
- prefer adapters and interfaces so remote contributors are not blocked

## Planned Shared Packages

### `packages/shared_models`

Shared data structures, protocol models, enums, and constants used by both apps.

### `packages/mock_services`

Mock or fake service implementations for teammates who cannot test with real hardware.

### `packages/openbene_bridge`

The future landing zone for selected APK/Android logic migrated from OpenBene.

## Current Practical Rule

If a teammate cannot access hardware, they should still be able to contribute safely by working in:

- `presentation`
- `state`
- `theme`
- `shared_models`
- `mock_services`

For day-to-day collaboration rules, read `../CONTRIBUTING.md`.
