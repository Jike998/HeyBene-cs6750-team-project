import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/control_app_bootstrap.dart';
import '../domain/control_layout.dart';
import 'control_state.dart';

class ControlController extends ChangeNotifier with WidgetsBindingObserver {
  ControlController({
    required this.bootstrap,
    required this.state,
  });

  static const _gamepadDeadZone = 0.08;
  static const _steeringExponent = 1.32;
  static const _throttleExponent = 1.55;
  static const _commandDeltaThreshold = 0.02;
  static const _gamepadInactivityTimeout = Duration(milliseconds: 400);
  static const _localUsbLatencyMs = 12;

  final ControlAppBootstrap bootstrap;
  final ControlState state;

  StreamSubscription<Map<String, dynamic>>? _gamepadSubscription;
  StreamSubscription<Map<String, dynamic>>? _sensorSubscription;
  StreamSubscription<bool>? _usbConnectionSubscription;
  Timer? _gamepadInactivityTimer;

  Map<String, double> _latestAxes = const {};
  final Map<String, bool> _latestButtons = <String, bool>{};
  double _lastSentLeft = 0;
  double _lastSentRight = 0;
  bool _usbConnected = false;

  CameraController? get cameraController => bootstrap.cameraService.controller;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);

    try {
      await bootstrap.initializeCore();
      await _initializeCameraIfPossible();

      _usbConnected = bootstrap.robotConnectionService.usbConnected;

      final connectionStream =
          bootstrap.robotConnectionService.connectionStateStream;
      if (connectionStream != null) {
        _usbConnectionSubscription = connectionStream.listen((connected) async {
          _usbConnected = connected;
          state.setInitializationError(
            connected ? null : state.initializationError,
          );
          state.applyHardwareTelemetry(
            latency: connected ? _localUsbLatencyMs : 0,
          );
          if (!connected) {
            await _stopDrive(resetVisuals: true);
          }
          _syncConnectionState();
        });
      }

      final sensorStream = bootstrap.robotConnectionService.sensorStream;
      if (sensorStream != null) {
        _sensorSubscription = sensorStream.listen(_handleSensor);
      }

      _gamepadSubscription = bootstrap.gamepadService.events.listen((event) {
        unawaited(_handleGamepadEvent(event));
      });

      _syncConnectionState();
      state.setInitialized(true);
    } catch (error) {
      state.setInitializationError(error.toString());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.detached) {
      unawaited(_stopDrive(resetVisuals: false));
    }
  }

  Future<void> toggleRobotLink() async {
    if (state.usbBusy) return;

    state.setUsbBusy(true);
    try {
      if (_usbConnected) {
        await _stopDrive(resetVisuals: true);
        await bootstrap.robotConnectionService.disconnect();
        _usbConnected = false;
        state.applyHardwareTelemetry(latency: 0);
        state.setInitializationError(null);
      } else {
        await bootstrap.robotConnectionService.connectUsb();
        _usbConnected = bootstrap.robotConnectionService.usbConnected;
        if (_usbConnected) {
          state.applyHardwareTelemetry(latency: _localUsbLatencyMs);
          state.setInitializationError(null);
        } else {
          state.setInitializationError(
            'USB connect failed. Check the cable, OTG adapter, and USB permission.',
          );
        }
      }
      _syncConnectionState();
    } finally {
      state.setUsbBusy(false);
    }
  }

  Future<void> setLayout(ControlLayout layout) async {
    if (state.layout == layout) return;
    state.setLayout(layout);
    await _stopDrive(resetVisuals: true);
    await _processCurrentInput();
  }

  Future<void> _initializeCameraIfPossible() async {
    final granted = (await Permission.camera.request()).isGranted;
    if (!granted) {
      state.setInitializationError('Camera permission not granted.');
      return;
    }

    try {
      await bootstrap.initializeCamera();
      state.setCameraInitialized(
        bootstrap.cameraService.controller?.value.isInitialized ?? false,
      );
    } catch (error) {
      state.setInitializationError('Camera unavailable: $error');
    }
  }

  Future<void> _handleGamepadEvent(Map<String, dynamic> event) async {
    final eventType = event['event'] as String?;
    if (eventType == null) return;

    state.setGamepadConnected(true);
    _syncConnectionState();
    _resetGamepadInactivityTimer();

    if (eventType == 'button') {
      final button = event['button']?.toString();
      if (button == null || button.isEmpty) return;
      _latestButtons[button] = event['pressed'] == true;
      state.setGamepadDebug(
        'Button ${button.toUpperCase()} ${event['pressed'] == true ? "down" : "up"}',
      );
      await _processCurrentInput();
      return;
    }

    if (eventType != 'axes') return;
    final axesPayload = event['axes'];
    if (axesPayload is! Map) return;

    _latestAxes = axesPayload.map(
      (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
    );
    state.setGamepadDebug(_formatAxesDebug(_latestAxes));
    await _processCurrentInput();
  }

  Future<void> _processCurrentInput() async {
    switch (state.layout) {
      case ControlLayout.dual:
        await _processDualInput();
        return;
      case ControlLayout.arrow:
        await _processArrowInput();
        return;
    }
  }

  Future<void> _processDualInput() async {
    final steering =
        _applyDeadZone(_latestAxes['lx'] ?? _latestAxes['hatX'] ?? 0);
    final triggerThrottle = _applyDeadZone(
      _normalizedTrigger(_latestAxes['rt'] ?? _latestAxes['gas'] ?? 0) -
          _normalizedTrigger(_latestAxes['lt'] ?? _latestAxes['brake'] ?? 0),
    );
    final stickThrottle =
        _applyDeadZone(-(_latestAxes['ry'] ?? _latestAxes['ryAlt'] ?? 0));
    final throttle =
        triggerThrottle.abs() > 0.01 ? triggerThrottle : stickThrottle;

    state.updateDualInput(
      steering: steering,
      throttle: throttle,
    );

    if (!_usbConnected) return;

    final throttleMix =
        _applySignedResponse(throttle, _throttleExponent) * 0.92;
    final steeringMix =
        _applySignedResponse(steering, _steeringExponent) * 0.76;
    final left = (throttleMix + steeringMix).clamp(-1.0, 1.0);
    final right = (throttleMix - steeringMix).clamp(-1.0, 1.0);

    await _applyDriveCommand(left: left, right: right);
  }

  Future<void> _processArrowInput() async {
    final steering = _resolveArrowSteering();
    final throttle = _resolveArrowThrottle();

    state.updateArrowInput(
      steering: steering,
      throttle: throttle,
      leftPressed: _latestButtons['dpad_left'] == true || steering < -0.24,
      rightPressed: _latestButtons['dpad_right'] == true || steering > 0.24,
      go: throttle > 0.08,
      stop: throttle < -0.08,
    );

    if (!_usbConnected) return;

    final throttleMix = throttle >= 0
        ? _applySignedResponse(throttle, _throttleExponent) * 0.92
        : _applySignedResponse(throttle, _throttleExponent) * 0.46;
    final steeringMix =
        _applySignedResponse(steering, _steeringExponent) * 0.76;
    final left = (throttleMix + steeringMix).clamp(-1.0, 1.0);
    final right = (throttleMix - steeringMix).clamp(-1.0, 1.0);

    await _applyDriveCommand(left: left, right: right);
  }

  double _resolveArrowSteering() {
    final leftPressed = _latestButtons['dpad_left'] == true;
    final rightPressed = _latestButtons['dpad_right'] == true;
    if (leftPressed && !rightPressed) return -1;
    if (rightPressed && !leftPressed) return 1;

    final hatX = _applyDeadZone(_latestAxes['hatX'] ?? 0);
    if (hatX.abs() > 0.01) return hatX;

    return _applyDeadZone(_latestAxes['lx'] ?? 0);
  }

  double _resolveArrowThrottle() {
    final triggerMix = _applyDeadZone(
      _normalizedTrigger(_latestAxes['rt'] ?? _latestAxes['gas'] ?? 0) -
          _normalizedTrigger(_latestAxes['lt'] ?? _latestAxes['brake'] ?? 0),
    );
    if (triggerMix.abs() > 0.01) return triggerMix;

    final goPressed = _latestButtons['a'] == true ||
        _latestButtons['r1'] == true ||
        _latestButtons['dpad_up'] == true;
    final stopPressed = _latestButtons['b'] == true ||
        _latestButtons['l1'] == true ||
        _latestButtons['dpad_down'] == true;
    if (goPressed && !stopPressed) return 1;
    if (stopPressed && !goPressed) return -1;

    return _applyDeadZone(-(_latestAxes['ry'] ?? _latestAxes['ryAlt'] ?? 0));
  }

  Future<void> _applyDriveCommand({
    required double left,
    required double right,
  }) async {
    final isStop = left.abs() <= 0.01 && right.abs() <= 0.01;
    final isMeaningfulChange =
        (left - _lastSentLeft).abs() > _commandDeltaThreshold ||
            (right - _lastSentRight).abs() > _commandDeltaThreshold;

    if (!isMeaningfulChange && !isStop) return;
    if (!isMeaningfulChange &&
        isStop &&
        _lastSentLeft == 0 &&
        _lastSentRight == 0) {
      return;
    }

    if (isStop) {
      await bootstrap.robotConnectionService.stopDrive();
      _usbConnected = bootstrap.robotConnectionService.usbConnected;
      state.applyDriveTelemetry(left: 0, right: 0);
      _lastSentLeft = 0;
      _lastSentRight = 0;
      _syncConnectionState();
      return;
    }

    await bootstrap.robotConnectionService.sendDrive(left, right);
    _usbConnected = bootstrap.robotConnectionService.usbConnected;
    _lastSentLeft = left;
    _lastSentRight = right;
    state.applyDriveTelemetry(left: left, right: right);
    _syncConnectionState();
  }

  Future<void> _stopDrive({
    required bool resetVisuals,
  }) async {
    _gamepadInactivityTimer?.cancel();
    if (_usbConnected) {
      await bootstrap.robotConnectionService.stopDrive();
      _usbConnected = bootstrap.robotConnectionService.usbConnected;
    }
    _lastSentLeft = 0;
    _lastSentRight = 0;
    if (resetVisuals) {
      state.resetVisuals();
    } else {
      state.applyDriveTelemetry(left: 0, right: 0);
    }
    _syncConnectionState();
  }

  void _syncConnectionState() {
    state.setConnection(
      usbConnected: _usbConnected,
      bluetoothConnected: false,
      videoStable: state.cameraInitialized,
    );
  }

  void _handleSensor(Map<String, dynamic> sensor) {
    switch (sensor['type']) {
      case 'voltage':
        final voltage = (sensor['value'] as num?)?.toDouble();
        if (voltage != null) {
          final battery = (((voltage - 6.8) / (8.4 - 6.8)) * 100)
              .round()
              .clamp(0, 100);
          state.applyHardwareTelemetry(
            voltage: double.parse(voltage.toStringAsFixed(2)),
            battery: battery,
          );
        }
        return;

      case 'sonar':
        final distance = (sensor['distance'] as num?)?.toDouble();
        if (distance != null) {
          state.applyHardwareTelemetry(
            distance: double.parse(distance.toStringAsFixed(1)),
          );
        }
        return;

      case 'wheel':
        final leftRpm = (sensor['left_rpm'] as num?)?.toDouble();
        final rightRpm = (sensor['right_rpm'] as num?)?.toDouble();
        if (leftRpm != null && rightRpm != null) {
          final avgRpm = (leftRpm.abs() + rightRpm.abs()) / 2;
          final normalizedSpeed = (avgRpm / 255).clamp(0.0, 1.0);
          state.applyHardwareTelemetry(
            speed: double.parse(normalizedSpeed.toStringAsFixed(2)),
          );
        }
        return;

      default:
        return;
    }
  }

  double _applyDeadZone(double value) {
    final magnitude = value.abs();
    if (magnitude <= _gamepadDeadZone) return 0;
    final normalized = (magnitude - _gamepadDeadZone) / (1 - _gamepadDeadZone);
    return value.isNegative ? -normalized : normalized;
  }

  double _applySignedResponse(double value, double exponent) {
    if (value == 0) return 0;
    final magnitude = value.abs();
    final response = math.pow(magnitude, exponent).toDouble();
    return value.isNegative ? -response : response;
  }

  double _normalizedTrigger(double value) {
    final clamped = value.clamp(-1.0, 1.0);
    return clamped < 0 ? (clamped + 1) / 2 : clamped;
  }

  String _formatAxesDebug(Map<String, double> axes) {
    if (axes.isEmpty) return 'Axes: empty';
    final parts = axes.entries
        .map((entry) => '${entry.key}=${entry.value.toStringAsFixed(2)}')
        .toList()
      ..sort();
    return parts.take(6).join('  ');
  }

  void _resetGamepadInactivityTimer() {
    _gamepadInactivityTimer?.cancel();
    _gamepadInactivityTimer = Timer(_gamepadInactivityTimeout, () {
      unawaited(_handleGamepadInactivity());
    });
  }

  Future<void> _handleGamepadInactivity() async {
    state.setGamepadDebug('Gamepad idle');
    state.resetVisuals();
    await _stopDrive(resetVisuals: false);
  }

  Future<void> disposeController() async {
    WidgetsBinding.instance.removeObserver(this);
    _gamepadInactivityTimer?.cancel();
    await _gamepadSubscription?.cancel();
    await _sensorSubscription?.cancel();
    await _usbConnectionSubscription?.cancel();
    await _stopDrive(resetVisuals: false);
    await bootstrap.dispose();
  }
}
