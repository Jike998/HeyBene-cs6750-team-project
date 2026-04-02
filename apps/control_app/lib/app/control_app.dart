import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/control_app_theme.dart';
import '../features/control/presentation/control_screen.dart';
import '../features/control/state/control_controller.dart';
import '../features/control/state/control_state.dart';
import 'control_app_bootstrap.dart';

class ControlApp extends StatefulWidget {
  const ControlApp({super.key});

  @override
  State<ControlApp> createState() => _ControlAppState();
}

class _ControlAppState extends State<ControlApp> {
  late final ControlAppBootstrap _bootstrap;
  late final ControlState _state;
  late final ControlController _controller;

  @override
  void initState() {
    super.initState();
    _bootstrap = ControlAppBootstrap();
    _state = ControlState();
    _controller = ControlController(
      bootstrap: _bootstrap,
      state: _state,
    )..initialize();
  }

  @override
  void dispose() {
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
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Control App',
        theme: ControlAppTheme.dark(),
        home: const ControlScreen(),
      ),
    );
  }
}
