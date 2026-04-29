# OpenBot UI 团队工作区

[English](README.md) | [中文说明](README.zh.md)

这个仓库是 Georgia Tech CS6750 团队项目的工作区。

当前工作基线：

- 当前 robot runtime 主要工作分支：`backup/working-tree-20260428-1615`
- 当前重点 app：`apps/robot_app`

## 当前 app 范围

- `apps/control_app`：合并式 Flutter app，包含角色切换和 controller 侧 UI 工作
- `apps/robot_app`：独立可运行的 robot 侧 Flutter app，目前是主要 runtime 开发重点

## 建议从这里开始

1. 先读 [docs/status/robot_app_handoff_zh.md](docs/status/robot_app_handoff_zh.md)。
2. 再读 [docs/status/robot_app_handoff.md](docs/status/robot_app_handoff.md)。
3. 再读 [docs/architecture.md](docs/architecture.md)。
4. 再读 [docs/onboarding.md](docs/onboarding.md)。
5. 需要协作规则时读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 仓库结构

```text
openbot-ui/
  apps/
    control_app/
    robot_app/
  docs/
    architecture.md
    onboarding.md
    run-modes.md
    design/
    migration/
    status/
  downloads/
    README.md
    android/
  packages/
    mock_services/
    openbene_bridge/
    shared_models/
```

## 运行 app

### robot_app

```powershell
cd C:\Users\jiken\Desktop\openbot-ui\apps\robot_app
flutter pub get
flutter run
```

### control_app

```powershell
cd C:\Users\jiken\Desktop\openbot-ui\apps\control_app
flutter pub get
flutter run
```

## 当前最重要的产品规则

- `Robot` 是系统真源头。
- `Controller` 是远程控制和远程查看端。
- `START / STOP` 是 `Drive / Auto / Track` 的统一运行开关。
- 小车未连接时，`START` 显示但禁用。
- 只有 `START` 后才开启视频。
- 只有 `START` 后才接受远程控制输入。
- `Track` 现在是按目标类别自动识别和跟随，不再是点击屏幕选目标。

## 当前最关键文档

- [Robot App 中文交接文档](docs/status/robot_app_handoff_zh.md)
- [Robot App Handoff](docs/status/robot_app_handoff.md)
- [Architecture](docs/architecture.md)
- [Onboarding](docs/onboarding.md)

## 协作说明

- 当前 robot runtime 工作优先在 `apps/robot_app` 中推进。
- 在开始 UI、后端或真机测试之前，先看 `docs/status/` 下的交接文档。
- 中文交接文档里已经包含当前版本的真机测试步骤版。
