# Robot Runtime Baseline

Working interaction baseline for the `Robot` side of `Robot Controller`.

This document is the next step after the low-fidelity demo comparison.
It is not a final visual spec.
It is a product and implementation baseline for the next design and coding passes.

## Status

- Date: `2026-04-24`
- Source demos reviewed:
  - `docs/design/robot_app/visible_mode_rail/index.html`
  - `docs/design/robot_app/drive_first_advanced/index.html`
  - `docs/design/robot_app/workflow_card/index.html`
- Supporting specs:
  - `docs/robot-state-matrix.md`
  - `docs/robot-model-workflow.md`

## Baseline Decision

Use `Drive First + Advanced Entry` as the shell baseline.

Borrow one key idea from `Workflow Card`:

- `Auto` and `Track` prerequisites must be shown as explicit next steps, not hidden inside generic settings

This gives a hybrid direction:

- `Drive` is the obvious default runtime
- `Auto` and `Track` remain available, but do not occupy equal top-level priority
- blocked states still explain the next required action clearly

## Why This Direction

### Why not `Visible Mode Rail`

`Visible Mode Rail` is strong on discoverability, but it keeps advanced modes in the user's face all the time.

That creates two problems:

- the main camera runtime feels busier than necessary
- `Auto` and `Track` can look more runnable than they really are

For this product, that is the wrong bias.

### Why not pure `Workflow Card`

`Workflow Card` is strongest for blocked or staged tasks, especially `Track`.

But as a full-time shell pattern it is too opinionated for ordinary `Drive` use.

`Drive` is the default and most frequent runtime.
It should feel immediate, not like a wizard.

## Baseline Interaction Model

### 1. Shell Structure

Keep a stable 3-part shell:

1. Top health bar
2. Camera-first middle surface
3. Bottom primary action zone

Add one secondary entry for advanced modes.

That entry is visible, but not equal-weight with the primary action.

### 2. Default Entry

- app opens into `Robot`
- `Robot` opens into `Drive`
- advanced modes stay collapsed by default

The first question the Robot UI answers is:

- can I operate the robot safely right now

Not:

- which interesting mode do I want to browse

### 3. Advanced Mode Entry

The advanced entry opens a compact secondary surface for:

- `Auto`
- `Track`

Rules:

- collapsed by default
- available in healthy idle runtime
- visually suppressed while a run is active
- visually suppressed during setup or fault recovery

This means `Auto` and `Track` are deliberate choices, not ambient clutter.

### 4. Guided Readiness

When `Auto` or `Track` is selected, the UI must adopt the workflow-card behavior for prerequisites:

- show current readiness
- show one missing requirement
- show one dominant next action

Examples:

- `Load Model`
- `Select Target`
- `Start Auto`
- `Start Tracking`

Do not send users into a generic settings sheet to discover why a mode cannot run.

## Role Switching Baseline

The current `H / C` mini switch is not a suitable product interaction.

Baseline change:

- rename the role from `Host` to `Robot`
- replace the mini switch with a top-right role entry
- tapping it opens a role sheet or role confirmation surface

### Role Switch Rules

- if `Robot` is idle and healthy, switching is allowed
- if `Robot` is in setup or fault, switching is allowed
- if `Robot` is actively running, role switch is blocked behind a stop-first confirmation

Required copy:

- `Stop current run before switching role`

The product must not behave as if role switching is a casual tab change during motion.

## Mode Behavior Baseline

### Drive

Drive remains the primary lane.

Main behavior:

- plain `Start` / `Stop`
- local gamepad is the default expected owner
- collect-data stays secondary if it is retained at all
- speed tuning stays secondary

Drive should work without forcing the user through an advanced mode browser.

### Auto

Auto stays behind the advanced entry.

Main behavior:

1. select `Auto`
2. if no valid model exists, show `Load Model`
3. once model is valid, show `Start Auto`

Do not expose a long list of technical model controls in the main runtime surface.

### Track

Track also stays behind the advanced entry.

Main behavior:

1. select `Track`
2. if no valid model exists, show `Load Model`
3. once the model is valid, show `Select Target`
4. once target is ready, show `Start Tracking`

`Track` is the strongest case for guided staging.
The camera overlay should support that directly.

## Active-State Safety Rules

When any mode is actively running:

- primary action becomes `Stop`
- advanced mode entry is suppressed or disabled
- role switch is blocked behind stop-first confirmation
- ownership handoff must be explicit, not silent

The user should never be able to confuse:

- current mode
- current owner
- whether the robot is actually active

## Secondary Surfaces

These remain secondary and should not dominate the main runtime shell:

- model browser
- model metadata
- runtime device selection
- speed tuning
- debug details
- data collection controls

They can live in sheets or drawers, but they should not define the first-screen interaction logic.

## Current Implementation Gap

The current codebase is not aligned with this baseline yet.

### Current merged app shell

`apps/control_app/lib/app/fusion_app.dart` still uses:

- `FusionRole.host`
- `FusionRole.controller`
- a floating `H / C` mini switch

That does not match the intended product language or the stop-first role-switch behavior.

### Current Robot runtime interaction

`apps/control_app/lib/legacy/robot_shell/features/robot_camera/presentation/robot_camera_screen.dart`
and
`apps/robot_app/lib/features/robot_camera/presentation/robot_camera_screen.dart`
still center the runtime around:

- swipe mode switching
- a general settings surface
- equally visible mode concepts

That conflicts with the new baseline.

### Current Robot state model

`apps/robot_app/lib/features/robot_camera/state/robot_camera_state.dart`
still contains:

- `driveArmed`
- hardcoded model enums for `Auto` and `Track`
- mode-specific settings embedded directly in the runtime state

That is still close to the current prototype, not the target product model.

## Recommended Implementation Order

### Phase 1: Role and shell cleanup

- rename user-facing `Host` to `Robot`
- replace `H / C` switch with a role entry and confirmation logic
- keep existing runtime behavior underneath if needed

### Phase 2: Mode-entry refactor

- remove swipe-first mode switching
- introduce `Drive` as the default shell
- add a compact advanced entry for `Auto` / `Track`
- keep one dominant primary action

### Phase 3: Model workflow integration

- replace hardcoded Auto / Track model selection with a model readiness flow
- move import / validation / selection out of generic settings
- keep `Track` target selection as a staged camera action

### Phase 4: State model cleanup

- decide whether `driveArmed` remains a real internal safety concept or is removed from user-facing state
- split product state from low-level runtime configuration
- prepare shared model metadata structures for both standalone and merged app paths

## Decision To Carry Forward

Until a better direction appears, use this rule:

- baseline shell: `Drive First + Advanced Entry`
- readiness behavior for `Auto` / `Track`: guided, workflow-like

That is the working product direction for the next design and implementation pass.
