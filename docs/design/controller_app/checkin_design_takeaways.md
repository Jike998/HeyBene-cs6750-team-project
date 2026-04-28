# Controller Check-In Design Takeaways

This note condenses the four course check-ins into controller-side design guidance.

Important scope note:

- these check-ins mainly validate the `Controller` role, not the `Robot` runtime
- they should not be copied wholesale onto the Robot side
- in the merged app, these findings inform the `Controller` role inside `FusionApp`

## Check-In 1: Reframe The Product

- The current OpenBot controller feels like an engineering debug screen, not a phone-native driving tool.
- A direct "physical gamepad pasted onto a touchscreen" translation is the wrong baseline.
- The redesign target should feel closer to a mobile driving game:
  - clear camera-first focus
  - simpler runtime information
  - obvious mode switching

## Check-In 2: Needfinding Signals

- Live video and responsiveness matter more than exposing technical parameters.
- The camera feed should remain the visual center of the controller.
- Two-thumb control is the dominant mental model, but touchscreen thumb drift is a real problem.
- The default layout should compensate for the tactile gap with:
  - forgiving touch targets
  - dynamic anchoring
  - immediate visual and haptic feedback
- Manual versus Auto mode switching must be impossible to miss.
- Current mode should remain visible at all times, not buried in menus.

## Check-In 3: Prototype Method Lessons

- Functional web prototypes were the right fidelity for this problem because touch behavior and motion input cannot be judged from static mockups.
- Wizard-of-Oz simulation is acceptable at this stage as long as the interaction loop feels real.
- The evaluation focus was correct:
  - steering confidence
  - confidence in finger placement
  - clarity of mode status

## Check-In 4: What Actually Won

- `Mobile Gamer` was the clear winner and should be the default controller shell.
- Active braking beat passive release-to-stop.
- Decoupled steering and speed control beat single-thumb combined gestures.
- Stable visible UI beat hidden minimal UI.
- The high-value refinements validated in testing were:
  - dedicated brake retention
  - glassmorphism to preserve feed visibility
  - dynamic joystick anchoring
  - stable battery progress bar

## What Belongs To Controller

- landscape-first, camera-first controller shell
- default `Mobile Gamer` control layout
- dynamic left-thumb steering anchor
- decoupled steering and speed input
- dedicated active brake
- persistent visible mode status for `Manual` versus `Auto Tracking`
- visible AI confirmation on the feed when assist modes are active

These conclusions directly shape:

- `apps/control_app/lib/features/control/presentation/control_screen.dart`
- the controller role inside `apps/control_app/lib/app/fusion_app.dart`

## What Does Not Automatically Transfer To Robot

The following were validated for the controller experience, not for Robot runtime structure:

- floating joystick behavior
- gas / brake thumb control layout
- one-handed versus dual-thumb controller ergonomics
- controller HUD hierarchy

Robot-side interaction should instead follow the separate Robot design work already done in this repo:

- `docs/robot-state-matrix.md`
- `docs/design/robot_app/robot_runtime_baseline.md`
- `docs/robot-model-workflow.md`

That means the Robot side stays focused on:

- default `Drive`
- single dominant primary action
- compact advanced entry for `Auto` and `Track`
- explicit model / target readiness flow
- safety-first role switching and stop-first behavior

## Ideas To Carry Into The Product

- Keep the controller landscape-first and camera-first.
- Keep the top HUD stable:
  - battery bar
  - connection state
  - latency
  - current mode
- Make the left steering surface dynamic instead of fixed.
- Keep a dedicated emergency brake in every relevant mode.
- Preserve a visible mode toggle in the primary HUD, not in settings.
- In Auto or AI-assisted modes, show confirmation on the feed itself:
  - target box
  - lock label
  - confidence or state cue
- Treat Alt 2 and Alt 3 as optional secondary layouts for future settings or experiments, not the default controller.

## Implications For Next Iterations

- Wire real robot video and telemetry into the merged app shell before expanding layout variety.
- Keep `Mobile Gamer` as the default controller preset even if more controller modes are added later.
- Treat future controller modes as controller-only layout options, not as Robot runtime modes.
- Test AI trust cues with real model output, not just a toggle state:
  - visible target lock
  - mode ownership
  - brake override behavior
