# Onboarding

## 1. Read The Context

Start with:

- `README.md`
- `docs/architecture.md`
- `docs/run-modes.md`

## 2. Pick A Primary App

- choose `apps/control_app` if you are working on the controller-side UI
- choose `apps/robot_app` if you are working on the robot-side UI

## 3. Run The App Locally

### Control App

```powershell
cd C:\Users\jiken\Desktop\openbot-ui\apps\control_app
flutter pub get
flutter run
```

### Robot App

```powershell
cd C:\Users\jiken\Desktop\openbot-ui\apps\robot_app
flutter pub get
flutter run
```

## 4. Know Where To Work

- UI polish: `lib/features/*/presentation`, `lib/core/theme`
- app logic and local state: `lib/features/*/state`, `lib/app`
- hardware/network adapters: `lib/services`

## 5. If You Do Not Have Hardware

You are still fully useful to the team.

Focus on:

- UI layout and usability
- feature structure and naming
- state flow and interaction logic
- documentation
- mock-service planning

Avoid blocking yourself on device-only testing unless your task truly requires it.

## 6. Sync Your Progress

Use `docs/status/team-sync-template.md` for updates to teammates.

Recommended rhythm:

- what you finished
- what you are doing now
- what is blocked
- what someone else can review or pick up

