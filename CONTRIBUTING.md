# Contributing Guide

This repository is organized so teammates can collaborate without stepping on each other.

## 1. Source Of Truth

Active team-project code lives in:

- `apps/control_app`
- `apps/robot_app`
- `packages/*`
- `docs/*`

Archived or non-mainline material:

- `apps/controller_app`
- `apps/control_app/lib/legacy`
- `docs/design`
- `Individual Project`

## 2. What To Edit

### If you are working on controller-side UI

Edit:

- `apps/control_app/lib/features/control`
- `apps/control_app/lib/core`
- `apps/control_app/assets`

Avoid editing:

- `apps/control_app/lib/legacy`

### If you are working on robot-side UI

Edit:

- `apps/robot_app/lib/features`
- `apps/robot_app/lib/core`
- `apps/robot_app/assets`

### If you are working on hardware or backend integration

Edit:

- `apps/control_app/lib/services`
- `apps/robot_app/lib/services`
- `packages/openbene_bridge`
- `packages/shared_models`

### If you do not have hardware

Prefer:

- presentation
- state modeling
- themes and assets
- mock planning
- docs

Do not take ownership of real hardware behavior changes unless someone with device access can verify them.

## 3. What Not To Commit

Never commit:

- build output
- local logs
- IDE temp files
- local device config

The repo `.gitignore` already covers the common cases, but still check your staged files before committing.
The repo `.gitattributes` also normalizes line endings so Windows-only newline noise does not pollute commits.

## 4. Practical Team Split

### UI-focused teammate

Owns:

- layouts
- visual polish
- interaction flow
- copy changes

Typical folders:

- `lib/features/*/presentation`
- `lib/core/theme`

### State / app-flow teammate

Owns:

- controllers
- local state
- navigation and app wiring

Typical folders:

- `lib/features/*/state`
- `lib/app`

### Hardware / integration teammate

Owns:

- adapters
- platform bridges
- device communication

Typical folders:

- `lib/services`
- `packages/openbene_bridge`

### Shared-model teammate

Owns:

- common enums
- payloads
- protocol-facing data structures

Typical folders:

- `packages/shared_models`

## 5. Branch And Commit Rules

Use one branch per focused task.

Good branch examples:

- `feat/control-layout-polish`
- `feat/robot-setup-flow`
- `refactor/control-legacy-archive`
- `docs/collaboration-guide`

Keep commits scoped.

Good commit examples:

- `Refine control_app landscape layout`
- `Document active vs legacy paths`
- `Add shared telemetry models`

Avoid mixing these in one commit:

- UI changes
- service/integration changes
- documentation-only changes

## 6. Before You Commit

Check:

1. Are you only changing the area you intended to own?
2. Did you accidentally touch generated files or logs?
3. If you changed integration code, did you note what was and was not tested?
4. If you changed shared models, did you check both apps for impact?

## 7. Handoff Expectations

When handing work to a teammate, include:

- what changed
- where it changed
- what still needs testing
- whether hardware access is required next

Use `docs/status/team-sync-template.md` for progress updates.

## 8. Real-World Collaboration Rules

Because the team is remote and hardware access is uneven:

- UI work should not wait on hardware by default
- hardware-specific behavior should stay behind service/adaptor boundaries
- shared model changes should be announced before merge
- if a teammate cannot test on device, they should still be able to continue work from mocks, screenshots, and documented assumptions
