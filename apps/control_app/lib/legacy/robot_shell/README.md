# robot_shell Archive

This is a robot-side scaffold that previously lived directly inside `control_app`.

It is kept here so the repository structure matches the current project reality:

- `control_app` active path: merged one-phone runtime through `FusionApp`
- `robot_app` active path: standalone robot-side UI
- `legacy/robot_shell`: temporary host-role dependency still used by `FusionApp`

## Transitional Status

Do not treat this folder as the long-term home for new shared architecture.

If something here is still useful, extract it carefully into:

- `apps/robot_app`
- `packages/shared_models`
- `packages/openbene_bridge`
- `packages/mock_services`

Short-term note:

- if the current `FusionApp` host role needs a bug fix or a careful update, this path may still need targeted edits
- avoid casually growing this folder when the same logic can be promoted or extracted instead
