# Fusion UI Element Matrix

This document answers one architecture question only:

- what visible buttons, tags, and surfaces exist in the merged app
- which layer each one belongs to
- what state it depends on
- what it changes
- how it relates to neighboring controls

It is grounded in the current merged implementation, not a greenfield redesign.

## Current Code Basis

- shell:
  - `apps/control_app/lib/app/fusion_app.dart`
- Robot runtime:
  - `apps/control_app/lib/legacy/robot_shell/features/robot_camera/presentation/robot_camera_screen.dart`
  - `apps/control_app/lib/legacy/robot_shell/features/robot_camera/state/robot_camera_state.dart`
- Controller runtime:
  - `apps/control_app/lib/features/control/presentation/control_screen.dart`
  - `apps/control_app/lib/features/control/state/control_state.dart`
  - `apps/control_app/lib/features/control/state/control_controller.dart`

## How To Read This Matrix

### Layer model

| Layer | Meaning |
| --- | --- |
| `L0` | shared shell navigation |
| `L1` | role runtime root |
| `L2` | persistent runtime controls always or usually visible in a role |
| `L3` | contextual panels or overlays visible only in some runtime states |
| `L4` | modal or sheet flows for secondary decisions |

### Element types

| Type | Meaning |
| --- | --- |
| `button` | changes state or opens another surface |
| `tag` | reports state only |
| `info` | explanatory text or derived status summary |
| `surface` | primary visual or interactive area, not a simple button/tag |
| `sheet` | modal or bottom-sheet container |

### Separation rule

These axes must never be collapsed into the same selector:

| Axis | Owned by | Current implementation status |
| --- | --- | --- |
| `role` | `FusionApp` shell | implemented |
| Robot `mode` | Robot runtime | implemented |
| Controller `layout` | Controller runtime | implemented |
| Controller `driveMode` | Controller runtime | missing |

## 1. Shared Shell Matrix

| Element | Layer | Type | Visible when | Action or meaning | Depends on | Relationship |
| --- | --- | --- | --- | --- | --- | --- |
| Role switch button | `L0` | `button` | always | opens role picker | `FusionApp._roleSwitchBusy`, current `role` | changes runtime root only; must not change Robot mode or Controller layout |
| Role picker sheet | `L4` | `sheet` | after role switch tap | choose `Robot` or `Controller` | `FusionRole.values`, current `role` | secondary navigation flow owned by shell |
| Stop-and-switch dialog | `L4` | `sheet` | only when leaving active Robot runtime | cancel switch or stop current Robot run and continue switch | `RobotCameraState.isRunning` via `prepareToLeaveRole()` | safety guard between shell and Robot runtime |

## 2. Robot Runtime Matrix

### 2.1 Persistent Robot Elements

| Element | Layer | Type | Visible when | Action or meaning | Depends on | Relationship |
| --- | --- | --- | --- | --- | --- | --- |
| `Robot` pill | `L2` | `tag` | `role == robot` | identifies active runtime | shell `role` | identity tag only |
| bridge status pill | `L2` | `tag` | always in Robot top bar | shows `Starting`, `Bridge Ready`, or `Bridge Missing` | `RobotCameraController.initialized`, `state.connection.usbConnected` | global health tag that drives setup state and primary action |
| owner pill | `L2` | `tag` | always in Robot top bar | shows winning controller owner | `state.driveController`, `state.gamepadConnected`, `state.connection.bluetoothConnected` | reports ownership; must not be the owner selector |
| remote link pill | `L2` | `tag` | always in Robot top bar | shows remote-phone connection availability | `state.connection.bluetoothConnected` | not the same thing as control ownership |
| battery / latency pill | `L2` | `tag` | always in Robot top bar | reports telemetry summary | `state.telemetry` | runtime health only |
| mode pill | `L2` | `tag` | always in Robot top bar | reports current Robot mode | `state.mode` | passive state label; not the mode switch |
| top settings icon | `L2` | `button` | always | opens settings sheet | none | secondary action only; should not compete with primary action |
| status card | `L2` | `info` | always | summarizes current Robot state with headline and body text | `initialized`, `state.connection.usbConnected`, `state.mode`, `state.isRunning`, `state.trackingPoint`, `advancedOpen` | explanation layer between tags and primary action |
| camera surface | `L2` | `surface` | always | main visual context | active Robot runtime | in `Track`, this surface also becomes the targeting surface |
| `Current Mode` meta box | `L2` | `info` | always in bottom panel | reports current mode | `state.mode` | passive summary inside primary action zone |
| `Next Step` meta box | `L2` | `info` | always in bottom panel | reports derived next action | `_nextStepLabel()` | mirrors but does not replace primary button |
| primary action button | `L2` | `button` | always in bottom panel | runs the next dominant action | `_primaryActionFor()` using `initialized`, USB state, `state.mode`, `state.isRunning`, `state.trackingPoint` | this is the only dominant runtime action |
| `Advanced Modes` / `Back To Drive` button | `L2` | `button` | always in bottom panel | opens advanced panel or returns to `Drive` | `_advancedOpen`, `state.mode`, `state.isRunning` | secondary mode-entry control; disabled during active run |
| bottom settings button | `L2` | `button` | always in bottom panel | opens settings sheet | none | duplicates the top settings icon; same action, different placement |
| footer note | `L2` | `info` | always in bottom panel | explains current rule or restriction | `state.isRunning`, `advancedOpen` | guidance only |

### 2.2 Contextual Robot Elements

| Element | Layer | Type | Visible when | Action or meaning | Depends on | Relationship |
| --- | --- | --- | --- | --- | --- | --- |
| advanced mode panel | `L3` | `surface` | `_advancedOpen == true` or `state.mode != drive` | exposes `Auto` and `Track` as explicit secondary choices | `_advancedOpen`, `state.mode`, `state.isRunning` | not part of shell navigation; only a Robot-mode chooser |
| `Auto` mode card | `L3` | `button` | inside advanced mode panel | switches Robot mode to `auto` | `state.mode`, `state.isRunning` | selects mode only; does not start runtime |
| `Track` mode card | `L3` | `button` | inside advanced mode panel | switches Robot mode to `track` | `state.mode`, `state.isRunning`, `state.trackingPoint` for status text | selects mode only; does not start runtime |
| target tap surface | `L3` | `surface` | `state.mode == track` | tap camera view to set target point | `state.mode` | interaction belongs to camera surface, not to settings sheet |
| track overlay | `L3` | `info` | `state.mode == track && state.trackingPoint != null` | shows target box and target status text | `state.trackingPoint`, `state.trackingStatus` | visual confirmation after target selection |
| mode transition feedback | `L3` | `info` | briefly after mode change | transient `DRIVE` / `AUTO` / `TRACK` confirmation | `_transitionMode`, `_showModeLabel`, `_modeFx` | feedback only; no state ownership |

### 2.3 Robot Settings Sheet Controls

These controls are secondary by definition. They must not become the only place where the user discovers blocked readiness.

| Element | Layer | Type | Visible when | Action or meaning | Depends on | Relationship |
| --- | --- | --- | --- | --- | --- | --- |
| settings sheet | `L4` | `sheet` | after either settings button is pressed | secondary runtime configuration | active Robot mode | container for mode-specific secondary settings |
| `Collect data` switch | `L4` | `button` | `state.mode == drive` | toggles data collection while running | `state.collecting`, `state.isRunning` | Drive-only secondary behavior |
| `Controller` picker | `L4` | `button` | `state.mode == drive` | selects `PC`, `Gamepad`, or `Phone` as intended drive controller | `state.driveController` | configuration choice; owner display still belongs to top bar |
| Drive `Speed mode` picker | `L4` | `button` | `state.mode == drive` | selects Drive speed profile | `state.driveSpeedMode` | Drive-only tuning |
| Auto `Model` picker | `L4` | `button` | `state.mode == auto` | picks placeholder Auto model enum | `state.autoModel` | current code uses enum selection instead of real model workflow |
| Auto `Device` picker | `L4` | `button` | `state.mode == auto` | picks Auto compute device | `state.autoDevice` | secondary runtime tuning |
| Auto `Speed mode` picker | `L4` | `button` | `state.mode == auto` | picks Auto speed profile | `state.autoSpeedMode` | secondary runtime tuning |
| Track `Model` picker | `L4` | `button` | `state.mode == track` | picks placeholder Track model enum | `state.trackModel` | current code uses enum selection instead of real model workflow |
| Track `Target type` picker | `L4` | `button` | `state.mode == track` | picks intended target class | `state.trackTargetType` | secondary configuration; target selection itself still belongs on camera surface |
| Track `Device` picker | `L4` | `button` | `state.mode == track` | picks Track compute device | `state.trackDevice` | secondary runtime tuning |
| Track `Speed mode` picker | `L4` | `button` | `state.mode == track` | picks Track speed profile | `state.trackSpeedMode` | secondary runtime tuning |

### 2.4 Robot Relationship Rules

| Parent element | Child element | Correct relationship |
| --- | --- | --- |
| bridge status pill | primary action button | bridge missing should force setup-first primary action |
| owner pill | `Controller` picker | current owner is runtime truth; controller picker is only a secondary configuration input |
| mode pill | advanced mode panel | mode pill reports current mode; advanced panel is the only mode selector on the main surface |
| camera surface | target tap surface | target selection should happen on the live visual surface, not in settings |
| `Next Step` meta box | primary action button | `Next Step` explains the button; it must not become a second button |
| settings buttons | settings sheet | settings must remain secondary to the primary action flow |

### 2.5 Robot Current Architecture Gaps

| Gap | Why it matters |
| --- | --- |
| `RobotCameraState.driveArmed` still exists in state but no longer has a clean visible role in the shell | leftover half-state can reintroduce ambiguous Robot state logic |
| current `Auto` flow has no real `modelMissing` readiness | architecture says `Load Model` should be possible, but current primary action jumps straight to `Start Auto` once USB is connected |
| current `Track` flow checks only target selection, not model readiness | current shell cannot yet represent `Load Model -> Select Target -> Start Tracking` as separate steps |
| settings sheet owns model selection through enums | this hides model workflow in `L4`, which is the wrong layer for a blocked prerequisite |
| there are two settings entry buttons for the same sheet | duplicated access is not fatal, but one entry should eventually become canonical |

## 3. Controller Runtime Matrix

### 3.1 Persistent Controller Elements

| Element | Layer | Type | Visible when | Action or meaning | Depends on | Relationship |
| --- | --- | --- | --- | --- | --- | --- |
| robot-link pill | `L2` | `button` | always in Controller top bar | if linked, disconnect current transport; if not linked, open link chooser | `state.linkBusy`, `controller.bluetoothLinked`, `controller.directUsbConnected` | transport control only; not a mode selector |
| latency pill | `L2` | `tag` | always in Controller top bar | reports latency or `--` | link state and `state.telemetry.latency` | passive transport-health tag |
| layout switcher group | `L2` | `surface` | always in Controller top bar | contains layout buttons | `state.layout` | changes physical control arrangement only |
| `Dual` chip | `L2` | `button` | always in layout switcher | selects `ControlLayout.dual` | `state.layout` | layout only; must not imply controller mode |
| `Arrow` chip | `L2` | `button` | always in layout switcher | selects `ControlLayout.arrow` | `state.layout` | layout only; must not imply controller mode |
| init error pill | `L2` | `tag` | only when `state.initializationError != null` | reports init or link failure | `state.initializationError` | status only; should not mutate state |
| scene background or camera preview | `L2` | `surface` | always | shows camera preview when available, otherwise fallback scene image | `state.showCamera`, `controller.cameraController` | main contextual surface behind control chrome |
| left control cluster | `L2` | `surface` | always | visualizes steering input state | `state.layout`, steering values | current implementation is mainly input visualization, not a mode selector |
| right control cluster | `L2` | `surface` | always | visualizes throttle or stop input state | `state.layout`, throttle and button values | current implementation is mainly input visualization, not a mode selector |

### 3.2 Contextual And Modal Controller Elements

| Element | Layer | Type | Visible when | Action or meaning | Depends on | Relationship |
| --- | --- | --- | --- | --- | --- | --- |
| link chooser sheet | `L4` | `sheet` | robot-link pill pressed while not linked | choose transport type | no active BT or USB link | transport setup, not controller mode |
| `Robot Phone via Bluetooth` tile | `L4` | `button` | inside link chooser sheet | proceeds to bonded-device picker | link chooser open | transport choice only |
| `Direct USB` tile | `L4` | `button` | inside link chooser sheet | starts USB link attempt | link chooser open | transport choice only |
| bonded-device picker sheet | `L4` | `sheet` | after Bluetooth transport chosen | list paired robot phones | `controller.getBondedRobotDevices()` | second stage of Bluetooth link flow |
| bonded-device row | `L4` | `button` | inside bonded-device picker | connect to selected robot phone | bonded devices available | transport choice only |

### 3.3 Controller Relationship Rules

| Parent element | Child element | Correct relationship |
| --- | --- | --- |
| robot-link pill | link chooser sheet | transport setup is a secondary flow owned by the link button |
| robot-link pill | latency pill | link button changes transport; latency pill only reports transport quality |
| layout switcher | left and right control clusters | layout changes arrangement, not command semantics |
| init error pill | robot-link pill | error can describe link failure, but recovery action still belongs to the link button or transport sheet |
| scene background | future AI overlay | overlays may annotate the scene, but must not replace transport or mode ownership text |

### 3.4 Controller Current Architecture Gaps

| Gap | Why it matters |
| --- | --- |
| there is no first-class `driveMode` in `ControlState` | future controller modes would currently get mixed into layout or transport semantics |
| `_ModeSwitcher` is a layout switcher, not a mode switcher | the current naming encourages semantic drift |
| current control clusters mainly mirror gamepad input state and do not provide a generalized touch-input abstraction | future DIY controller panels need input model separation before more layouts are added |
| `showCamera` currently depends on `gamepadConnected && cameraInitialized` | camera visibility is coupled to gamepad presence, which may be wrong once controller modes expand |
| there is no controller-side AI / assist overlay yet | once `driveMode` grows beyond manual, the runtime needs visible ownership cues on top of the scene |

## 4. Cross-Role Relationship Summary

| Question | Correct owner |
| --- | --- |
| Which runtime is active: `Robot` or `Controller`? | shell `role` |
| Which Robot mode is active: `Drive`, `Auto`, or `Track`? | Robot runtime |
| Which controller layout is active: `Dual` or `Arrow`? | Controller runtime |
| Which transport is active: Bluetooth or USB? | Controller runtime transport state |
| Which controller command model is active: `manual`, `autoTracking`, or future modes? | Controller runtime `driveMode` |

## 5. Immediate Implementation Conclusions

1. The current merged app already has the correct shell split: one shell, two runtime roots.
2. The biggest Robot-side logic gap is not visual polish. It is the missing explicit readiness model for `Auto` and `Track`.
3. The biggest Controller-side logic gap is the missing explicit `driveMode` axis separate from layout.
4. Transport, mode, layout, and role are four different layers and must stay separate in code and UI.
5. Any future demo or Flutter refactor should start from this matrix before changing visuals.
