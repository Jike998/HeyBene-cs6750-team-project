# Run Modes

This project is being organized so teammates can contribute at different levels of hardware access.

Current runtime note:

- `apps/control_app` is the mainline merged app and supports in-app role switching through `FusionApp`
- `apps/robot_app` remains a separate standalone runtime

## 1. UI-Only Mode

Use this when you are remote or do not have access to the robot hardware.

Typical work:

- layout changes
- visual polish
- navigation and screen flow
- state modeling
- design review

Current note:

- this is the most realistic mode today for teammates who only work on UI
- full mock service plumbing is planned but not fully wired yet

## 2. Integration Mode

Use this when you can run the app locally and exercise some service paths, but not the full hardware stack.

Typical work:

- validating app startup
- validating `FusionApp` role switching
- checking local camera access
- testing state transitions
- verifying adapter boundaries

## 3. Hardware Mode

Use this when the app is connected to the real robot-side or controller-side hardware path.

Typical work:

- USB / bluetooth verification
- real camera / telemetry flow
- live drive testing
- end-to-end validation

This can happen in either of these setups:

- one-phone role switching inside `apps/control_app`
- standalone validation inside `apps/robot_app`

## 4. Planned Mock Mode

The planned long-term goal is to support a true mock mode through `packages/mock_services`.

That package should eventually provide:

- fake telemetry
- fake connection state
- fake robot responses
- safe UI demos for teammates without hardware
