# Robot App Handoff

## Purpose

This document is the current handoff guide for `apps/robot_app`.

It is intended for:
- teammate onboarding
- first-run guidance writing
- UI/logic alignment before device testing
- resuming work after interruptions

Current working baseline:
- branch: `backup/working-tree-20260428-1615`
- active app focus: `apps/robot_app`

## Product Roles

### Robot mode

`Robot` is the source-of-truth runtime.

It owns:
- car hardware connection
- current runtime mode: `Drive / Auto / Track`
- `START / STOP`
- whether video is active
- whether remote control input is accepted
- who currently owns control

### Controller mode

`Controller` is a remote control/view surface.

It owns:
- link selection to the robot phone
- control layout and driving-mode UX
- remote preview display
- remote input sending

It does **not** define the robot's true runtime mode.

## Global Main-Flow Rules

### START gate

`START / STOP` is the single runtime gate for all robot modes:
- `Drive`
- `Auto`
- `Track`

Rules:
- `START` stays visible when the car is not connected
- `START` is disabled until `Car USB` is connected
- video starts only after `START`
- remote control is accepted only after `START`
- `STOP` clears the active runtime

### Control ownership

Control ownership is runtime state, not a settings toggle.

Rules:
- usually there is only one controller device
- if multiple control sources exist, the first source to send valid input takes control
- `Controller` in Robot settings is display-only
- later inputs from another source are rejected until the current run ends or ownership clears

### Video rules

Robot mode:
- before `START`: show background only
- after `START`: show local camera
- after `STOP`: return to background

Controller mode:
- before robot `START`: show background only
- after robot `START` but before first preview frame: show `Video starting`
- after preview frame arrives: show remote preview
- after `STOP`: return to background

## Robot Mode UI Inventory

File:
- `apps/robot_app/lib/features/robot_camera/presentation/robot_camera_screen.dart`

### Camera / background surface

#### Background image
Shown when:
- robot is idle
- camera preview is not active

Purpose:
- standby visual state

#### Local live camera
Shown when:
- robot is running
- camera controller is initialized

Purpose:
- primary robot-side live view

#### Track overlay
Shown when:
- mode is `Track`
- robot is running
- backend has returned a track box

Purpose:
- show the current tracked object location
- box should follow the moving target

## Robot Top Area

### Telemetry tray

Collapsed view shows:
- Bluetooth link state
- USB state
- battery
- `Info / Hide`

Expanded view shows:
- `PING`
- `SPEED`
- `STEERING`
- one mode-specific metric:
  - `Drive` -> `VOLTAGE`
  - `Auto` -> `CONFIDENCE`
  - `Track` -> `DISTANCE`

Additional rows:
- in `Drive` with collection active:
  - `REC`
  - `SESSION`
- in `Auto / Track`:
  - `BACKEND`
  - `INF`
  - `LEFT`
  - `RIGHT`

### Top-right role button

Icon: gamepad

Action:
- switch to `Controller` mode

## Robot Bottom Area

### Mode rail

Current runtime mode selector:
- `AUTO`
- `DRIVE`
- `TRACK`

Action:
- swipe or tap to change robot mode

Mode switching behavior:
- stops current runtime first
- reconfigures backend for the chosen mode

### Main action button

#### Drive
- idle label: `START`
- active label: `STOP`

#### Auto
- idle label: `START AUTO`
- active label: `STOP AUTO`

#### Track
- idle label: `START TRACK`
- active label: `STOP TRACK`

Current behavior:
- if idle and allowed, starts the selected mode
- if active, stops the current mode

Enablement:
- idle start requires `Car USB` connected
- active stop stays enabled

### Settings button

Icon: gear

Action:
- opens Robot settings sheet

## Robot Settings Sheet

### Connection section

#### Car USB
Button: `USB`

Action:
- connect or disconnect robot hardware over USB

Meaning:
- this is the hard precondition for `START`

#### Controller Links

##### Phone Link
Action:
- start or stop the robot-side Bluetooth control link service

Meaning:
- remote controller phone entry point

##### PC Link
Action:
- start or stop the robot-side PC link service

Meaning:
- PC-side remote/debug path

#### PC Status
Shown when:
- PC link port exists

Meaning:
- shows listening or connected client state

#### Car BLE
Current state:
- `Unavailable`

Meaning:
- not implemented in the current flow

### Drive settings

#### Collect data
Shown in:
- `Drive`

Action:
- toggle Drive-only data collection

Meaning:
- used for future training data collection

#### Session
Shown when:
- collection session path exists

Meaning:
- displays current data session path

#### Controller
Shown in:
- `Drive`

Meaning:
- display-only current control owner
- not a selector

Possible values:
- `PC`
- `Gamepad`
- `Phone`
- `None`

#### Speed mode
Options:
- `Low`
- `Normal`
- `High`

Meaning:
- current drive output / speed profile

### Auto settings

#### Model
Current behavior:
- shows the selected Auto model label
- runtime currently resolves to the active Auto backend model

#### Device
Options:
- `CPU`
- `GPU`
- `NNAPI`

Meaning:
- compute placement

#### Speed mode
Meaning:
- Auto speed profile

### Track settings

#### Model
Meaning:
- track/detector model selection

#### Target type
Current options:
- `Person`
- `Dog`
- `Cat`
- `Bicycle`
- `Car`
- `Banana`

Meaning:
- choose which object class Track should automatically detect and follow

Important:
- this is the Track primary input now
- Track no longer depends on tapping the screen to pick a location

#### Device
Meaning:
- Track compute placement

#### Speed mode
Meaning:
- Track runtime speed profile

## Track Mode Definition

Track now means:
- choose a detector model
- choose a target category
- press `START TRACK`
- backend automatically detects supported objects of that category
- backend returns a live tracking box
- overlay follows the moving object

Track no longer means:
- tap the screen to set a manual target point

## Controller Mode UI Inventory

File:
- `apps/robot_app/lib/features/control/presentation/control_screen.dart`

### Main surface states

#### Background
Shown when:
- no robot link
- or robot not started
- or no preview yet and video not starting

#### Video starting
Shown when:
- robot is started
- video is enabled
- preview has not delivered the first frame yet

#### Remote preview
Shown when:
- robot status says video is enabled
- remote preview bytes are present

## Controller Top Area

### Link pill
Possible labels:
- `BT Linked`
- `USB Linked`
- `Robot Link`

Action:
- if Bluetooth linked -> disconnect Bluetooth link
- if USB linked -> disconnect USB link
- if neither linked -> open link type chooser

### Latency pill
Shows:
- round-trip latency in ms when linked
- `--` otherwise

### Layout pill
Shows:
- current controller layout label

Meaning:
- controller-only layout state

### Tune button
Action:
- open Controller Settings

### Robot icon button
Action:
- switch back to Robot mode

### Driving Mode switcher
Current options:
- `Manual`
- `Auto`

Meaning:
- controller-side driving mode UX only
- does not redefine robot runtime mode

## Controller Link Flow

### Link type chooser
Options:
- `Robot Phone via Bluetooth`
- `Direct USB`

Meaning:
- Bluetooth is the primary remote path
- USB is fallback/debug

### Bonded robot picker
Purpose:
- choose a paired robot phone for Bluetooth connection

## Controller Settings

### Driving Mode
Action:
- switch controller-side driving mode

### Layout
Current options:
- `Dual`
- `Arrow`
- `One Hand`

Meaning:
- controller-only shell preset
- does not change robot runtime mode

### Control Position
Purpose:
- fine-tune control layout positions
- saved per driving mode and layout

## Controller Input Surfaces

### Dual layout
Left:
- steering pad

Right:
- throttle/brake pad

### Arrow layout
Left:
- directional steering cluster

Right:
- pedal cluster

### One Hand layout
- single joystick surface for portrait use

All controller input surfaces:
- update local control visuals
- compute left/right drive values
- send over the active transport
- for Bluetooth, actual authority still comes from robot-side ownership state

## Current Implementation Notes

### Track compatibility leftovers
The old `trackingTargetConfigured` and `setTrackingPoint` path still exist inside the Android backend bridge for compatibility, but they are no longer part of the intended Track main flow.

### Current branch baseline
Work should continue from:
- `backup/working-tree-20260428-1615`

### Main files to re-open first
- `apps/robot_app/lib/features/robot_camera/presentation/robot_camera_screen.dart`
- `apps/robot_app/lib/features/robot_camera/state/robot_camera_controller.dart`
- `apps/robot_app/lib/features/robot_camera/state/robot_camera_state.dart`
- `apps/robot_app/lib/features/control/presentation/control_screen.dart`
- `apps/robot_app/lib/features/control/state/control_controller.dart`
- `apps/robot_app/lib/features/control/state/control_state.dart`
- `apps/robot_app/android/app/src/main/kotlin/com/openbothci/robot_app/RobotBackendBridge.kt`
- `apps/robot_app/lib/services/robot_backend_service.dart`

## Suggested Next Uses Of This Document

Use this document as the source for:
- first-run onboarding copy
- teammate handoff
- manual test cases
- UI/logic review checklists
- future cleanup of compatibility leftovers
