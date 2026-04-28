# Robot Model Workflow

Draft workflow for Auto / Track model import, validation, selection, and runtime use in `Robot Controller`.

This document exists because `Auto` and `Track` should not be treated as simple mode toggles.

## Why This Needs Its Own Workflow

`Drive` can usually run as soon as the robot bridge is healthy.

`Auto` and `Track` cannot.

They depend on model availability and runtime readiness, so the product needs a visible lifecycle for models:

1. import or choose
2. validate
3. mark ready
4. run
5. fail or recover
6. replace or remove

If this lifecycle stays hidden behind random settings controls, the UI will keep feeling confusing.

## OpenBot Reference Findings

From the local OpenBot reference sources:

- `android/robot/src/main/java/org/openbot/tflite/Model.java`
- `android/robot/src/main/java/org/openbot/modelManagement/ModelManagementFragment.java`
- `android/robot/src/main/java/org/openbot/common/ControlsFragment.java`
- `android/robot/src/main/java/org/openbot/utils/FileUtils.java`
- `android/robot/src/main/java/org/openbot/autopilot/AutopilotFragment.java`

Observed patterns:

1. OpenBot keeps a real model registry, not just a spinner of hardcoded names.
2. A model includes metadata such as:
   - class
   - type
   - display name
   - path type
   - path
   - input size
3. OpenBot has a separate model-management screen.
4. It imports files from storage with `ACTION_OPEN_DOCUMENT`.
5. Imported models are copied into app-managed storage.
6. Runtime screens filter available models by type and then load them into TFLite interpreters.
7. Runtime configuration also includes device and thread settings.

## What To Keep From OpenBot

- a real model registry
- a distinction between bundled assets and imported files
- copying imported models into app-managed storage
- metadata per model
- runtime filtering by compatibility instead of showing every model everywhere

## What Not To Copy Directly

- model selection hidden inside mode settings as if it were a minor option
- mode pages that assume the user already knows which model is runnable
- exposing technical model details before the user can even start the flow
- spreading model management logic across too many screens

## Proposed Product Direction

`Robot Controller` should treat models as a shared subsystem with one workflow and mode-specific readiness rules.

### Shared Workflow States

| Model Workflow State | Meaning |
| --- | --- |
| `empty` | No compatible model is ready for the current mode |
| `importing` | The user is choosing or copying a model |
| `validating` | The app is checking compatibility and metadata |
| `ready` | A compatible model is available and can be used |
| `active` | The model is currently backing an active Auto or Track runtime |
| `failed` | Import or validation failed and needs recovery |

## Required Model Metadata

The product should track a metadata shape close to OpenBot, but simplified for product use.

Recommended fields:

- `id`
- `displayName`
- `sourceType`
  - `asset`
  - `file`
  - future:
    - `remote`
- `storagePath`
- `modeCompatibility`
  - `auto`
  - `track`
  - future:
    - `both`
- `taskType`
  - `cmdnav`
  - `detector`
  - `goalnav`
- `inputSize`
- `validationStatus`
  - `unknown`
  - `valid`
  - `invalid`
- `validationMessage`
- `lastUsedAt`

## Mode-Specific Readiness

### Auto

Auto becomes runnable when:

- robot global setup is healthy
- a compatible Auto model exists
- the selected model passed validation

Auto does not need target selection.

### Track

Track becomes runnable when:

- robot global setup is healthy
- a compatible Track model exists
- the selected model passed validation
- a target has been selected or locked

Track therefore has one extra readiness step beyond Auto.

## Proposed User Flow

### Auto

1. User enters `Auto`
2. If no valid model exists, primary action becomes `Load Model`
3. User chooses a source:
   - bundled model
   - import from device
   - future: sync from remote source
4. App imports and validates
5. If valid, state becomes `ready`
6. Primary action becomes `Start Auto`

### Track

1. User enters `Track`
2. If no valid model exists, primary action becomes `Load Model`
3. After model validation succeeds, primary action becomes `Select Target`
4. User selects target on the camera surface
5. State becomes `ready`
6. Primary action becomes `Start Tracking`

## Import Flow

### Step 1: Choose Source

Recommended source sheet:

- `Bundled Models`
- `Import From Device`
- future:
  - `Sync From Robot Library`

### Step 2: Copy Into App Storage

If the source is external storage:

- copy the file into app-managed storage
- assign or preserve a display name
- register metadata

The product should avoid referencing arbitrary external paths at runtime when possible.

### Step 3: Validate

Validation should produce a user-visible result, not just a silent failure.

Validation outputs:

- compatible / incompatible
- mode compatibility
- input size
- any blocking reason

### Step 4: Confirm Ready State

Once validation passes, the UI should show:

- current active model
- source type
- compatibility badge
- last-used hint if useful

This is the moment where `Load Model` turns into `Start Auto` or `Select Target`.

## Failure Handling

Failures should resolve into clear next actions:

| Failure | Recommended Action |
| --- | --- |
| file copy failed | `Try Again` |
| unsupported file or metadata | `Choose Another Model` |
| incompatible mode | `Switch Model` |
| runtime creation failed | `Reload Model` |

The app should not leave the user in a fake-ready state after a failed load.

## UI Placement

### Main Flow

The main mode screen should only show what affects the next step:

- current model status
- one primary action
- short reason if blocked

### Secondary Flow

Advanced model management can live in a secondary surface:

- model browser
- metadata view
- remove / replace
- bundled vs imported list

This keeps the main Robot flow clean while still supporting power users.

## Recommended First Product Version

For the first practical version:

- support bundled models
- support import from device
- validate before marking ready
- keep one active model per mode
- do not expose thread count or low-level runtime tuning in the main flow

## Open Questions

- Should the first product version ship with one bundled Auto model and one bundled Track model?
- Should Track target selection happen before pressing `Start Tracking`, or should pressing start enter a target-selection phase?
- Should model removal be possible from the main mode surface, or only from advanced management?

## Suggested Next Step

Use this workflow with `docs/robot-state-matrix.md` to build:

1. low-fidelity Auto screens
2. low-fidelity Track screens
3. a future Flutter-side model registry API
