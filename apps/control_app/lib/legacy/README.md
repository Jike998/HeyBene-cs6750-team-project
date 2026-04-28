# Legacy Code

This folder mostly holds archived scaffolding, but it is no longer purely inactive.

## Current Rule

- active `control_app` work should primarily stay in `lib/app`, `lib/features`, and related shared services
- `lib/legacy/robot_shell` is currently used by `FusionApp` host mode as a temporary active dependency
- files under the rest of `lib/legacy/` are preserved for reference, comparison, or selective reuse
- avoid broad new feature work inside `lib/legacy/`; prefer extracting reusable logic into active paths or shared packages
