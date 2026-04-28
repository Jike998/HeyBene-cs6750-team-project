import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/control_app_theme.dart';
import '../features/control/presentation/control_screen.dart';
import '../features/control/state/control_controller.dart';
import '../features/control/state/control_state.dart';
import '../legacy/robot_shell/app/robot_app_bootstrap.dart';
import '../legacy/robot_shell/features/connection/presentation/robot_connection_controller.dart';
import '../legacy/robot_shell/features/robot_camera/presentation/robot_camera_screen.dart';
import '../legacy/robot_shell/features/robot_camera/state/robot_camera_controller.dart';
import '../legacy/robot_shell/features/robot_camera/state/robot_camera_state.dart';
import 'control_app_bootstrap.dart';

enum FusionRole { robot, controller }

extension FusionRolePresentation on FusionRole {
  String get label => switch (this) {
        FusionRole.robot => 'Robot',
        FusionRole.controller => 'Controller',
      };

  String get description => switch (this) {
        FusionRole.robot => 'Robot-side runtime with camera, Drive, Auto, and Track.',
        FusionRole.controller => 'Controller-side runtime for gamepad and remote drive.',
      };
}

class FusionApp extends StatefulWidget {
  const FusionApp({super.key});

  @override
  State<FusionApp> createState() => _FusionAppState();
}

class _FusionAppState extends State<FusionApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _robotRootKey = GlobalKey<_RobotRoleRootState>();
  final _controllerRootKey = GlobalKey<_ControllerRoleRootState>();

  FusionRole _role = FusionRole.robot;
  bool _roleSwitchBusy = false;

  Future<bool> _prepareCurrentRoleExit() async {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return true;

    switch (_role) {
      case FusionRole.robot:
        final future =
            _robotRootKey.currentState?.prepareToLeaveRole(navigatorContext);
        return future == null ? true : await future;
      case FusionRole.controller:
        final future =
            _controllerRootKey.currentState?.prepareToLeaveRole(
          navigatorContext,
        );
        return future == null ? true : await future;
    }
  }

  Future<void> _openRolePicker() async {
    if (_roleSwitchBusy) return;
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return;

    final nextRole = await showModalBottomSheet<FusionRole>(
      context: navigatorContext,
      backgroundColor: const Color(0xFF101723),
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: FusionRole.values
                  .map(
                    (role) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      tileColor: role == _role
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.transparent,
                      title: Text(
                        role.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        role.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.66),
                        ),
                      ),
                      trailing: role == _role
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                      onTap: () => Navigator.of(context).pop(role),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );

    if (!mounted || nextRole == null || nextRole == _role) return;

    await _setRole(nextRole);
  }

  Future<void> _setRole(FusionRole role) async {
    if (_role == role || _roleSwitchBusy) return;

    setState(() {
      _roleSwitchBusy = true;
    });

    try {
      final canLeave = await _prepareCurrentRoleExit();
      if (!mounted || !canLeave) return;

      setState(() {
        _role = role;
      });
    } finally {
      if (mounted) {
        setState(() {
          _roleSwitchBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Robot Controller',
      navigatorKey: _navigatorKey,
      theme: ControlAppTheme.dark(),
      home: Builder(
        builder: (shellContext) {
          return Scaffold(
            backgroundColor: const Color(0xFF05070D),
            body: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _role == FusionRole.robot
                        ? _RobotRoleRoot(key: _robotRootKey)
                        : _ControllerRoleRoot(key: _controllerRootKey),
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(shellContext).top + 8,
                  right: 10,
                  child: _RolePickerButton(
                    role: _role,
                    busy: _roleSwitchBusy,
                    onPressed: _openRolePicker,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RolePickerButton extends StatelessWidget {
  const _RolePickerButton({
    required this.role,
    required this.busy,
    required this.onPressed,
  });

  final FusionRole role;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              role.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              busy ? Icons.sync : Icons.swap_horiz,
              size: 16,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControllerRoleRoot extends StatefulWidget {
  const _ControllerRoleRoot({super.key});

  @override
  State<_ControllerRoleRoot> createState() => _ControllerRoleRootState();
}

class _ControllerRoleRootState extends State<_ControllerRoleRoot> {
  late final ControlAppBootstrap _bootstrap;
  late final ControlState _state;
  late final ControlController _controller;

  Future<bool> prepareToLeaveRole(BuildContext context) async {
    return true;
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _bootstrap = ControlAppBootstrap();
    _state = ControlState();
    _controller = ControlController(
      bootstrap: _bootstrap,
      state: _state,
    )..initialize();
  }

  @override
  void dispose() {
    // Fire-and-forget async teardown; controller self-guards after disposal.
    _controller.disposeController();
    _controller.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ControlState>.value(value: _state),
        ChangeNotifierProvider<ControlController>.value(value: _controller),
      ],
      child: const ControlScreen(),
    );
  }
}

class _RobotRoleRoot extends StatefulWidget {
  const _RobotRoleRoot({super.key});

  @override
  State<_RobotRoleRoot> createState() => _RobotRoleRootState();
}

class _RobotRoleRootState extends State<_RobotRoleRoot> {
  late final RobotAppBootstrap _bootstrap;
  late final RobotCameraState _cameraState;
  late final RobotCameraController _cameraController;
  late final RobotConnectionController _connectionController;

  Future<bool> prepareToLeaveRole(BuildContext context) async {
    if (!_cameraState.isRunning) return true;

    final shouldStop = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF101723),
              title: const Text('Stop current run?'),
              content: const Text(
                'Robot is currently active. Stop the current run before switching to Controller.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Stop and Switch'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldStop) return false;

    await _cameraController.stopFromUi();
    return true;
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _bootstrap = RobotAppBootstrap();
    _cameraState = RobotCameraState()..start();
    _cameraController = RobotCameraController(
      bootstrap: _bootstrap,
      state: _cameraState,
    )..initialize();
    _connectionController = RobotConnectionController(bootstrap: _bootstrap);
  }

  @override
  void dispose() {
    _cameraController.disposeController();
    _cameraController.dispose();
    _cameraState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<RobotCameraState>.value(value: _cameraState),
        ChangeNotifierProvider<RobotCameraController>.value(
          value: _cameraController,
        ),
        ChangeNotifierProvider<RobotConnectionController>.value(
          value: _connectionController,
        ),
      ],
      child: const RobotCameraScreen(),
    );
  }
}
