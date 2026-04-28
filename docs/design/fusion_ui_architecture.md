# Fusion UI Architecture

This document defines the logical framework for the merged app.

It is intentionally about:

- hierarchy
- state ownership
- button / tag responsibilities
- relationships between UI elements

It is not a visual spec.

## Goal

Clarify the merged app around the two existing runtimes already present in the repo:

- `Robot`
- `Controller`

The key rule is:

- the merged app is not a third brand-new app
- it is a shell that switches between two existing runtime surfaces

## Current Code Basis

The architecture must stay grounded in the current implementation:

- shared shell:
  - `apps/control_app/lib/app/fusion_app.dart`
- current Robot runtime:
  - `apps/control_app/lib/legacy/robot_shell/features/robot_camera/presentation/robot_camera_screen.dart`
  - `apps/control_app/lib/legacy/robot_shell/features/robot_camera/state/robot_camera_state.dart`
- current Controller runtime:
  - `apps/control_app/lib/features/control/presentation/control_screen.dart`
  - `apps/control_app/lib/features/control/state/control_state.dart`

## 1. Canonical Hierarchy

The merged app should be understood as a five-level hierarchy.

### L0 App Shell

Scope:

- global role switching only

Elements:

- role switch button
- role picker sheet
- stop-first guard dialog when leaving active `Robot`

Rules:

- this layer must not contain Robot mode controls
- this layer must not contain Controller layout controls
- this layer only decides which runtime root is visible

### L1 Role Runtime Root

Exactly one of these is active:

- `RobotRuntimeRoot`
- `ControllerRuntimeRoot`

Rules:

- each role owns its own state model
- each role owns its own persistent runtime chrome
- role internals should not leak back into L0 shell

### L2 Persistent Runtime Controls

These are always or usually visible while a role is active.

Examples:

- Robot top health bar
- Robot camera surface
- Robot bottom primary action zone
- Controller top transport bar
- Controller camera surface
- Controller primary input surface

### L3 Contextual Secondary Surfaces

These appear only in specific role states.

Examples:

- Robot advanced mode panel
- Robot target overlay
- Controller AI target confirmation
- Controller layout picker

Rules:

- these depend on the active role and runtime state
- they must never redefine the meaning of L0 or L1

### L4 Modal / Sheet Flows

Examples:

- role picker
- stop-first confirmation dialog
- Robot settings sheet
- Controller link chooser
- Controller bonded device picker

Rules:

- sheets are for secondary decisions
- primary runtime progress should not depend on browsing a generic sheet unless the task is inherently secondary

## 2. Architecture Tree

```text
FusionApp
|- L0 Shell
|  |- Role switch button
|  |- Role picker sheet
|  `- Stop-first guard dialog
|- RobotRuntimeRoot
|  |- L2 Top health bar
|  |- L2 Camera surface
|  |- L2 Bottom primary action zone
|  |- L3 Advanced mode panel
|  |- L3 Track target overlay
|  `- L4 Settings sheet
`- ControllerRuntimeRoot
   |- L2 Top transport bar
   |- L2 Camera surface
   |- L2 Primary input surface
   |- L3 Layout switcher / mode strip
   |- L3 AI target confirmation
   `- L4 Link chooser sheets
```

## 3. State Taxonomy

The most important architecture rule is that different layers own different types of state.

### 3.1 Shared Shell State

Owned by `FusionApp`.

| State | Meaning | Must Not Control |
| --- | --- | --- |
| `role` | `robot` or `controller` | Robot mode, Controller layout |
| `roleSwitchBusy` | guards repeated switch actions | runtime UI content |
| `pendingRole` | used during stop-first handoff | runtime semantics |

### 3.2 Robot State

Owned by `RobotCameraState` plus Robot controllers.

Canonical dimensions:

| State | Meaning |
| --- | --- |
| `systemState` | `booting`, `setupNeeded`, `ready`, `fault` |
| `mode` | `drive`, `auto`, `track` |
| `runState` | `idle`, `active` |
| `controlOwner` | `localGamepad`, `remotePhone`, `pc`, `none` |
| `modeReadiness` | `ready`, `modelMissing`, `targetMissing` |

Current implementation already partially maps to this through:

- `mode`
- `isRunning`
- `connection.usbConnected`
- `driveController`
- `trackingPoint`

But it still has older state mixed in:

- `driveArmed`
- hardcoded model enums directly on runtime state

### 3.3 Controller State

Owned by `ControlState` plus `ControlController`.

Canonical dimensions:

| State | Meaning |
| --- | --- |
| `transportState` | `disconnected`, `connecting`, `linked` |
| `controllerLayout` | `mobileGamer`, `dual`, `arrow`, future presets |
| `driveMode` | `manual`, `autoTracking`, future controller modes |
| `inputState` | `idle`, `steering`, `throttle`, `braking`, `combined` |
| `feedbackState` | `normal`, `aiVisible`, `linkWarning` |

Current implementation already has:

- `layout`
- link-related state through `connection`, `linkBusy`, Bluetooth / USB controller services
- visual input state:
  - `dualSteering`
  - `dualThrottle`
  - `arrowSteering`
  - `arrowThrottle`
  - button pressed flags

Current implementation does not yet have a first-class controller-side:

- `driveMode` such as `manual` vs `autoTracking`

This is a real architecture gap.

That means:

- `controllerLayout` and `driveMode` must be separated explicitly
- future controller modes should not be shoved into the same variable as layout

## 4. Buttons vs Tags

Every visible element should belong to one of two groups:

### Buttons

Definition:

- changes state
- opens a sheet
- opens a secondary surface
- confirms or cancels a flow

Examples:

- role switch button
- Robot primary action button
- Robot advanced-mode entry
- Robot settings button
- Controller robot-link button
- Controller layout switcher

### Tags

Definition:

- reports status only
- should not change app state

Examples:

- `Robot`
- `Bridge Ready`
- `Owner: Gamepad`
- battery / latency tags
- `Drive`
- `Auto`
- `BT Linked`

Architecture rule:

- a tag should not secretly behave like a button unless that is explicit in its design and naming
- if an element is clickable, it should read like an action

## 5. Shared Shell Inventory

This section is the L0 architecture inventory.

| Element | Type | Visible When | Action | Relationship |
| --- | --- | --- | --- | --- |
| Role switch button | button | always | opens role picker | chooses runtime root |
| Role picker sheet | modal | after role switch tap | choose `Robot` or `Controller` | updates shell `role` |
| Stop-first confirmation | modal | switching away from active `Robot` | cancel or stop-and-switch | depends on Robot `runState` |

Key relationship:

- L0 may ask Robot runtime whether it is safe to leave
- L0 must not directly mutate Robot mode or Controller layout

## 6. Robot Role Inventory

This section describes the architecture of the current Robot runtime and the intended logical framework.

### 6.1 Robot Layer Map

| Layer | Surface | Responsibility |
| --- | --- | --- |
| L2 | Top health bar | global Robot status |
| L2 | Camera surface | primary visual context |
| L2 | Bottom primary action zone | one dominant next action |
| L3 | Advanced mode panel | choose `Auto` or `Track` |
| L3 | Track target overlay | target selection / target confirmation |
| L4 | Settings sheet | secondary tuning and configuration |

### 6.2 Robot Persistent Elements

| Element | Type | Current Source | Function | Depends On |
| --- | --- | --- | --- | --- |
| `Robot` pill | tag | top bar | identify role | shell role = `Robot` |
| bridge status pill | tag | top bar | setup / health status | init + USB status |
| owner pill | tag | top bar | show winning control owner | controller source state |
| remote link pill | tag | top bar | show phone-link status | Bluetooth status |
| battery / latency pill | tag | top bar | show telemetry summary | telemetry snapshot |
| mode pill | tag | top bar | show current Robot mode | `mode` |
| settings icon | button | top bar | open settings sheet | always available as secondary action |
| status card | informational panel | upper body | summarize current state | `systemState`, `mode`, `runState` |
| camera surface | primary surface | middle layer | display scene; allow target tap in `Track` | active role + mode |
| bottom primary button | button | bottom panel | derived next action | `systemState + mode + runState + readiness` |
| `Advanced Modes` button | button | bottom panel | open or close advanced panel | suppressed while active |

### 6.3 Robot Contextual Elements

| Element | Type | Visible When | Function |
| --- | --- | --- | --- |
| advanced mode panel | L3 panel | idle + advanced open | choose `Auto` or `Track` |
| target overlay | L3 overlay | `Track` with target | show AI target |
| mode-specific settings rows | L4 sheet | settings open | configure mode-specific secondary options |

### 6.4 Robot Primary Action Logic

The bottom primary button is the center of the Robot architecture.

It should be derived, not screen-specific.

| Conditions | Primary Action |
| --- | --- |
| not initialized | `Starting...` |
| bridge missing | `Connect Robot` |
| `Drive + idle` | `Start` |
| `Drive + active` | `Stop` |
| `Auto + model missing` | `Load Model` |
| `Auto + ready + idle` | `Start Auto` |
| `Auto + active` | `Stop Auto` |
| `Track + model missing` | `Load Model` |
| `Track + target missing` | `Select Target` |
| `Track + ready + idle` | `Start Tracking` |
| `Track + active` | `Stop Tracking` |
| fault | `Recover` |

### 6.5 Robot Relationships

- top bar tags are global Robot status only
- camera surface is the only place where target selection should happen
- bottom primary zone owns the current next step
- advanced mode panel can change `mode`, but only while idle
- settings sheet must stay secondary and must not replace the primary action flow

## 7. Controller Role Inventory

This section describes the architecture of the current Controller runtime and the intended logical framework.

### 7.1 Controller Layer Map

| Layer | Surface | Responsibility |
| --- | --- | --- |
| L2 | Top transport bar | connection and controller-surface selection |
| L2 | Camera surface | driving context |
| L2 | Primary input surfaces | steering + throttle / stop input |
| L3 | AI confirmation overlay | trust cue when assist mode is active |
| L4 | link chooser sheets | transport setup and device selection |

### 7.2 Controller Persistent Elements

| Element | Type | Current Source | Function | Depends On |
| --- | --- | --- | --- | --- |
| robot-link pill | button | top bar | open link flow or disconnect current link | BT / USB link state |
| latency pill | tag | top bar | report link responsiveness | telemetry latency |
| layout switcher | button group | top bar | choose control surface layout | `ControlState.layout` |
| init error pill | tag | top area | surface controller initialization failure | `initializationError` |
| camera / scene | primary surface | background | contextual driving view | camera availability |
| left control cluster | input surface | lower left | steering control visualization / input surface | `layout` |
| right control cluster | input surface | lower right | throttle / stop control visualization / input surface | `layout` |

### 7.3 Controller Contextual Elements

| Element | Type | Visible When | Function |
| --- | --- | --- | --- |
| robot link chooser sheet | L4 sheet | after link pill tap with no active link | choose BT vs USB |
| bonded robot picker | L4 sheet | after choosing BT | pick robot phone |
| future AI feed overlay | L3 overlay | `driveMode == autoTracking` | confirm AI ownership on feed |

### 7.4 Current Controller Architecture Gap

Current Flutter controller UI is organized around:

- `layout`
- transport state
- visualized input state

But it does not yet have a first-class controller runtime mode such as:

- `manual`
- `autoTracking`

This matters because the user wants controller-side modes to expand later.

So the correct architecture is:

- `controllerLayout` decides how controls are physically arranged
- `driveMode` decides what kind of command model is active

These are separate axes.

### 7.5 Controller Relationships

- transport state is orthogonal to controller layout
- controller layout is orthogonal to controller mode
- controller mode is orthogonal to Robot runtime mode
- the link chooser is setup flow, not a runtime mode
- future controller modes should appear inside Controller runtime, not in the shared shell

## 8. Relationship Rules Between Robot And Controller

This is the most important separation.

### Must Be Separate

- shell `role`
- Robot `mode`
- Controller `driveMode`
- Controller `layout`

### Correct Relationship

| Axis | Example Values | Owned By |
| --- | --- | --- |
| `role` | `robot`, `controller` | shell |
| Robot runtime mode | `drive`, `auto`, `track` | Robot runtime |
| Controller runtime mode | `manual`, `autoTracking`, future controller modes | Controller runtime |
| Controller layout | `dual`, `arrow`, `mobileGamer`, future custom presets | Controller runtime |

### Wrong Relationship

These should not be collapsed into one selector:

- `Robot` vs `Controller`
- `Drive` vs `Auto` vs `Track`
- `Manual` vs `Auto Tracking`
- `Dual` vs `Arrow` vs future controller presets

They belong to different layers.

## 9. What Should Never Be Visible At The Same Level

To avoid future architectural drift:

- role switch and controller layout switch should not look like siblings
- Robot primary action and generic settings should not have equal emphasis
- Controller mode switch and Robot mode switch should never appear in the same strip
- transport setup sheets should not pretend to be controller modes
- AI trust overlays should not replace core status ownership text

## 10. Immediate Architecture Conclusions

### Conclusion 1

The next step should be architecture-first, not visuals-first.

### Conclusion 2

The current merged app shell in `FusionApp` is the correct base layer.

### Conclusion 3

`Robot` and `Controller` need separate, explicit state taxonomies.

### Conclusion 4

The most important missing architecture piece on the controller side is:

- explicit controller runtime mode separate from layout

### Conclusion 5

Any future prototype or Flutter refactor should be checked against this rule:

- if a control mixes shell, Robot mode, Controller mode, and layout semantics, the architecture is wrong

## 11. Recommended Next Deliverables

Before rebuilding more demo UI, the next useful artifacts are:

1. a `Robot` button / tag matrix mapped to actual state transitions
2. a `Controller` button / tag matrix mapped to actual state transitions
3. a revised merged prototype that follows this document exactly
