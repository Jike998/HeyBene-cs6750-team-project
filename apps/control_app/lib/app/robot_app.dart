import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/robot_app_theme.dart';
import '../features/connection/presentation/robot_connection_controller.dart';
import '../features/robot_camera/presentation/robot_camera_screen.dart';
import '../features/robot_camera/state/robot_camera_controller.dart';
import '../features/robot_camera/state/robot_camera_state.dart';
import '../features/setup/presentation/setup_screen.dart';
import 'robot_app_bootstrap.dart';

class RobotApp extends StatefulWidget {
  const RobotApp({super.key});

  @override
  State<RobotApp> createState() => _RobotAppState();
}

class _RobotAppState extends State<RobotApp> {
  bool _enteredCamera = false;
  late final RobotAppBootstrap _bootstrap;
  late final RobotCameraState _cameraState;
  late final RobotCameraController _cameraController;
  late final RobotConnectionController _connectionController;

  @override
  void initState() {
    super.initState();
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
        ChangeNotifierProvider<RobotCameraController>.value(value: _cameraController),
        ChangeNotifierProvider<RobotConnectionController>.value(value: _connectionController),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Robot App',
        theme: RobotAppTheme.dark(),
        home: _enteredCamera
            ? const RobotCameraScreen()
            : SetupScreen(
                onContinue: () => setState(() => _enteredCamera = true),
              ),
      ),
    );
  }
}
