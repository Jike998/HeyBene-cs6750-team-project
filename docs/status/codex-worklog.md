# Codex Worklog

This file is the persistent collaboration log for ongoing work in this repo.
The goal is to make interrupted sessions easy to resume.

## Usage

- Add a new dated entry for each work session.
- Record both what changed and what was learned.
- Prefer concrete file paths, assumptions, blockers, and next actions.
- If a task is interrupted, leave enough context here to restart quickly.

## 2026-04-24 Initial Project Readthrough

### Scope

- Goal for this session: understand the current repo state before deeper collaboration.
- User context: `robot app` and `control app` have already been merged in some form, but many optimizations and changes remain.
- Important constraint: preserve existing uncommitted work in the tree.

### Working Tree Snapshot

- Branch: `main`
- Repo has existing uncommitted and untracked files before this session.
- Notable in-progress paths already present:
  - `apps/control_app/lib/app/fusion_app.dart`
  - `apps/control_app/lib/features/connection/`
  - `apps/control_app/lib/features/telemetry/`
  - multiple design artifacts under `docs/design/controller_app/`

### Repo Structure Summary

- Main active apps:
  - `apps/control_app`
  - `apps/robot_app`
- Supporting docs:
  - `docs/architecture.md`
  - `docs/onboarding.md`
  - `docs/run-modes.md`
  - `docs/migration/openbene-apk-plan.md`
- Planned shared packages:
  - `packages/shared_models`
  - `packages/mock_services`
  - `packages/openbene_bridge`

### Current Runtime Reality

- Repository docs still describe a two-app mainline:
  - `control_app` for controller-side UI
  - `robot_app` for robot-side UI
- Actual `control_app` entry point has changed:
  - [`apps/control_app/lib/main.dart`](c:\Users\jiken\Desktop\openbot-ui\apps\control_app\lib\main.dart) now runs `FusionApp`
- `FusionApp` currently switches between two roles inside one Flutter app:
  - `host` role
  - `controller` role
- `controller` role uses the new `control_app` flow.
- `host` role currently reuses archived robot UI code from:
  - `apps/control_app/lib/legacy/robot_shell/...`

### Important Architecture Observation

The merge is currently real at the app-shell level, but not yet fully real at the shared-domain level.

What appears merged already:

- one installable Flutter app entry on the `control_app` side
- role switch between host and controller
- Android side includes both:
  - controller Bluetooth client bridge
  - robot-side Bluetooth server bridge
  - native gamepad bridge

What still appears separate or duplicated:

- robot-side UI/state in `FusionApp` is still imported from `legacy/robot_shell`
- `robot_app` still exists as a separate active app with similar code
- connection and telemetry models are duplicated across apps
- planned shared packages exist mostly as placeholders, not active shared code

### Control Side Findings

Key files read:

- [`apps/control_app/lib/app/fusion_app.dart`](c:\Users\jiken\Desktop\openbot-ui\apps\control_app\lib\app\fusion_app.dart)
- [`apps/control_app/lib/features/control/state/control_controller.dart`](c:\Users\jiken\Desktop\openbot-ui\apps\control_app\lib\features\control\state\control_controller.dart)
- [`apps/control_app/lib/features/control/state/control_state.dart`](c:\Users\jiken\Desktop\openbot-ui\apps\control_app\lib\features\control\state\control_state.dart)
- [`apps/control_app/lib/services/bluetooth_robot_link_service_adapter.dart`](c:\Users\jiken\Desktop\openbot-ui\apps\control_app\lib\services\bluetooth_robot_link_service_adapter.dart)
- [`apps/control_app/lib/services/openbene_robot_connection_adapter.dart`](c:\Users\jiken\Desktop\openbot-ui\apps\control_app\lib\services\openbene_robot_connection_adapter.dart)
- [`apps/control_app/android/app/src/main/kotlin/com/openbothci/control_app/MainActivity.kt`](c:\Users\jiken\Desktop\openbot-ui\apps\control_app\android\app\src\main\kotlin\com\openbothci\control_app\MainActivity.kt)
- [`apps/control_app/android/app/src/main/kotlin/com/openbothci/control_app/RobotLinkClientBridge.kt`](c:\Users\jiken\Desktop\openbot-ui\apps\control_app\android\app\src\main\kotlin\com\openbothci\control_app\RobotLinkClientBridge.kt)

Observations:

- Controller UI is polished and actively developed.
- Control input pipeline is mostly:
  - native Android gamepad events
  - Flutter controller state/orchestration
  - USB drive commands through the robot connection adapter
- Bluetooth client adapter already exists and supports:
  - bonded device listing
  - connect/disconnect
  - payload send
  - status/error streams
- But current control feature wiring does not appear to consume that Bluetooth link service yet.
- There is a likely temporary mismatch in the top bar:
  - UI label says `BT Link` / `BT Linked`
  - actual state is derived from `usbConnected`
  - `toggleRobotLink()` currently toggles USB, not Bluetooth

### Robot Side Findings

Key files read:

- [`apps/robot_app/lib/app/robot_app.dart`](c:\Users\jiken\Desktop\openbot-ui\apps\robot_app\lib\app\robot_app.dart)
- [`apps/robot_app/lib/app/robot_app_bootstrap.dart`](c:\Users\jiken\Desktop\openbot-ui\apps\robot_app\lib\app\robot_app_bootstrap.dart)
- [`apps/robot_app/lib/features/robot_camera/state/robot_camera_controller.dart`](c:\Users\jiken\Desktop\openbot-ui\apps\robot_app\lib\features\robot_camera\state\robot_camera_controller.dart)
- [`apps/robot_app/lib/features/robot_camera/state/robot_camera_state.dart`](c:\Users\jiken\Desktop\openbot-ui\apps\robot_app\lib\features\robot_camera\state\robot_camera_state.dart)
- [`apps/robot_app/lib/features/robot_camera/presentation/robot_camera_screen.dart`](c:\Users\jiken\Desktop\openbot-ui\apps\robot_app\lib\features\robot_camera\presentation\robot_camera_screen.dart)
- [`apps/robot_app/lib/services/bluetooth_controller_link_service_adapter.dart`](c:\Users\jiken\Desktop\openbot-ui\apps\robot_app\lib\services\bluetooth_controller_link_service_adapter.dart)
- [`apps/robot_app/android/app/src/main/kotlin/com/openbothci/robot_app/PhoneControllerLinkBridge.kt`](c:\Users\jiken\Desktop\openbot-ui\apps\robot_app\android\app\src\main\kotlin\com\openbothci\robot_app\PhoneControllerLinkBridge.kt)

Observations:

- Robot-side app flow is more complete than the repo docs suggest.
- Bluetooth server path is implemented for controller-phone-to-robot-phone communication.
- Robot side periodically sends status packets back to the controller.
- Incoming Bluetooth commands already support:
  - `drive`
  - `stop`
  - `heartbeat`
  - `set_mode`
- Local gamepad on the robot side can override remote phone commands when armed.
- USB robot drive remains the final motor control path.

### Cross-App Gaps

- `packages/shared_models` is not yet used for the duplicated connection/telemetry models.
- `packages/mock_services` is still only planned, not wired into the runtime.
- `packages/openbene_bridge` is still only planned, not the active home of bridge logic.
- Repo docs still describe `legacy/robot_shell` as archive-only, but `FusionApp` actively depends on it.
- This means current documentation and runtime reality are partially out of sync.

### Verification Status

- Readthrough completed for key docs, runtime entry points, controllers, and Android Bluetooth/gamepad bridges.
- Heavy static analysis was attempted with `flutter analyze` but was interrupted before a usable result was captured.
- Several `dart` processes were still visible afterward, so avoid assuming a clean verification state from this session.

### Suggested Near-Term Priorities

1. Decide whether `FusionApp` is now the real mainline direction.
2. If yes, stop treating the host-side code inside `control_app/lib/legacy/robot_shell` as archive and either:
   - promote it into active paths, or
   - extract shared pieces cleanly and reduce duplication with `apps/robot_app`
3. Move duplicated connection/telemetry/protocol models into `packages/shared_models`.
4. Clarify the intended meaning of Bluetooth vs USB in the controller UI and wire the control side accordingly.
5. Add a lightweight session logging rhythm to this file whenever work continues.

### Questions To Confirm With The User

- Is `apps/robot_app` still intended to remain as a separately runnable app long-term, or is `FusionApp` meant to replace it?
- For the merged app, is the primary target one phone with role switching, or still two phones where one acts as controller and one acts as robot host?
- Should `legacy/robot_shell` now be considered temporary active code, or do you want it extracted/refactored out before more features are added?
- Is the controller-side Bluetooth link meant to become the primary remote-control path, with USB kept only for direct local robot connection?

### Resume Notes

If a future session needs to resume quickly, start here:

1. Re-read this file.
2. Check current changes in `git status`.
3. Re-open `FusionApp`, `control_controller.dart`, `robot_camera_controller.dart`, and both Bluetooth bridge adapters.
4. Confirm with the user which app/runtime path is considered the real product direction before large refactors.

## 2026-04-24 Product Direction Confirmed

### User Decisions

- `FusionApp` is the mainline product direction.
- All apps should still remain independently runnable.
- The primary merged target is one phone with in-app role switching.
- The user has not yet made a firm decision on whether the current host-side code under `legacy/robot_shell` should stay there temporarily or be promoted into active paths.

### Meaning Of The Open `legacy/robot_shell` Question

The question is not about behavior first. It is about code ownership and structure.

Right now:

- `FusionApp` is the real active entry point.
- But its host role still imports robot-side logic from:
  - `apps/control_app/lib/legacy/robot_shell`

That creates a mismatch:

- runtime says this code is active
- folder naming and docs say this code is archived

This can confuse future work because teammates may avoid editing code that the app actually depends on.

### Recommended Working Assumption

Until the project is ready for a larger refactor:

- treat `legacy/robot_shell` as temporary active dependency
- do not keep expanding it casually
- prefer new shared logic to go into cleaner active paths
- plan a later extraction/promotion step once the one-phone role-switch flow is more stable

### Next Likely Work Areas

Given the confirmed direction, the most valuable next tasks appear to be:

1. align docs with the new mainline reality around `FusionApp`
2. clarify app boundaries now that all apps remain independently runnable
3. reduce confusing naming around `legacy/robot_shell`
4. start extracting duplicated shared models into `packages/shared_models`
5. fix controller-side Bluetooth vs USB naming/wiring mismatch

## 2026-04-24 Documentation Alignment Pass

### Goal

- Align repo documentation with the confirmed product direction before making larger code changes.

### Confirmed Direction Applied To Docs

- `FusionApp` is the mainline product direction.
- `apps/control_app` is the merged one-phone runtime.
- `apps/robot_app` remains independently runnable as a standalone app.
- `apps/control_app/lib/legacy/robot_shell` is documented as a temporary active dependency instead of pure archive-only code.

### Files Updated

- `README.md`
- `CONTRIBUTING.md`
- `docs/architecture.md`
- `docs/onboarding.md`
- `docs/run-modes.md`
- `apps/control_app/README.md`
- `apps/robot_app/README.md`
- `apps/control_app/lib/legacy/README.md`
- `apps/control_app/lib/legacy/robot_shell/README.md`

### Notes

- This pass changes docs only.
- No runtime behavior was changed.
- Heavy validation was intentionally avoided after the earlier interrupted `flutter analyze` attempt.

## 2026-04-24 Controller Link Wiring Pass

### Goal

- Start resolving the control-side `BT Link` mismatch without relying on long-running verification commands.

### What Changed

- `control_app` bootstrap now initializes the Bluetooth robot-link service during core startup.
- Bluetooth robot-link service no longer requests Bluetooth permission during generic initialization.
- `ControlController` now manages both:
  - Bluetooth robot-phone link
  - direct USB fallback
- Controller-side gamepad output can now route through Bluetooth payloads instead of only local USB.
- Controller listens to robot status packets from the Bluetooth link and maps them into local telemetry/connection state.
- A lightweight heartbeat command is sent over Bluetooth so latency can refresh from echoed status.
- The control top bar no longer pretends Bluetooth is USB.
- Tapping the link pill now opens a connection chooser:
  - `Robot Phone via Bluetooth`
  - `Direct USB`
- The bonded-device picker is now wired into the control flow instead of remaining unused UI.

### Files Updated

- `apps/control_app/lib/app/control_app_bootstrap.dart`
- `apps/control_app/lib/services/bluetooth_robot_link_service_adapter.dart`
- `apps/control_app/lib/features/control/state/control_controller.dart`
- `apps/control_app/lib/features/control/presentation/control_screen.dart`

### Important Notes

- This is still a first-pass integration.
- I intentionally avoided heavy commands like repo-wide `flutter analyze` or `dart format` after repeated hangs.
- Follow-up validation should use short, targeted checks only.

### Remaining Risks

- Internal naming still uses `usbBusy` for the shared link action lock, which is now broader than USB only.
- Bluetooth latency still depends on echoed status timing rather than a dedicated transport abstraction.
- The control screen still uses local camera plumbing; remote video is not part of this pass.

## 2026-04-24 Manual Verification Follow-Up

### Goal

- Continue validating the controller-side BT/USB link pass without using long-running `dart` or `flutter` commands.

### What Was Checked

- Manually re-read the changed controller-side files:
  - `apps/control_app/lib/app/control_app_bootstrap.dart`
  - `apps/control_app/lib/services/bluetooth_robot_link_service_adapter.dart`
  - `apps/control_app/lib/features/control/state/control_controller.dart`
  - `apps/control_app/lib/features/control/presentation/control_screen.dart`
- Cross-checked controller-side Bluetooth status parsing against robot-side status payloads in:
  - `apps/robot_app/lib/features/robot_camera/state/robot_camera_controller.dart`
  - `apps/control_app/lib/legacy/robot_shell/features/robot_camera/state/robot_camera_controller.dart`
- Cross-checked Android Bluetooth client behavior in:
  - `apps/control_app/android/app/src/main/kotlin/com/openbothci/control_app/RobotLinkClientBridge.kt`

### Findings

- No obvious missing-method or stale-call compile issue was found by text inspection.
- Controller-side status key usage appears aligned with robot-side payloads:
  - `type`
  - `usbConnected`
  - `serverRunning`
  - `battery`
  - `latency`
  - `speed`
  - `steering`
  - `echoTs`
- A real connection race was found in the Bluetooth client adapter:
  - native `connect` can return success before the Dart event stream updates `_connected`
  - controller logic checked `linkService.connected` immediately after `connect`
  - this could cause a false failure path on first Bluetooth connect

### Fixes Applied

- Updated `apps/control_app/lib/services/bluetooth_robot_link_service_adapter.dart`
  - when `connect` returns `success: true`, the adapter now immediately updates local:
    - `_connected`
    - `_deviceName`
    - `_deviceAddress`
  - when `connect` fails or `disconnect()` completes, the adapter now also clears local connection state immediately
- Updated `apps/control_app/lib/features/control/state/control_controller.dart`
  - `getBondedRobotDevices()` now clears stale initialization errors when paired devices are successfully found
  - renamed the shared link action lock usage from `usbBusy` to `linkBusy`
- Updated `apps/control_app/lib/features/control/state/control_state.dart`
  - renamed `usbBusy` to `linkBusy` to reflect Bluetooth + USB shared usage
- Updated `apps/control_app/lib/features/control/presentation/control_screen.dart`
  - the top-bar link pill now keys off `state.linkBusy`

### Verification Limits

- I intentionally did not run `dart` or `flutter` validation commands again.
- Even quick commands like `dart --version` / `flutter --version` unexpectedly hung in this environment and were interrupted.
- There are lingering `dart` processes from earlier aborted attempts, so do not assume a clean local tool state.

### Working Rule Going Forward

- Prefer manual inspection, targeted file reads, and very short shell commands.
- Avoid `dart` / `flutter` commands unless the user explicitly wants another attempt and we are ready to cut them off quickly.

### Tooling Process Note

- The user confirmed it was safe to kill leftover toolchain processes.
- I terminated the earlier high-CPU `dart` processes successfully.
- After that, two new low-CPU `dart` processes appeared immediately from:
  - `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe`
- That suggests at least one background tool or watcher is respawning them.
- I stopped short of repeatedly killing the respawned processes to avoid churn without first identifying the parent process.

### Targeted Analyze Result

- The user ran targeted analyze on the edited controller-side files and reported 2 issues:
  - `unnecessary_null_comparison` at `control_controller.dart:67`
  - `avoid_renaming_method_parameters` at `control_controller.dart:132`
- Both issues were fixed locally in:
  - `apps/control_app/lib/features/control/state/control_controller.dart`
- I did not rerun `flutter analyze` myself; waiting on the user's next run result.
- A later user-pasted analyze result still showed the same 2 issues, but the current file on disk no longer matches that output:
  - current line 67 is the `connectionStream.listen(...)` call, not a null comparison
  - current lifecycle override parameter is already named `state`
- That suggests the reported analyze output may have come from a stale snapshot, cached result, or a different working copy.

## 2026-04-24 Product-Definition Discovery Pass

### Goal

- Re-ground the project around current real functionality before discussing final product naming and interaction direction.

### Current Functional Inventory

- `FusionApp` remains the main merged shell in `apps/control_app`.
- It currently exposes two runtime roles:
  - controller role
  - host role
- Current controller-side capabilities discovered:
  - landscape control UI
  - two control layouts: `dual` and `arrow`
  - gamepad input handling
  - camera preview when local camera is available
  - link selection between:
    - direct USB
    - robot phone via Bluetooth
  - bonded-device picker for Bluetooth robot-phone selection
  - top-bar status for:
    - link state
    - latency
  - transport-aware drive sending and stop behavior
- Current robot-side capabilities discovered:
  - setup screen for bridge/server readiness
  - live camera-first runtime
  - swipe mode switching between:
    - `drive`
    - `auto`
    - `track`
  - large start/stop action button
  - settings sheet with:
    - robot USB connection
    - controller Bluetooth/server connection
    - collect-data toggle in drive mode
    - drive controller source selection: `PC` / `Gamepad` / `Phone`
    - speed-mode selection
    - auto model/device/speed selections
    - track model/target/device/speed selections
  - track-mode tap-to-select target point
  - telemetry tray showing:
    - Bluetooth connected
    - USB connected
    - battery
    - latency
    - speed
    - steering
    - mode-dependent metric such as voltage / confidence / distance

### Product Observation

- The controller role already feels closer to a focused product.
- The host role currently mixes two types of functionality:
  - essential robot runtime behavior
  - research/demo-oriented controls inherited from OpenBot-like workflows
- The current name `host` is technically understandable in code but weak as a user-facing role label.

### Next Discussion Themes

- Rename `host` to a user-facing role name that explains purpose immediately.
- Decide which robot-side functions are core product functions versus experimental scaffolding.
- Brainstorm broader interaction patterns instead of limiting the product to the current:
  - mini role toggle
  - swipe mode switcher
  - settings-sheet pattern

## 2026-04-24 Robot State Matrix Draft

### Goal

- Move the product discussion from general ideas into a state-driven interaction draft for the Robot side.

### Output

- Added:
  - `docs/robot-state-matrix.md`

### What The Draft Covers

- default assumption that the app opens into `Robot` mode
- state hierarchy between:
  - global runtime state
  - mode state
- concrete Robot states such as:
  - booting
  - setup needed
  - drive standby / armed / active
  - auto standby / active
  - track standby / active
  - fault / recovery
- what each state should:
  - show
  - hide or demote
  - allow
  - block
- explicit note that Auto / Track need a real model lifecycle instead of being treated as simple toggles

### Intended Use

- use this matrix as the interaction baseline before changing layouts
- use it to compare possible mode-switch patterns later
- use it to drive a separate Auto / Track model-import workflow draft

## 2026-04-24 Robot Spec Refinement Pass

### Goal

- Convert the earlier Robot-side interaction draft into a more implementation-facing spec.
- Reduce overlapping states.
- Separate Auto / Track model lifecycle from generic mode settings.

### Inputs

- Follow-up design discussion with the user
- internal critique that the first draft was strong conceptually but still too wide for direct implementation
- local OpenBot reference code review, especially:
  - `android/robot/src/main/java/org/openbot/tflite/Model.java`
  - `android/robot/src/main/java/org/openbot/modelManagement/ModelManagementFragment.java`
  - `android/robot/src/main/java/org/openbot/common/ControlsFragment.java`
  - `android/robot/src/main/java/org/openbot/utils/FileUtils.java`
  - `android/robot/src/main/java/org/openbot/autopilot/AutopilotFragment.java`

### Outputs

- Rewrote:
  - `docs/robot-state-matrix.md`
- Added:
  - `docs/robot-model-workflow.md`

### Main Changes

- The Robot-side spec now uses orthogonal state dimensions instead of a larger flat named-state list:
  - `systemState`
  - `mode`
  - `runState`
  - `controlOwner`
  - `modeReadiness`
- Removed the earlier standalone `Drive Armed` concept from the default UI spec.
- Clarified that the Robot side is:
  - camera-first
  - single-primary-action
  - safety-first
  - gamepad-first for local control
- Added a primary-action derivation table instead of treating button labels as page-specific decisions.
- Added an event -> next-state transition table for the main Robot runtime flow.
- Split Auto / Track model handling into its own workflow doc.

### OpenBot-Informed Findings Carried Forward

- Original OpenBot does have a real model registry and a dedicated model-management flow.
- It distinguishes asset-backed and file-backed models.
- It copies imported models into app-managed storage.
- It filters models by runtime compatibility before loading them.
- These patterns are worth keeping.
- What should not be copied directly is the old UX pattern where model selection is spread across mode-specific controls and hidden inside technical settings.

## 2026-04-24 Robot Runtime Demo Set

### Goal

- Turn the Robot-side product discussion into concrete low-fidelity interaction artifacts.
- Compare different mode-entry and state-guidance structures before changing Flutter UI.

### Files Added

- `docs/design/robot_app/visible_mode_rail/index.html`
- `docs/design/robot_app/drive_first_advanced/index.html`
- `docs/design/robot_app/workflow_card/index.html`

### Supporting Docs Updated

- `docs/design/robot_app/robot_runtime_demo_notes.md`

### What Each Demo Is Testing

- `visible_mode_rail`
  - keeps `Drive`, `Auto`, and `Track` always visible
  - tests discoverability versus clutter
  - useful for judging whether advanced modes deserve equal shell priority
- `drive_first_advanced`
  - keeps `Drive` visually primary
  - moves `Auto` and `Track` behind a secondary entry
  - tests whether the Robot side should feel more like a focused runtime tool
- `workflow_card`
  - makes the bottom card the dominant interaction pattern
  - stages readiness as explicit tasks
  - tests whether Auto / Track become clearer when framed as workflows instead of mode toggles

### Shared Scenario Coverage

All three demos support the same scenario set:

- setup needed
- drive idle
- drive active
- auto missing model
- auto ready
- track needs target
- fault / recovery

This should make side-by-side discussion easier because the shell changes while the runtime situations stay constant.

### Product Insight Captured

- `Visible Mode Rail` is strongest on capability discoverability.
- `Drive First + Advanced Entry` is strongest on keeping the base runtime disciplined and camera-first.
- `Workflow Card` is strongest on communicating prerequisites and next-step clarity.

At this point the main design question is less "which layout looks nicest" and more:

- do we want Robot to feel like a mode browser
- a focused operating surface
- or a guided staged workflow

### Verification Notes

- No `flutter` or `dart` validation commands were run for this pass.
- Work stayed in static docs and self-contained HTML artifacts to avoid the earlier toolchain hangs.

### Suggested Next Step

- Open the three demos and decide which interaction direction feels most natural as the base for the Robot runtime.
- After that, refine the chosen direction into:
  - role-switch behavior
  - active-state safety rules
  - Auto / Track import and readiness flows

## 2026-04-24 Robot Runtime Baseline Chosen

### Goal

- Stop treating the three low-fidelity demos as equal candidates.
- Choose a working baseline that can drive real UI refactoring.

### Output

- Added:
  - `docs/design/robot_app/robot_runtime_baseline.md`
- Updated:
  - `docs/design/robot_app/robot_runtime_demo_notes.md`

### Baseline Chosen

- base shell:
  - `Drive First + Advanced Entry`
- borrowed behavior:
  - explicit prerequisite staging from `Workflow Card` for `Auto` and `Track`

### Reasoning

- `Visible Mode Rail` is too biased toward discoverability and keeps advanced modes overly prominent.
- pure `Workflow Card` is good for staged tasks, but too heavy as the full-time shell for ordinary `Drive` use.
- the hybrid baseline keeps the product focused while still making blocked advanced states understandable.

### Important Product Rules Captured

- rename user-facing `Host` to `Robot`
- remove the casual `H / C` role-switch interaction from the product surface
- keep `Drive` as the obvious default
- make `Auto` and `Track` deliberate advanced entries
- suppress role/mode switching during active runs unless the user stops first

### Codebase Gaps Noted

- `FusionApp` still uses `host/controller` and the floating mini role switch
- Robot runtime still relies on swipe-based mode switching and a settings-heavy interaction pattern
- Robot state still has prototype-era fields like `driveArmed` and hardcoded model enums

### Suggested Next Step

- Start the implementation-facing pass from shell and role-switch cleanup first.
- Do not start with model import code before the top-level interaction structure is settled.

## 2026-04-24 Fusion Role Entry Cleanup

### Goal

- Start the implementation-facing pass with the lowest-risk product cleanup in the merged app shell.
- Remove the most confusing user-facing part of the current `FusionApp`: the `H / C` role switch and `Host` naming.

### File Updated

- `apps/control_app/lib/app/fusion_app.dart`

### What Changed

- internal role naming was changed from `host/controller` to `robot/controller`
- app title was changed to `Robot Controller`
- the floating `H / C` mini switch was replaced by a readable role picker button
- tapping the role picker now opens a bottom sheet with:
  - `Robot`
  - `Controller`
- leaving the `Robot` role now checks whether the robot is actively running
- if the robot is active, role switching is blocked behind a stop-first confirmation dialog

### Why This Was Worth Doing First

- it removes the least defensible piece of product language immediately
- it aligns the merged app shell with the current design baseline without forcing a large Robot UI refactor yet
- it introduces the first real distinction between:
  - role switching as product navigation
  - mode switching as runtime interaction

### Remaining Gaps

- the actual Robot runtime UI is still the old `legacy/robot_shell` surface
- `Drive / Auto / Track` entry is still not refactored to the new baseline
- the controller side currently allows role switching without additional confirmation because current teardown already stops the controller-side runtime path on disposal

### Verification Notes

- no `flutter` or `dart analyze` command was run in this pass
- this change was checked by direct file inspection only, due the known local toolchain hang risk

## 2026-04-25 Robot Runtime Visual Shell Pass

### Goal

- Get from product baseline to a visible in-app result as quickly as possible.
- Update the merged app's Robot runtime shell before deeper state-model refactors.

### File Updated

- `apps/control_app/lib/legacy/robot_shell/features/robot_camera/presentation/robot_camera_screen.dart`

### What Changed

- removed the old swipe-first mode selector from the main Robot runtime surface
- removed the draggable telemetry tray as the main top interaction
- introduced a new top health bar with:
  - `Robot` label
  - bridge readiness
  - current owner
  - remote link state
  - battery / latency
  - current mode
- introduced a center status card with state-driven copy
- introduced a new bottom runtime shell with:
  - current mode
  - next step
  - one dominant primary action
  - `Advanced Modes` entry
  - settings as a secondary action
- added an advanced mode panel for:
  - `Auto`
  - `Track`
- advanced mode switching is now blocked while active
- returning from advanced mode goes back to `Drive`

### Important Implementation Note

- this pass focuses on visual shell and interaction structure
- it does not fully rework the underlying Auto / Track execution model yet
- `Drive` still uses the existing controller path
- `Auto` / `Track` start-stop behavior is currently visual-state-first in this shell pass so the UI can be exercised before their deeper runtime logic is rebuilt

### Why This Order

- it produces a concrete UI result fast
- it lets us evaluate the shell direction before touching model import and readiness infrastructure
- it reduces the risk of doing large architectural work against the wrong UI structure

### Remaining Gaps

- standalone `apps/robot_app` has not been synced to this new shell yet
- Auto / Track still rely on prototype-era state fields and settings data
- model import / validation is still not wired into the main runtime surface

### Verification Notes

- no `flutter` or `dart analyze` command was run in this pass
- this file was checked by direct inspection only

## 2026-04-25 Controller Check-In Synthesis And Final Prototype

### Goal

- Read the four `Team Project Check In` PDFs.
- Extract controller-relevant design ideas.
- Build the Check-In 4 final controller prototype by extending the existing `mobile_gamer` direction instead of starting over.

### Inputs Reviewed

- `Team Project Check In/Team_Project_Check_In_1.pdf`
- `Team Project Check In/Team_Project_Check_In2.pdf`
- `Team Project Check In/Team_Project_Check_In_3.pdf`
- `Team Project Check In/Team_Project_Check_In_4.pdf`
- existing controller prototypes under:
  - `docs/design/controller_app/mobile_gamer/`
  - `docs/design/controller_app/immersive_fpv/`
  - `docs/design/controller_app/one_handed_casual/`

### Main Findings Captured

- The controller should remain camera-first and feel closer to a mobile driving game than an engineering screen.
- `Mobile Gamer` is the validated default direction.
- The most durable interaction findings across the check-ins were:
  - dynamic steering anchoring
  - explicit mode visibility
  - active brake retention
  - stable top HUD
  - visible AI confirmation on the feed
- `Immersive FPV` and `One-Handed Casual` still have value as optional niche layouts, but not as the default shell.

### Files Added Or Updated

- added `docs/design/controller_app/checkin_design_takeaways.md`
- rebuilt `docs/design/controller_app/final_prototype/index.html`

### Final Prototype Changes

- started from the existing `mobile_gamer` structure and upgraded it into a higher-fidelity final demo
- kept the validated landscape `Mobile Gamer` shell
- preserved:
  - dynamic left-thumb joystick anchoring
  - dedicated gas and brake controls
  - glass HUD overlays
  - stable battery progress bar
- added a clearer Auto Tracking state with visible in-feed confirmation:
  - target box
  - lock card
  - confidence cue
  - tap-to-retarget interaction
- kept the controller camera-first while making the right-side brake larger and more explicit

### Verification

- extracted and reviewed PDF text with `pypdf`
- verified the final prototype page script syntax with local `node`
- checked the final HTML for mojibake artifacts
- attempted headless browser screenshot generation, but local Chrome/Edge crashpad permissions blocked image export in this environment

### Resume Notes

If work resumes later, continue from:

1. open `docs/design/controller_app/final_prototype/index.html`
2. compare the demo against live controller requirements in Flutter
3. decide whether the next pass should focus on:
   - syncing this shell into the Flutter controller UI
   - adding optional alternative controller layouts
   - wiring real video / telemetry / AI state into the prototype

## 2026-04-25 Fusion Interaction Separation Pass

### Goal

- correct the design framing after realizing the previous prototype still blurred Robot logic and Controller logic
- document which findings belong to which side of the merged app
- keep the merged app grounded in the existing two-app implementation base instead of treating it as a greenfield redesign

### What Changed

- updated `docs/design/controller_app/checkin_design_takeaways.md`
  - clarified that the four check-ins mainly validate the `Controller` role
  - explicitly separated controller findings from Robot runtime rules
- added `docs/design/fusion_interaction_logic.md`
  - mapped shared shell responsibilities
  - mapped Robot-specific interaction logic
  - mapped Controller-specific interaction logic
  - tied all three layers back to current code paths in `FusionApp`, `RobotCameraScreen`, and `ControlScreen`
- adjusted `docs/design/controller_app/final_prototype/index.html`
  - clarified top-level semantics in the controller role so `layout` and `drive mode` are not treated as the same thing

### Key Correction Captured

- `Robot` mode logic should come from:
  - `docs/robot-state-matrix.md`
  - `docs/design/robot_app/robot_runtime_baseline.md`
  - `docs/robot-model-workflow.md`
- controller check-in findings should shape:
  - controller layout
  - controller feedback
  - controller mode visibility
  - controller trust cues
- the merged app should keep refining the existing fused shell, not restart from zero

## 2026-04-25 Final Prototype Visual Convergence Pass

### Goal

- continue refining the merged `final_prototype` visual demo
- make it read more like the existing fused app structure
- reduce the feeling that Robot and Controller concerns are all being shown at once

### Main Changes

- simplified the shared shell:
  - removed the large shared top status bar
  - kept only a floating role-switch entry at the app-shell level
- moved status presentation back into each role surface:
  - `Robot` now has its own top health bar
  - `Controller` now has its own top info bar
- reduced duplicate information:
  - Robot bottom action zone no longer repeats owner plus multiple top-level stats
  - Controller bottom dock no longer repeats link state that is already shown in the controller top bar
- removed the extra floating controller assist card
  - AI assistance is now expressed through:
    - the visible target box
    - the state text in the bottom dock
    - the `Manual / Auto Tracking` switch

### Why This Pass Matters

- it brings the demo closer to how `FusionApp` actually works:
  - shared shell for role switching
  - role-specific runtime surfaces underneath
- it makes the prototype easier to compare with current code in:
  - `apps/control_app/lib/app/fusion_app.dart`
  - `apps/control_app/lib/legacy/robot_shell/features/robot_camera/presentation/robot_camera_screen.dart`
  - `apps/control_app/lib/features/control/presentation/control_screen.dart`

### Verification

- final prototype script syntax checked with local `node`
- final prototype DOM id wiring checked with local `node`
- removed stale references from the old shared top-bar structure

## 2026-04-25 Fusion Element Matrix Pass

### Goal

- stop discussing the merged app mainly as a visual prototype
- document the actual logic framework of the current merged app
- make every important button, tag, and surface traceable to a layer, state dependency, and source file

### Files Added

- `docs/design/fusion_ui_element_matrix.md`

### Files Reused As Ground Truth

- `apps/control_app/lib/app/fusion_app.dart`
- `apps/control_app/lib/legacy/robot_shell/features/robot_camera/presentation/robot_camera_screen.dart`
- `apps/control_app/lib/legacy/robot_shell/features/robot_camera/state/robot_camera_state.dart`
- `apps/control_app/lib/features/control/presentation/control_screen.dart`
- `apps/control_app/lib/features/control/state/control_state.dart`
- `apps/control_app/lib/features/control/state/control_controller.dart`
- `docs/design/fusion_ui_architecture.md`
- `docs/design/fusion_interaction_logic.md`

### What The New Matrix Clarifies

- `L0` to `L4` layer ownership
- which elements are:
  - `button`
  - `tag`
  - `info`
  - `surface`
  - `sheet`
- which state each element depends on
- which elements are global shell controls versus Robot-only or Controller-only controls
- which relationships are correct versus currently drifting

### Most Important Architecture Conclusions Captured

- the merged app is already correctly shaped as:
  - one shell
  - two runtime roots
- Robot-side logic still lacks a first-class readiness model for:
  - `Auto`
  - `Track`
- Controller-side logic still lacks a first-class runtime mode axis separate from layout
- transport, role, Robot mode, Controller layout, and future Controller mode must stay separate in both code and UI

### Concrete Gaps Noted

- `RobotCameraState.driveArmed` still exists as leftover state without a clean shell role
- Robot `Auto` currently has no true `modelMissing` state in the active Flutter runtime
- Robot `Track` currently checks target readiness but not model readiness
- Robot settings still hide model choice inside `L4` instead of exposing readiness in the main flow
- Controller `_ModeSwitcher` is really a layout switcher, not a mode switcher
- Controller input chrome is still mostly gamepad-state visualization, not a generalized touch control system
- Controller has no first-class `driveMode`

### Process Notes

- avoided `flutter` and `dart` commands on purpose because of prior hangs
- used direct file inspection and targeted text reads only

### Recommended Next Step

1. turn this matrix into:
   - one Robot event/state transition table tied to current Flutter code
   - one Controller event/state transition table tied to current Flutter code
2. after that, update Flutter screens against the matrix instead of continuing visual-only demo work

## 2026-04-26 robot_app background-and-chrome convergence pass

### Pass Goal

- Move `apps/robot_app` closer to the final visual language implied by the chosen Robot / Controller background art.
- Reduce the mismatch between background mood and foreground controls before starting the next functional refactor.

### Pass Changes

- wired image backgrounds into the standalone runtime:
  - `apps/robot_app/assets/images/robot.png`
  - `apps/robot_app/assets/images/control.png`
- converged Robot and Controller top chrome toward one shared material language:
  - deep blue-gray translucent glass
  - cool blue border treatment
  - colder white text/icons
- removed the controller bottom gray plate that was hurting visibility
- restyled Robot runtime surfaces toward the same family:
  - telemetry tray
  - role switch icon
  - `Info` pill
  - mode rail
  - primary action styling
  - settings launcher and settings sheet shell
- restyled Controller runtime surfaces toward the same family:
  - top info pills
  - layout switcher
  - role button
  - direction cluster
  - stick shells / stick caps
  - `GO / STOP` pedal shells
- reduced several saturated legacy accents so the shell reads more like one system instead of several prototype layers

### Pass Verification

- `flutter analyze apps/robot_app` passed repeatedly during this pass.
- `installDebug` to the connected Android device completed repeatedly during this pass.

### Remaining Visual Gaps In This Pass

- Robot `START / STOP` still carries stronger semantic emphasis than the rest of the shell.
- Robot settings still contains a few legacy accent decisions.
- Controller bottom controls are much closer, but still need final on-device tuning for contrast and weight.

### Product-Logic Gaps Still Separate From This Pass

- Robot still uses equal-weight `AUTO / DRIVE / TRACK` switching.
- Robot still lacks readiness-driven `Load Model / Select Target / Start Auto / Start Tracking` flow.
- Controller still exposes `Dual / Arrow` layout switching instead of converging on one validated default shell.

### Suggested Next Step After This Pass

- Shift from visual convergence into functional interaction work:
  - Robot `Drive First + Advanced Entry`
  - readiness-driven Robot flows
  - controller driving-mode architecture and default-shell convergence

## 2026-04-26 robot camera-like mode rail pass

### Pass Goal

- Preserve Robot swipe-based mode switching while making the bottom interaction feel closer to a phone camera app.
- Reduce how much the mode rail blocks the image while keeping current behavior stable for device testing.

### Pass Changes

- kept the swipe-based `AUTO / DRIVE / TRACK` interaction in `apps/robot_app/lib/features/robot_camera/presentation/robot_camera_screen.dart`
- compressed the bottom stack vertically:
  - smaller gap between mode rail and primary action row
  - slightly smaller primary action button
  - slightly tighter spacing to the settings button
- narrowed and thinned the mode rail:
  - larger side padding
  - lower height
  - less oversized center emphasis
- made the mode text behave more like a camera-style selector:
  - current mode larger and brighter
  - side modes weaker and smaller
  - reduced visual weight so the rail sits over the image more lightly

### Verification

- `flutter analyze apps/robot_app` passed after the pass.
- device install was used to validate the live visual result on Android hardware.

### Remaining Product Question

- whether to keep the current equal-weight mode semantics or move to a `Drive First` semantic model while preserving the same swipe interaction pattern.

## 2026-04-27 robot_app backend phase 1 pass

### Pass Goal

- Start turning `apps/robot_app` into a real replacement runtime instead of a UI-only shell.
- Reuse only the valuable parts of original OpenBot:
  - on-device Android inference wrapper shape
  - model metadata shape
  - tracking control policy
- Avoid copying old OpenBot screens, extra features, and legacy service baggage.

### What Was Confirmed Before Editing

- `apps/robot_app` is the active frontend target.
- `apps/control_app` still contains useful service boundaries and controller/runtime coordination patterns.
- Original OpenBot remains useful mainly for:
  - `Autopilot.java`
  - `Network.java`
  - `Detector.java`
  - `DetectorDefault.java`
  - `MultiBoxTracker.java`
  - `Model.java`
- Original OpenBot should not be ported wholesale because it includes unrelated screens and old platform wiring.

### New Files Added

- `apps/robot_app/lib/services/robot_backend_service.dart`
- `apps/robot_app/lib/services/android_robot_backend_service.dart`

### Updated Files In This Pass

- `apps/robot_app/lib/services/camera_stream_service.dart`
- `apps/robot_app/lib/services/openbene_camera_service_adapter.dart`
- `apps/robot_app/lib/app/robot_app_bootstrap.dart`
- `apps/robot_app/lib/features/robot_camera/state/robot_camera_state.dart`
- `apps/robot_app/lib/features/robot_camera/state/robot_camera_controller.dart`
- `.gitignore`
- `.claude/settings.local.json`

### Backend Phase 1 Progress

- Added a dedicated Flutter-side backend contract for robot autonomy/tracking state.
- Added an Android platform service adapter stub for:
  - backend initialization
  - model listing
  - backend configuration
  - session start/stop
  - tracking point updates
  - camera frame submission
  - backend snapshot streaming
- Split camera service responsibilities into:
  - preview ownership
  - backend frame streaming
- Switched camera image format from JPEG to YUV420 so Android-side frame processing can become real.
- Extended `RobotAppBootstrap` to own the new backend service.
- Extended `RobotCameraState` with backend runtime fields:
  - readiness
  - active state
  - status text
  - processed frame count
  - inference timing
  - fps
  - active model id
  - backend model inventory from Android bridge
- Reworked `RobotCameraController` so mode changes now prepare backend configuration and Auto/Track start/stop is no longer treated as plain UI-only mode flipping.
- Landed Android-side model loading entry in `RobotBackendBridge.kt` with concrete states for:
  - model missing
  - model asset missing
  - model load failed
  - ready
  - active
- Added Android asset-backed model inventory visibility back into Flutter state.
- Downloaded `autopilot_float.tflite` and `ssd_mobilenet_v1_1_metadata.tflite` into `apps/robot_app/android/app/src/main/assets/models/`.
- Added `config.openbot.json` and label assets into `apps/robot_app/android/app/src/main/assets/` for reference and detector metadata.
- Added demo inference outputs to the backend contract:
  - suggested left/right control
  - active detection label
  - active detection score
- Wired backend suggested control values back into robot drive for non-Drive modes.
- Added real frame preprocessing in the Android backend:
  - YUV420 plane decode
  - RGB bitmap creation
  - autopilot crop/scale path
  - detector scale path
  - actual interpreter invocation for demo models
- `flutter analyze` and `app:assembleDebug` both passed after the preprocessing/inference pass.

### Architecture Correction

- The user clarified the intended relationship between the two roles:
  - `Robot` is the primary and required app/runtime that connects to the vehicle.
  - `Controller` is a remote controller running on another phone/tablet, conceptually like a PS/Xbox controller with extra live video/audio support.
- Because of that, the earlier idea of leaning into `controller -> direct USB car control` as a core product path is wrong for the target product.
- The implementation should now treat:
  - `robot phone -> car` as the mainline required path
  - `controller phone -> robot phone` as the mainline remote path
  - direct USB from controller side, if kept, should be treated as fallback/debug path rather than the primary product story
- The same correction applies to wording, settings labels, and future transport decisions.


- Installed `apps/robot_app` debug APK to connected Android device `ACPRVB4223010191`.
- Confirmed `com.openbothci.robot_app/.MainActivity` launches and stays foreground.
- Verified live camera preview appears on device.
- Verified manual switch into `TRACK` mode on device works.
- Verified target tap in `TRACK` mode draws the target box and `Target locked` overlay.
- Verified no new `robot_app` Android runtime crash appeared during this pass.
- `START TRACK` did not transition into active run during device testing because the Robot USB link was not connected on the phone at test time.
- That means the remaining unverified part is the real motor-driving active run, not the UI/backend wiring itself.
- Kept the demo model scope intentionally narrow for presentation quality:
  - one autopilot model
  - one tracking detector model

### Still In Progress

- Android native backend bridge implementation is not finished yet.
- The first Kotlin backend bridge is now attached through `MainActivity`, but it is still a phase-1 stub and not the real OpenBot inference port yet.
- `robot_camera_screen.dart` has been moved toward controller-owned mode and target actions, but the remaining runtime polish is not done.
- Model assets and the real autopilot / detector runtime still need to be landed in `apps/robot_app/android`.

### Verification Status

- Flutter-side phase-1 backend wiring now exists across `robot_app` state, controller, camera service, and Android bridge attachment.
- `flutter analyze` for `apps/robot_app` passed with no issues.
- `gradlew.bat app:assembleDebug` for `apps/robot_app/android` succeeded.
- Build output surfaced one actionable environment note: several Flutter plugins want Android NDK `27.0.12077973`, while the app is still using the lower default NDK. The APK still built successfully, but this should be aligned next.
