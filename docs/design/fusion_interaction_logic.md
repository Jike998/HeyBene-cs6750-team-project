# Fusion Interaction Logic

This document separates the interaction logic for the merged app into three layers:

1. shared fusion shell
2. `Robot` role logic
3. `Controller` role logic

The goal is to prevent two recurring mistakes:

- using controller research conclusions to drive Robot runtime structure
- treating the merged app as a greenfield redesign instead of a fusion of two already-working app directions

## Existing Basis

The merged app already has a concrete implementation basis:

- fusion shell:
  - `apps/control_app/lib/app/fusion_app.dart`
- robot runtime:
  - `apps/control_app/lib/legacy/robot_shell/features/robot_camera/presentation/robot_camera_screen.dart`
- controller runtime:
  - `apps/control_app/lib/features/control/presentation/control_screen.dart`

So the correct direction is:

- refine and align the current merged structure
- not restart the product model from zero

## 1. Shared Fusion Shell

This layer is responsible only for app-level concerns.

### Shared responsibilities

- app opens directly into `Robot`
- no landing page
- role switch lives in the shell, not inside either runtime surface
- switching away from active Robot runtime is guarded by stop-first confirmation
- each role keeps its own internal interaction model

### Shared shell state

| State | Meaning |
| --- | --- |
| `role` | `robot` or `controller` |
| `roleSwitchBusy` | guard against repeated switch actions |
| `pendingRole` | temporary state while a stop-first switch is being confirmed |

### Shared shell rule

Role switching is navigation.
Mode switching is runtime behavior.
These are different layers and should not be mixed.

## 2. Robot Role Logic

Robot logic should come from the Robot-side specs already written in this repo, not from the controller check-ins.

### Robot interaction stance

- camera-first
- `Drive` first
- safety-first
- single dominant primary action
- `Auto` and `Track` behind advanced entry

### Robot state model

Use the dimensions already defined in `docs/robot-state-matrix.md`:

- `systemState`
- `mode`
- `runState`
- `controlOwner`
- `modeReadiness`

### Robot primary flow

1. app enters `Robot`
2. default mode is `Drive`
3. if setup is incomplete, show setup blocker and one next step
4. if healthy and idle, show one dominant action
5. advanced modes are explicit, secondary choices

### Robot-specific responsibilities

- USB / bridge readiness
- active runtime state
- control ownership
- model import / selection for `Auto` and `Track`
- target selection for `Track`
- recovery after bridge loss or runtime failure

### Robot-specific actions

- `Connect Robot`
- `Start`
- `Stop`
- `Load Model`
- `Select Target`
- `Start Auto`
- `Stop Auto`
- `Start Tracking`
- `Stop Tracking`
- `Recover`

## 3. Controller Role Logic

Controller logic is where the four check-ins apply most directly.

### Controller interaction stance

- camera-first
- mobile-game feel instead of debug-tool feel
- default `Mobile Gamer` layout
- explicit mode visibility
- active brake always available

### Controller state model

Controller needs its own state dimensions, separate from Robot mode:

| Dimension | Values | Meaning |
| --- | --- | --- |
| `transportState` | `disconnected`, `connecting`, `linked` | Link to robot phone or direct robot path |
| `controllerLayout` | `mobileGamer`, `oneHanded`, future presets | Control surface preset |
| `driveMode` | `manual`, `autoTracking`, future controller modes | What the controller is currently commanding |
| `inputState` | `idle`, `steering`, `throttle`, `braking`, `combined` | Current touch activity |
| `feedbackState` | `normal`, `aiVisible`, `linkWarning` | What supporting feedback needs emphasis |

### Controller-specific responsibilities

- transport selection and link status
- touch input ergonomics
- on-screen control layout
- showing `Manual` versus `Auto Tracking`
- visible AI trust cues on the feed
- emergency brake override behavior

### Controller-specific rules

- `controllerLayout` is not the same thing as Robot mode
- future controller modes can be added without changing Robot runtime logic
- the default preset should stay `Mobile Gamer`
- experimental layouts belong behind controller-specific layout selection, not mixed into Robot mode selection

### Controller layout rule

The merged app may support multiple controller layouts later, but:

- `Mobile Gamer` stays default
- new controller modes are controller-only presets
- they should not affect Robot-side `Drive / Auto / Track` semantics

## Final Prototype Implication

The final merged prototype should therefore show:

### Shared shell

- default `Robot`
- role switch entry
- stop-first guard

### Robot role

- `Drive` first
- advanced entry for `Auto` and `Track`
- staged model / target readiness

### Controller role

- validated `Mobile Gamer` default
- visible `Manual` / `Auto Tracking`
- cleaner HUD hierarchy
- space to extend controller presets later

## Recommended Implementation Order

1. Keep `FusionApp` as the top-level shell and continue refining it.
2. Refine Robot runtime according to the Robot state matrix, not controller check-in results.
3. Refine Controller runtime according to the check-in results.
4. Add future controller presets as controller-only layout options after the default shell is stable.
