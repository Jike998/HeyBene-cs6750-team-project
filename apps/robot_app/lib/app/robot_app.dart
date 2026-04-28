import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/robot_app_theme.dart';
import '../features/connection/presentation/robot_connection_controller.dart';
import '../features/control/presentation/control_screen.dart';
import '../features/control/state/control_controller.dart';
import '../features/control/state/control_state.dart';
import '../features/robot_camera/presentation/robot_camera_screen.dart';
import '../features/robot_camera/state/robot_camera_controller.dart';
import '../features/robot_camera/state/robot_camera_state.dart';
import 'controller_mode_bootstrap.dart';
import 'robot_app_bootstrap.dart';

enum RobotAppRole { robot, controller }

class RobotApp extends StatefulWidget {
  const RobotApp({super.key});

  @override
  State<RobotApp> createState() => _RobotAppState();
}

class _RobotAppState extends State<RobotApp> {
  static const _guideSeenKey = 'robot_app_first_use_guide_seen_v1';

  final _robotRootKey = GlobalKey<_RobotModeRootState>();
  final _controllerRootKey = GlobalKey<_ControllerModeRootState>();

  RobotAppRole _role = RobotAppRole.robot;
  bool _roleSwitchBusy = false;
  bool _guideScheduled = false;

  Future<void> _switchToController() async {
    if (_role == RobotAppRole.controller || _roleSwitchBusy) return;

    setState(() {
      _roleSwitchBusy = true;
    });

    try {
      final canLeave =
          await _robotRootKey.currentState?.prepareToLeaveRole() ?? true;
      if (!mounted || !canLeave) return;
      setState(() {
        _role = RobotAppRole.controller;
      });
    } finally {
      if (mounted) {
        setState(() {
          _roleSwitchBusy = false;
        });
      }
    }
  }

  Future<void> _switchToRobot() async {
    if (_role == RobotAppRole.robot || _roleSwitchBusy) return;

    setState(() {
      _roleSwitchBusy = true;
    });

    try {
      final canLeave =
          await _controllerRootKey.currentState?.prepareToLeaveRole() ?? true;
      if (!mounted || !canLeave) return;
      setState(() {
        _role = RobotAppRole.robot;
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
  void initState() {
    super.initState();
    unawaited(_maybeShowFirstUseGuide());
  }

  Future<void> _maybeShowFirstUseGuide() async {
    if (_guideScheduled) return;
    _guideScheduled = true;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_guideSeenKey) ?? false;
    if (seen || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_showFirstUseGuide());
    });
  }

  Future<void> _showFirstUseGuide() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101723),
          title: const Text('Quick Start Guide'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Robot role'),
                SizedBox(height: 8),
                Text('• This is the main app that must connect to the car.'),
                Text('• Car USB is the required main path to the vehicle.'),
                Text('• Phone Link lets another phone act as the remote controller.'),
                Text('• PC Link is for remote command/debug access.'),
                Text('• In Drive mode, press START after the car and controller path are ready.'),
                Text('• In Track mode, tap a target first, then start tracking.'),
                Text('• Collect data only records in Drive mode.'),
                SizedBox(height: 14),
                Text('Controller role'),
                SizedBox(height: 8),
                Text('• Run this on another phone or tablet as the remote controller.'),
                Text('• Bluetooth connects to the robot phone, not directly to the car.'),
                Text('• One Hand, Dual, and Arrow are controller layouts.'),
                Text('• USB here is fallback/debug only.'),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
    await prefs.setBool(_guideSeenKey, true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Robot Controller',
      theme: RobotAppTheme.dark(),
      home: Builder(
        builder: (context) {
          return Stack(
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _role == RobotAppRole.robot
                      ? _RobotModeRoot(
                          key: _robotRootKey,
                          onOpenControllerMode: _switchToController,
                        )
                      : _ControllerModeRoot(
                          key: _controllerRootKey,
                          onOpenRobotMode: _switchToRobot,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RobotModeRoot extends StatefulWidget {
  const _RobotModeRoot({
    super.key,
    required this.onOpenControllerMode,
  });

  final Future<void> Function() onOpenControllerMode;

  @override
  State<_RobotModeRoot> createState() => _RobotModeRootState();
}

class _RobotModeRootState extends State<_RobotModeRoot> {
  late final RobotAppBootstrap _bootstrap;
  late final RobotCameraState _cameraState;
  late final RobotCameraController _cameraController;
  late final RobotConnectionController _connectionController;

  Future<bool> prepareToLeaveRole() async {
    if (!_cameraState.isRunning) return true;

    final shouldStop = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF101723),
              title: const Text('Stop current run?'),
              content: const Text(
                'Stop current run before switching to Controller.',
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
      child: RobotCameraScreen(
        onOpenControllerMode: widget.onOpenControllerMode,
      ),
    );
  }
}

class _ControllerModeRoot extends StatefulWidget {
  const _ControllerModeRoot({
    super.key,
    required this.onOpenRobotMode,
  });

  final Future<void> Function() onOpenRobotMode;

  @override
  State<_ControllerModeRoot> createState() => _ControllerModeRootState();
}

class _ControllerModeRootState extends State<_ControllerModeRoot> {
  late final ControllerModeBootstrap _bootstrap;
  late final ControlState _state;
  late final ControlController _controller;

  Future<bool> prepareToLeaveRole() async {
    if (!_controller.hasActiveDriveSession) return true;

    final shouldStop = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF101723),
              title: const Text('Stop remote drive?'),
              content: const Text(
                'Stop remote drive before switching back to Robot.',
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

    await _controller.stopDriveForRoleSwitch();
    return true;
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _bootstrap = ControllerModeBootstrap();
    _state = ControlState()
      ..addListener(_syncControllerOrientations);
    _controller = ControlController(
      bootstrap: _bootstrap,
      state: _state,
    )..initialize();
  }

  void _syncControllerOrientations() {
    final orientations = _state.isPortraitLayout
        ? const [
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]
        : const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ];
    SystemChrome.setPreferredOrientations(orientations);
  }

  @override
  void dispose() {
    _state.removeListener(_syncControllerOrientations);
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
      child: ControlScreen(onOpenRobotMode: widget.onOpenRobotMode),
    );
  }
}
