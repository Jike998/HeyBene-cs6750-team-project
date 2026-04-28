import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/control_app_bootstrap.dart';
import '../../../services/bluetooth_robot_link_service_adapter.dart';
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
  static const _bluetoothHeartbeatInterval = Duration(seconds: 1);
  static const _localUsbLatencyMs = 12;

  final ControlAppBootstrap bootstrap;
  final ControlState state;

  StreamSubscription<Map<String, dynamic>>? _gamepadSubscription;
  StreamSubscription<Map<String, dynamic>>? _sensorSubscription;
  StreamSubscription<bool>? _usbConnectionSubscription;
  StreamSubscription<bool>? _bluetoothLinkSubscription;
  StreamSubscription<Map<String, dynamic>>? _robotStatusSubscription;
  StreamSubscription<String>? _robotLinkErrorSubscription;
  Timer? _gamepadInactivityTimer;
  Timer? _bluetoothHeartbeatTimer;

  Map<String, double> _latestAxes = const {};
  final Map<String, bool> _latestButtons = <String, bool>{};
  double _lastSentLeft = 0;
  double _lastSentRight = 0;
  int _nextSequence = 1;
  bool _usbConnected = false;
  bool _bluetoothConnected = false;
  bool _remoteUsbConnected = false;
  bool _remoteServerRunning = false;
  bool _disposed = false;
  _ControlTransport _lastActiveTransport = _ControlTransport.none;

  CameraController? get cameraController => bootstrap.cameraService.controller;
  bool get bluetoothLinked => _bluetoothConnected;
  bool get directUsbConnected => _usbConnected;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);

    try {
      await bootstrap.initializeCore();
      await _initializeCameraIfPossible();

      _usbConnected = bootstrap.robotConnectionService.usbConnected;
      _bluetoothConnected = bootstrap.linkService.connected;

      final connectionStream =
          bootstrap.robotConnectionService.connectionStateStream;
      _usbConnectionSubscription = connectionStream.listen((connected) async {
        _usbConnected = connected;
        if (!connected && _lastActiveTransport == _ControlTransport.usb) {
          await _stopDrive(resetVisuals: true);
        }
        _applyPreferredLatency();
        _syncConnectionState();
      });

      final sensorStream = bootstrap.robotConnectionService.sensorStream;
      if (sensorStream != null) {
        _sensorSubscription = sensorStream.listen(_handleSensor);
      }

      _bluetoothLinkSubscription = bootstrap.linkService.linkStateStream.listen((
        connected,
      ) async {
        _bluetoothConnected = connected;
        if (connected) {
          state.applyHardwareTelemetry(latency: 0);
          _startBluetoothHeartbeat();
          await _sendRemoteHeartbeat();
          state.setInitializationError(null);
        } else {
          _stopBluetoothHeartbeat();
          _remoteUsbConnected = false;
          _remoteServerRunning = false;
          if (_lastActiveTransport == _ControlTransport.bluetooth) {
            _lastActiveTransport = _ControlTransport.none;
            _lastSentLeft = 0;
            _lastSentRight = 0;
            state.resetVisuals();
          }
        }
        _applyPreferredLatency();
        _syncConnectionState();
      });

      _robotStatusSubscription = bootstrap.linkService.statusStream.listen(
        _handleRobotStatus,
      );

      _robotLinkErrorSubscription = bootstrap.linkService.errorStream.listen((
        message,
      ) {
        if (message.isNotEmpty) {
          state.setInitializationError(message);
        }
      });

      _gamepadSubscription = bootstrap.gamepadService.events.listen((event) {
        unawaited(_handleGamepadEvent(event));
      });

      _applyPreferredLatency();
      _syncConnectionState();
      state.setInitialized(true);
    } catch (error) {
      state.setInitializationError(error.toString());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_stopDrive(resetVisuals: false));
    }
  }

  Future<List<BondedRobotDevice>> getBondedRobotDevices() async {
    final devices = await bootstrap.linkService.getBondedDevices();
    if (devices.isEmpty) {
      state.setInitializationError(
        'No paired robot phone found. Pair the host phone in Android Bluetooth settings first.',
      );
    } else {
      state.setInitializationError(null);
    }
    return devices;
  }

  Future<void> connectBluetoothRobotLink(String address) async {
    if (state.linkBusy) return;

    state.setLinkBusy(true);
    try {
      if (_usbConnected) {
        await _disconnectDirectUsbInternal(resetVisuals: true);
      }

      final response = await bootstrap.linkService.connect(address);
      _bluetoothConnected = bootstrap.linkService.connected;

      if (_bluetoothConnected && response['success'] != false) {
        state.applyHardwareTelemetry(latency: 0);
        _startBluetoothHeartbeat();
        await _sendRemoteHeartbeat();
        state.setInitializationError(null);
      } else {
        _stopBluetoothHeartbeat();
        _remoteUsbConnected = false;
        _remoteServerRunning = false;
        state.setInitializationError(
          response['error']?.toString() ?? 'Bluetooth connect failed.',
        );
      }

      _applyPreferredLatency();
      _syncConnectionState();
    } finally {
      state.setLinkBusy(false);
    }
  }

  Future<void> disconnectBluetoothRobotLink() async {
    if (state.linkBusy) return;

    state.setLinkBusy(true);
    try {
      await _disconnectBluetoothRobotLinkInternal(resetVisuals: true);
      state.setInitializationError(null);
      _applyPreferredLatency();
      _syncConnectionState();
    } finally {
      state.setLinkBusy(false);
    }
  }

  Future<void> toggleDirectUsbLink() async {
    if (state.linkBusy) return;

    state.setLinkBusy(true);
    try {
      if (_usbConnected) {
        await _disconnectDirectUsbInternal(resetVisuals: true);
        state.setInitializationError(null);
      } else {
        if (_bluetoothConnected) {
          await _disconnectBluetoothRobotLinkInternal(resetVisuals: true);
        }

        await bootstrap.robotConnectionService.connectUsb();
        _usbConnected = bootstrap.robotConnectionService.usbConnected;
        if (_usbConnected) {
          state.setInitializationError(null);
        } else {
          state.setInitializationError(
            'USB connect failed. Check the cable, OTG adapter, and USB permission.',
          );
        }
      }

      _applyPreferredLatency();
      _syncConnectionState();
    } finally {
      state.setLinkBusy(false);
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
    if (_disposed) return;
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

    if (_currentTransport == _ControlTransport.none) return;

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

    if (_currentTransport == _ControlTransport.none) return;

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
    if (_disposed) return;
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
      await _stopActiveTransport();
      if (_disposed) return;
      state.applyDriveTelemetry(left: 0, right: 0);
      _lastSentLeft = 0;
      _lastSentRight = 0;
      _syncConnectionState();
      return;
    }

    final transport = _currentTransport;
    if (transport == _ControlTransport.none) return;

    switch (transport) {
      case _ControlTransport.bluetooth:
        final sent = await _sendRemoteDrive(left: left, right: right);
        if (!sent || _disposed) return;
        break;
      case _ControlTransport.usb:
        await bootstrap.robotConnectionService.sendDrive(left, right);
        _usbConnected = bootstrap.robotConnectionService.usbConnected;
        if (!_usbConnected || _disposed) {
          _applyPreferredLatency();
          _syncConnectionState();
          return;
        }
        break;
      case _ControlTransport.none:
        return;
    }

    _lastActiveTransport = transport;
    _lastSentLeft = left;
    _lastSentRight = right;
    state.applyDriveTelemetry(left: left, right: right);
    _syncConnectionState();
  }

  Future<void> _stopDrive({
    required bool resetVisuals,
  }) async {
    if (_disposed) {
      _gamepadInactivityTimer?.cancel();
      return;
    }
    _gamepadInactivityTimer?.cancel();
    await _stopActiveTransport();
    if (_disposed) return;
    _lastSentLeft = 0;
    _lastSentRight = 0;
    if (resetVisuals) {
      state.resetVisuals();
    } else {
      state.applyDriveTelemetry(left: 0, right: 0);
    }
    _applyPreferredLatency();
    _syncConnectionState();
  }

  Future<void> _stopActiveTransport() async {
    switch (_lastActiveTransport) {
      case _ControlTransport.bluetooth:
        await _sendRemoteStop();
        break;
      case _ControlTransport.usb:
        if (_usbConnected) {
          await bootstrap.robotConnectionService.stopDrive();
          _usbConnected = bootstrap.robotConnectionService.usbConnected;
        }
        break;
      case _ControlTransport.none:
        break;
    }
    _lastActiveTransport = _ControlTransport.none;
  }

  Future<void> _disconnectBluetoothRobotLinkInternal({
    required bool resetVisuals,
  }) async {
    await _stopDrive(resetVisuals: resetVisuals);
    await bootstrap.linkService.disconnect();
    _bluetoothConnected = false;
    _remoteUsbConnected = false;
    _remoteServerRunning = false;
    _stopBluetoothHeartbeat();
  }

  Future<void> _disconnectDirectUsbInternal({
    required bool resetVisuals,
  }) async {
    await _stopDrive(resetVisuals: resetVisuals);
    await bootstrap.robotConnectionService.disconnect();
    _usbConnected = false;
  }

  Future<bool> _sendRemoteDrive({
    required double left,
    required double right,
  }) async {
    return _sendRemotePayload({
      'cmd': 'drive',
      'left': double.parse(left.toStringAsFixed(4)),
      'right': double.parse(right.toStringAsFixed(4)),
      'layout': state.layout.name,
    });
  }

  Future<void> _sendRemoteStop() async {
    await _sendRemotePayload({'cmd': 'stop'}, setErrorOnFailure: false);
  }

  Future<void> _sendRemoteHeartbeat() async {
    await _sendRemotePayload({'cmd': 'heartbeat'}, setErrorOnFailure: false);
  }

  Future<bool> _sendRemotePayload(
    Map<String, dynamic> payload, {
    bool setErrorOnFailure = true,
  }) async {
    if (!_bluetoothConnected || _disposed) return false;

    final sent = await bootstrap.linkService.sendPayload({
      ...payload,
      'seq': _nextSequence++,
      'clientTs': DateTime.now().millisecondsSinceEpoch,
    });

    if (!sent) {
      _bluetoothConnected = bootstrap.linkService.connected;
      _applyPreferredLatency();
      _syncConnectionState();
      if (setErrorOnFailure) {
        state.setInitializationError(
          'Bluetooth send failed. Reconnect the robot phone.',
        );
      }
    }

    return sent;
  }

  void _startBluetoothHeartbeat() {
    _bluetoothHeartbeatTimer?.cancel();
    _bluetoothHeartbeatTimer = Timer.periodic(
      _bluetoothHeartbeatInterval,
      (_) {
        unawaited(_sendRemoteHeartbeat());
      },
    );
  }

  void _stopBluetoothHeartbeat() {
    _bluetoothHeartbeatTimer?.cancel();
    _bluetoothHeartbeatTimer = null;
  }

  void _handleRobotStatus(Map<String, dynamic> status) {
    if (_disposed) return;
    if (status['type']?.toString() != 'status') return;

    _remoteUsbConnected = status['usbConnected'] == true;
    _remoteServerRunning = status['serverRunning'] == true;

    final latency = _resolveBluetoothLatency(status);
    state.applyHardwareTelemetry(
      battery: (status['battery'] as num?)?.toInt(),
      latency: latency,
      speed: (status['speed'] as num?)?.toDouble(),
      steering: (status['steering'] as num?)?.toDouble(),
      voltage: (status['voltage'] as num?)?.toDouble(),
      distance: (status['distance'] as num?)?.toDouble(),
    );
    _syncConnectionState();
  }

  int? _resolveBluetoothLatency(Map<String, dynamic> status) {
    final echoedAt = (status['echoTs'] as num?)?.toInt();
    if (echoedAt != null && echoedAt > 0) {
      final roundTripMs =
          DateTime.now().millisecondsSinceEpoch - echoedAt;
      return roundTripMs.clamp(0, 60000).toInt();
    }
    return (status['latency'] as num?)?.toInt();
  }

  void _applyPreferredLatency() {
    if (_bluetoothConnected) {
      return;
    }
    state.applyHardwareTelemetry(
      latency: _usbConnected ? _localUsbLatencyMs : 0,
    );
  }

  void _syncConnectionState() {
    if (_disposed) return;
    state.setConnection(
      usbConnected: _bluetoothConnected ? _remoteUsbConnected : _usbConnected,
      bluetoothConnected: _bluetoothConnected,
      videoStable: _bluetoothConnected ? _remoteServerRunning : state.cameraInitialized,
    );
  }

  void _handleSensor(Map<String, dynamic> sensor) {
    if (_disposed) return;
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
    if (_disposed) return;
    state.setGamepadDebug('Gamepad idle');
    state.resetVisuals();
    await _stopDrive(resetVisuals: false);
  }

  _ControlTransport get _currentTransport {
    if (_bluetoothConnected) return _ControlTransport.bluetooth;
    if (_usbConnected) return _ControlTransport.usb;
    return _ControlTransport.none;
  }

  Future<void> disposeController() async {
    if (_disposed) return;

    WidgetsBinding.instance.removeObserver(this);
    _gamepadInactivityTimer?.cancel();
    _stopBluetoothHeartbeat();
    await _gamepadSubscription?.cancel();
    await _sensorSubscription?.cancel();
    await _usbConnectionSubscription?.cancel();
    await _bluetoothLinkSubscription?.cancel();
    await _robotStatusSubscription?.cancel();
    await _robotLinkErrorSubscription?.cancel();

    await _stopActiveTransport();
    _disposed = true;
    await bootstrap.dispose();
  }
}

enum _ControlTransport { none, usb, bluetooth }
