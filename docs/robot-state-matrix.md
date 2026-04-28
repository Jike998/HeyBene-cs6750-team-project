# Robot State Matrix

Implementation-facing draft for the `Robot` side of `Robot Controller`.

This version is intentionally more constrained than the first draft.
It keeps the earlier safety-first principles, but rewrites the state model so it can map more cleanly to implementation.

## Product Stance

- `Robot Controller` is the working product name direction.
- The app opens into `Robot` mode by default.
- There is no landing page.
- Role switching stays inside the app, but it must not feel like a casual tab change.
- The `Robot` side is:
  - camera-first
  - single-primary-action
  - safety-first
  - gamepad-first for local control
- Local gamepad is the default highest-priority control source.
- Remote phone and PC are valid control owners, but they are not equal-priority with local gamepad.

## Canonical Shell

The `Robot` side should keep a stable 3-part shell:

1. Top health bar
   - role label: `Robot`
   - robot bridge status
   - current control owner
   - battery
   - latency when meaningful
   - current mode
   - role-switch entry
2. Camera surface
   - always the dominant middle layer
   - can host overlays such as target selection or lock feedback
3. Bottom primary action zone
   - exactly one dominant action at a time
   - examples:
     - `Connect Robot`
     - `Start`
     - `Stop`
     - `Load Model`
     - `Select Target`
     - `Recover`

Everything else should be secondary:

- settings
- advanced model options
- debug details
- data collection

## Design Rules

1. Safety state overrides mode state.
2. Only one primary action may be dominant at a time.
3. The user must always know:
   - whether the robot bridge is connected
   - whether the robot is actively running
   - who currently owns control
   - whether the selected mode is runnable
4. Mode settings should appear only when the active mode needs them.
5. Advanced options should stay out of the main flow until prerequisites are satisfied.
6. Every fault should point to a recovery action, not just an error label.

## Orthogonal State Dimensions

Instead of encoding every UI situation as a separate named state, the `Robot` side should be described with a small set of dimensions.

| Dimension | Values | Meaning |
| --- | --- | --- |
| `systemState` | `booting`, `setupNeeded`, `ready`, `fault` | Global runtime health |
| `mode` | `drive`, `auto`, `track` | Active operating mode |
| `runState` | `idle`, `active` | Whether the selected mode is currently running |
| `controlOwner` | `none`, `localGamepad`, `remotePhone`, `pc` | Current winning control source |
| `modeReadiness` | `ready`, `modelMissing`, `targetMissing` | Whether the selected mode can run |

### Notes

- `systemState` is global and overrides all other dimensions.
- `runState` only matters when `systemState == ready`.
- `modeReadiness` is derived from the active mode:
  - `drive` normally uses `ready`
  - `auto` uses `modelMissing` or `ready`
  - `track` uses `modelMissing`, `targetMissing`, or `ready`
- This spec removes the previous standalone `Drive Armed` state.

If the hardware layer later introduces a real, safety-relevant arming stage, it should be added as an explicit safety mechanism, not kept as an ambiguous UI half-state.

## State Resolution Order

The UI should resolve state in this order:

1. `systemState == fault`
2. `systemState == setupNeeded`
3. `systemState == booting`
4. `systemState == ready`
   then use:
   - `mode`
   - `runState`
   - `controlOwner`
   - `modeReadiness`

That means:

- broken robot bridge beats normal mode UI
- startup beats normal mode UI
- mode UI only matters once the system is globally healthy

## Control Ownership Rules

Control ownership must be explicit and singular.

Priority order:

1. `localGamepad`
2. `remotePhone`
3. `pc`
4. `none`

Rules:

- The top bar should show only the winning owner, not multiple owners as if they were equal.
- If local gamepad is active, remote phone should be shown as connected but not owning control.
- If no source currently owns control, the UI should say so clearly.
- Changing control owner while `runState == active` should be treated as a controlled handoff, not a silent switch.

## Primary Action Derivation

The bottom primary action should be derived from the current state, not hand-authored screen by screen.

| Conditions | Primary Action | Enabled | Notes |
| --- | --- | --- | --- |
| `systemState == booting` | `Starting...` | no | Pure progress state |
| `systemState == fault` | `Recover` | yes | Leads into recovery flow |
| `systemState == setupNeeded` and robot bridge missing | `Connect Robot` | yes | Highest setup priority |
| `systemState == setupNeeded` and camera/permission issue blocks operation | `Fix Setup` | yes | Recovery-first wording |
| `systemState == ready` and `mode == drive` and `runState == idle` | `Start` | yes | Default safe idle action |
| `systemState == ready` and `mode == drive` and `runState == active` | `Stop` | yes | Strongest visible action |
| `systemState == ready` and `mode == auto` and `modeReadiness == modelMissing` | `Load Model` | yes | Auto cannot start yet |
| `systemState == ready` and `mode == auto` and `modeReadiness == ready` and `runState == idle` | `Start Auto` | yes | Prefer explicit verb |
| `systemState == ready` and `mode == auto` and `runState == active` | `Stop Auto` | yes | Keep mode-specific stop label if desired |
| `systemState == ready` and `mode == track` and `modeReadiness == modelMissing` | `Load Model` | yes | Track cannot start yet |
| `systemState == ready` and `mode == track` and `modeReadiness == targetMissing` | `Select Target` | yes | Track-specific prerequisite |
| `systemState == ready` and `mode == track` and `modeReadiness == ready` and `runState == idle` | `Start Tracking` | yes | Prefer explicit verb |
| `systemState == ready` and `mode == track` and `runState == active` | `Stop Tracking` | yes | Strong stop action |

### Action Naming Rule

`Drive` may keep the plain `Start` / `Stop` labels.

`Auto` and `Track` should prefer explicit verbs:

- `Start Auto`
- `Stop Auto`
- `Start Tracking`
- `Stop Tracking`

That keeps button meaning stable and avoids overloading the word `Start`.

## Visibility Rules

### Always visible in healthy runtime

- role label
- robot bridge health
- current control owner
- battery
- latency when meaningful
- current mode label
- one primary action

### Always hidden from the main layer

- raw engineering detail
- thread counts
- low-level inference parameters
- model internals that do not affect the next user decision

### Visible only when relevant

- collect-data toggle
  only if retained in `Drive`
- model selection and runtime-device controls
  only in `Auto` or `Track`
- target overlay
  only in `Track`
- recovery explanation
  only in `fault` or `setupNeeded`

## Global Runtime States

### G0 Booting

Meaning:

- services are still starting
- camera, bridge, or controller link entry points may not be initialized yet

Show:

- role label
- startup progress or status text
- placeholder health bar
- disabled primary action: `Starting...`

Hide or demote:

- mode switching
- advanced settings
- model controls
- target selection

Allowed:

- passive waiting
- minimal diagnostics only if boot hangs

Blocked:

- starting any mode
- changing control owner
- role switch

### G1 Setup Needed

Meaning:

- the system is not globally healthy enough to enter normal runtime

Typical causes:

- robot bridge disconnected
- blocking permission issue
- camera unavailable in a way that prevents the current product flow

Show:

- one concise reason
- one next-step action
- setup helpers related to the missing prerequisite

Hide or demote:

- mode-specific advanced settings
- mode start actions
- target selection

Allowed:

- complete setup
- inspect concise status

Blocked:

- starting Drive, Auto, or Track
- role switch if it would hide the unresolved setup issue

### G2 Ready

Meaning:

- global prerequisites are healthy
- normal mode UI may now drive the screen

Show:

- full camera-first shell
- mode entry
- concise telemetry
- one derived primary action

### G3 Fault

Meaning:

- a safety-relevant or flow-breaking issue occurred after the system was otherwise healthy

Typical causes:

- robot bridge loss
- active run interrupted
- model load or runtime failure
- camera failure during operation

Show:

- explicit fault title
- short reason
- safe-state confirmation
- one recovery action

Hide or demote:

- normal mode controls
- advanced settings unrelated to recovery

Blocked:

- any run action until recovery succeeds

## Mode Rules Inside `systemState == ready`

### Drive

Purpose:

- primary robot runtime
- lowest-friction operating mode

Default assumptions:

- local gamepad is preferred when available
- remote phone can take over when local gamepad is absent or intentionally ceded

Drive idle:

- primary action: `Start`
- visible:
  - control owner
  - battery
  - latency if remote
  - compact motion telemetry
- secondary:
  - speed mode
  - optional collect-data toggle

Drive active:

- primary action: `Stop`
- strongest visual emphasis on stopping and connection health
- blocked:
  - role switch
  - mode switch
  - connection reconfiguration

### Auto

Purpose:

- autonomous policy runtime

Auto idle with missing model:

- primary action: `Load Model`
- show only the reason Auto cannot start

Auto idle and ready:

- primary action: `Start Auto`
- secondary:
  - selected model
  - runtime device
  - speed mode

Auto active:

- primary action: `Stop Auto`
- block model replacement and device changes while active

### Track

Purpose:

- object or target following runtime

Track idle with missing model:

- primary action: `Load Model`

Track idle with model ready but no target:

- primary action: `Select Target`
- show the camera surface as the targeting surface

Track idle and ready:

- primary action: `Start Tracking`

Track active:

- primary action: `Stop Tracking`
- show target lock state, confidence, and distance
- block model replacement and target-type changes while active

## Event -> State Transition Table

This is the first implementation-facing transition table.
It is intentionally small and focused on the primary flow.

| Current Conditions | Event | Next Conditions | Primary Action After Transition | Notes |
| --- | --- | --- | --- | --- |
| `booting` | startup complete and prerequisites healthy | `ready + drive + idle + none + ready` | `Start` | Default landing runtime |
| `booting` | startup complete but prerequisites missing | `setupNeeded + drive + idle + none + ready` | `Connect Robot` or `Fix Setup` | Setup blocks normal runtime |
| `setupNeeded` | robot bridge connected and no other blockers remain | `ready + drive + idle + none + ready` | `Start` | Safe standby |
| `ready + any mode + any runState` | robot bridge lost | `fault + same mode + idle` | `Recover` | Safety override |
| `ready + drive + idle` | primary action pressed | `ready + drive + active + highestAvailableOwner + ready` | `Stop` | Start drive |
| `ready + drive + active` | stop pressed or safe-stop required | `ready + drive + idle + currentOwner + ready` | `Start` | Remain in Drive |
| `ready + any mode + active` | role switch requested | `ready + same mode + idle` then switch allowed | `Start` or mode-specific idle action | Stop first, then switch |
| `ready + drive + idle` | mode changed to `auto` and no model ready | `ready + auto + idle + currentOwner + modelMissing` | `Load Model` | Auto standby |
| `ready + auto + idle + modelMissing` | model loaded and validated | `ready + auto + idle + currentOwner + ready` | `Start Auto` | Auto is now runnable |
| `ready + auto + idle + ready` | primary action pressed | `ready + auto + active + currentOwner + ready` | `Stop Auto` | Start auto runtime |
| `ready + auto + active` | stop pressed | `ready + auto + idle + currentOwner + ready` | `Start Auto` | Return to Auto standby |
| `ready + drive + idle` | mode changed to `track` and no model ready | `ready + track + idle + currentOwner + modelMissing` | `Load Model` | Track standby |
| `ready + track + idle + modelMissing` | model loaded and validated | `ready + track + idle + currentOwner + targetMissing` | `Select Target` | One more prerequisite remains |
| `ready + track + idle + targetMissing` | target selected | `ready + track + idle + currentOwner + ready` | `Start Tracking` | Track is now runnable |
| `ready + track + idle + ready` | primary action pressed | `ready + track + active + currentOwner + ready` | `Stop Tracking` | Start tracking runtime |
| `ready + track + active` | stop pressed | `ready + track + idle + currentOwner + ready` | `Start Tracking` | Return to Track standby |
| `fault` | recovery succeeds but setup still incomplete | `setupNeeded + drive + idle + none + ready` | `Connect Robot` or `Fix Setup` | Fall back to setup |
| `fault` | recovery succeeds and setup is healthy | `ready + drive + idle + none + ready` | `Start` | Safe return to default runtime |

## Role Switch Rules

- Role switch entry stays visible in the top bar.
- It should not look like a tab bar.
- If `runState == active`, role switch becomes a guarded flow:
  - safe-stop first
  - then allow switching
- Role switch should not silently preserve an unsafe active runtime.

## Advanced Feature Placement

These should not dominate the first product-facing Robot flow:

- data collection
- model metadata editing
- runtime thread count
- engineering tuning
- multi-source model synchronization

They may still exist, but they should live behind a secondary settings or advanced path.

## Open Questions

- Should `Auto` and `Track` appear in the same visible mode switch as `Drive`, or in a secondary mode entry?
- Should controller-link status always be shown in the top bar, or only when remote control is available?
- Should `Select Target` be a one-step camera tap flow, or enter a temporary targeting sub-mode?
- Which Drive-era research features deserve to survive the first product version?

## Suggested Next Step

Use this file together with a separate model workflow spec to produce:

1. low-fidelity Robot interaction demos
2. mode-switch comparison demos
3. implementation tasks for the Flutter state layer
