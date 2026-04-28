# Robot Runtime Low-Fidelity Demos

These demos are discussion artifacts for the `Robot` side of `Robot Controller`.

They are intentionally low-fidelity and state-driven.
They are not final visual design proposals.

## Purpose

Each demo uses the same product assumptions from:

- `docs/robot-state-matrix.md`
- `docs/robot-model-workflow.md`

But each one explores a different interaction structure.

## Variants

### 1. Visible Mode Rail

Path:

- `docs/design/robot_app/visible_mode_rail/index.html`

Idea:

- `Drive`, `Auto`, and `Track` are always directly visible in the main shell.
- Best for comparing discoverability and immediate mode access.

Good for discussing:

- whether all three modes deserve equal visibility
- whether visible mode switching creates clutter during active use
- whether `Auto` and `Track` feel too "available" before prerequisites are met

### 2. Drive First + Advanced Entry

Path:

- `docs/design/robot_app/drive_first_advanced/index.html`

Idea:

- `Drive` remains the obvious default.
- `Auto` and `Track` live behind a secondary mode entry.
- Better reflects the more product-focused direction we discussed.

Good for discussing:

- whether `Auto` and `Track` should be demoted from the top-level mode rail
- whether the product should feel more "runtime tool" and less "feature browser"
- whether this is the best balance between clarity and capability

### 3. Workflow Card

Path:

- `docs/design/robot_app/workflow_card/index.html`

Idea:

- the dominant interaction is a bottom workflow card
- the primary action and next requirement are more important than visible mode controls

Good for discussing:

- whether the product should feel more task-guided
- whether model readiness and target readiness should be explicitly staged
- whether this interaction is clearer or too restrictive

## Shared Scenario Set

All three demos expose the same mock scenarios for comparison:

- setup needed
- drive idle
- drive active
- auto missing model
- auto ready
- track target needed
- fault

## Suggested Review Order

Review the demos in this order:

1. `Visible Mode Rail`
2. `Drive First + Advanced Entry`
3. `Workflow Card`

That sequence moves from:

- maximum mode visibility
- to focused default runtime
- to most guided task flow

This makes it easier to discuss which tradeoff feels right for `Robot Controller`.

## Working Baseline

Current working baseline after this comparison:

- use `Drive First + Advanced Entry` as the shell direction
- borrow explicit readiness staging from `Workflow Card` for `Auto` and `Track`

That means the product should currently bias toward:

- `Drive` as the default runtime
- `Auto` and `Track` as deliberate advanced flows
- one clear next step when prerequisites are missing

## Discussion Lens

When reviewing, try to judge them less by visual taste and more by interaction behavior:

- What does the app make feel primary?
- What does it deliberately hide or delay?
- What feels safest once the robot is active?
- What seems easiest to implement without state conflicts?
- What gives us the best starting point for later Auto / Track refinement?

## What To Compare

When we review these demos, the main questions should be:

1. Which variant makes the next action clearest?
2. Which variant keeps the camera view cleanest?
3. Which variant handles `Auto` / `Track` prerequisites most naturally?
4. Which variant makes active robot states feel safest?
5. Which variant gives us the best base for later implementation?
