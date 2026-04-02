# robot_shell Archive

This is an archived robot-side scaffold that previously lived directly inside `control_app`.

It is kept here so the repository structure matches the current project reality:

- `control_app` active path: controller-side UI
- `robot_app` active path: robot-side UI
- `legacy/robot_shell`: old embedded robot-side experiment preserved as reference only

## Do Not Use As Mainline

Do not build new team-project features on top of this archive path.

If something here is still useful, extract it carefully into:

- `apps/robot_app`
- `packages/shared_models`
- `packages/openbene_bridge`
- `packages/mock_services`

