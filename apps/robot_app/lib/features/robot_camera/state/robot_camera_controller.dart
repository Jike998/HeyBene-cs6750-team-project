import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../app/robot_app_bootstrap.dart';
import '../../modes/domain/robot_mode.dart';
import 'robot_camera_state.dart';

class RobotCameraController extends ChangeNotifier with WidgetsBindingObserver {
  RobotCameraController({required this.bootstrap, required this.state});

  static const _gamepadDeadZone = 0.08;
  static const _steeringExponent = 1.32;
  static const _throttleExponent = 1.55;
  static const _commandDeltaThreshold = 0.02;
  static const _gamepadInactivityTimeout = Duration(milliseconds: 400);

  final RobotAppBootstrap bootstrap;
  final RobotCameraState state;

  bool initialized = false;
  String? initializationError;
  StreamSubscription<Map<String, dynamic>>? _commandSubscription;
  StreamSubscription<Map<String, dynamic>>? _sensorSubscription;
  StreamSubscription<bool>? _linkStateSubscription;
  StreamSubscription<Map<String, dynamic>>? _gamepadSubscription;
  Timer? _statusTimer;
  Timer? _gamepadInactivityTimer;

  Map<String, double> _latestAxes = const {};
  double _lastSentLeft = 0;
  double _lastSentRight = 0;

  Future<void> initialize() async {
    try {
      WidgetsBinding.instance.addObserver(this);
      await bootstrap.initialize();
      initialized = true;
      _syncStateFromBootstrap();
      await _sendStatus();
      _statusTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        unawaited(_pushStatusTick());
      });
      _linkStateSubscription = bootstrap.networkService.linkStateStream.listen((connected) async {
        _syncStateFromBootstrap();
        if (!connected && state.driveController == DriveControllerType.phone) {
          await _stopActiveDrive(disarm: false);
        }
        await _sendStatus();
      });

      final sensorStream = bootstrap.robotConnectionService.sensorStream;
      if (sensorStream != null) {
        _sensorSubscription = sensorStream.listen(_handleSensor);
      }

      _gamepadSubscription = bootstrap.gamepadService.events.listen((event) {
        unawaited(_handleGamepadEvent(event));
      });

      _commandSubscription = bootstrap.networkService.commandStream.listen((command) async {
        final cmd = command['cmd'];
        final localGamepadHasPriority = state.gamepadConnected && state.driveArmed;

        if (cmd == 'stop') {
          if (localGamepadHasPriority) {
            await _sendStatus(extra: _statusEcho(command));
            return;
          }
          await _stopActiveDrive(disarm: false);
          await _sendStatus(extra: _statusEcho(command));
          return;
        }
        if (cmd == 'drive') {
          if (localGamepadHasPriority) {
            await _sendStatus(extra: _statusEcho(command));
            return;
          }
          final left = (command['left'] as num?)?.toDouble() ?? 0;
          final right = (command['right'] as num?)?.toDouble() ?? 0;
          state.setDriveController(DriveControllerType.phone);
          await _applyDriveCommand(left: left, right: right, updateArmed: false);
          await _sendStatus(extra: _statusEcho(command));
          return;
        }
        if (cmd == 'heartbeat') {
          await _sendStatus(extra: _statusEcho(command));
          return;
        }
        if (cmd == 'set_mode') {
          final mode = command['mode'];
          if (mode == 'drive') state.setMode(RobotMode.drive);
          if (mode == 'auto') state.setMode(RobotMode.auto);
          if (mode == 'track') state.setMode(RobotMode.track);
          if (state.mode != RobotMode.drive) {
            await _stopActiveDrive(disarm: true);
          }
          await _sendStatus(extra: _statusEcho(command));
        }
      });
      notifyListeners();
    } catch (error) {
      initializationError = error.toString();
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_stopActiveDrive(disarm: true));
    }
  }

  Future<void> startFromUi() async {
    _syncStateFromBootstrap();
    if (!bootstrap.robotConnectionService.usbConnected || state.mode != RobotMode.drive) {
      await _sendStatus();
      return;
    }
    state.setDriveArmed(true);
    state.startRobot();
    state.setDriveController(DriveControllerType.gamepad);
    await _sendStatus();
  }

  Future<void> stopFromUi() async {
    await _stopActiveDrive(disarm: true);
    await _sendStatus();
  }

  Future<void> _pushStatusTick() async {
    _syncStateFromBootstrap();
    await _sendStatus();
  }

  Future<void> _sendStatus({
    Map<String, dynamic> extra = const {},
  }) async {
    await bootstrap.networkService.sendStatus({
      'type': 'status',
      'mode': state.mode.name,
      'isRunning': state.isRunning,
      'driveArmed': state.driveArmed,
      'gamepadConnected': state.gamepadConnected,
      'battery': state.telemetry.battery,
      'latency': state.telemetry.latency,
      'speed': state.telemetry.speed,
      'steering': state.telemetry.steering,
      'collecting': state.collecting,
      'driveController': state.driveController.name,
      'driveSpeedMode': state.driveSpeedMode.name,
      'autoModel': state.autoModel.name,
      'autoDevice': state.autoDevice.name,
      'autoSpeedMode': state.autoSpeedMode.name,
      'trackModel': state.trackModel.name,
      'trackTargetType': state.trackTargetType.name,
      'trackDevice': state.trackDevice.name,
      'trackSpeedMode': state.trackSpeedMode.name,
      'tracking': state.trackingPoint != null ? state.trackingStatus : 'none',
      'usbConnected': state.connection.usbConnected,
      'bluetoothConnected': state.connection.bluetoothConnected,
      'serverRunning': state.connection.videoStable,
      ...extra,
    });
  }

  void _syncStateFromBootstrap() {
    final nextConnection = state.connection.copyWith(
      bluetoothConnected: bootstrap.networkService.controllerConnected,
      usbConnected: bootstrap.robotConnectionService.usbConnected,
      videoStable: bootstrap.networkService.isRunning,
    );
    if (nextConnection != state.connection) {
      state.connection = nextConnection;
      state.notifyListeners();
    }
    if (!nextConnection.usbConnected && (state.isRunning || state.driveArmed)) {
      state.setDriveArmed(false);
      state.stopRobot();
    }
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

  Future<void> _handleGamepadEvent(Map<String, dynamic> event) async {
    final eventType = event['event'] as String?;
    if (eventType == null) return;

    state.setGamepadConnected(true);

    if (eventType == 'button') {
      return;
    }

    if (eventType != 'axes') return;

    final axesPayload = event['axes'];
    if (axesPayload is! Map) return;

    _latestAxes = axesPayload.map(
      (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
    );

    _resetGamepadInactivityTimer();
    _syncStateFromBootstrap();

    if (!bootstrap.robotConnectionService.usbConnected || state.mode != RobotMode.drive || !state.driveArmed) {
      return;
    }

    state.setDriveController(DriveControllerType.gamepad);

    final drive = _computeGamepadDrive(_latestAxes);
    await _applyDriveCommand(
      left: drive.left,
      right: drive.right,
      updateArmed: false,
    );
  }

  _DrivePair _computeGamepadDrive(Map<String, double> axes) {
    final steeringRaw = axes['lx'] ?? 0;

    final rightStickY = axes['ry'] ?? axes['ryAlt'] ?? 0;
    final rightStickThrottle = -rightStickY;

    final triggerForward = _normalizedTrigger(axes['rt'] ?? axes['gas'] ?? 0);
    final triggerReverse = _normalizedTrigger(axes['lt'] ?? axes['brake'] ?? 0);

    final dualStickThrottle = _applySignedResponse(
      _applyDeadZone(rightStickThrottle),
      _throttleExponent,
    );

    final triggerThrottle = _applySignedResponse(
      _applyDeadZone(triggerForward - triggerReverse),
      _throttleExponent,
    );

    final throttle = triggerThrottle.abs() > 0.01 ? triggerThrottle : dualStickThrottle;
    final steering = _applySignedResponse(
      _applyDeadZone(steeringRaw),
      _steeringExponent,
    );

    final speedScale = switch (state.driveSpeedMode) {
      SpeedMode.low => 0.45,
      SpeedMode.normal => 0.92,
      SpeedMode.high => 1.0,
    };
    final steeringScale = switch (state.driveSpeedMode) {
      SpeedMode.low => 0.60,
      SpeedMode.normal => 0.76,
      SpeedMode.high => 0.82,
    };

    final left = (throttle * speedScale + steering * steeringScale)
        .clamp(-1.0, 1.0);
    final right = (throttle * speedScale - steering * steeringScale)
        .clamp(-1.0, 1.0);

    return _DrivePair(left: left, right: right);
  }

  Future<void> _applyDriveCommand({
    required double left,
    required double right,
    required bool updateArmed,
  }) async {
    final isStop = left.abs() <= 0.01 && right.abs() <= 0.01;
    final isMeaningfulChange =
        (left - _lastSentLeft).abs() > _commandDeltaThreshold ||
        (right - _lastSentRight).abs() > _commandDeltaThreshold;

    if (!isMeaningfulChange && !isStop) return;
    if (!isMeaningfulChange && isStop && _lastSentLeft == 0 && _lastSentRight == 0) {
      return;
    }

    if (isStop) {
      await bootstrap.robotConnectionService.stopDrive();
      state.stopRobot();
    } else {
      await bootstrap.robotConnectionService.sendDrive(left, right);
      state.applyRemoteDrive(left: left, right: right);
      state.startRobot();
      if (updateArmed) {
        state.setDriveArmed(true);
      }
    }

    _lastSentLeft = isStop ? 0 : left;
    _lastSentRight = isStop ? 0 : right;
  }

  Future<void> _stopActiveDrive({required bool disarm}) async {
    _gamepadInactivityTimer?.cancel();
    await bootstrap.robotConnectionService.stopDrive();
    state.stopRobot();
    _lastSentLeft = 0;
    _lastSentRight = 0;
    if (disarm) {
      state.setDriveArmed(false);
    }
  }

  void _resetGamepadInactivityTimer() {
    _gamepadInactivityTimer?.cancel();
    _gamepadInactivityTimer = Timer(_gamepadInactivityTimeout, () {
      unawaited(_applyDriveCommand(left: 0, right: 0, updateArmed: false));
    });
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

  Map<String, dynamic> _statusEcho(Map<String, dynamic> command) {
    final echo = <String, dynamic>{};
    final clientTs = (command['clientTs'] as num?)?.toInt();
    final seq = (command['seq'] as num?)?.toInt();
    if (clientTs != null && clientTs > 0) {
      echo['echoTs'] = clientTs;
    }
    if (seq != null) {
      echo['ackSeq'] = seq;
    }
    return echo;
  }

  Future<void> disposeController() async {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    _gamepadInactivityTimer?.cancel();
    await _gamepadSubscription?.cancel();
    await _linkStateSubscription?.cancel();
    await _sensorSubscription?.cancel();
    await _commandSubscription?.cancel();
    await bootstrap.robotConnectionService.stopDrive();
    await bootstrap.dispose();
    state.disposeState();
  }
}

class _DrivePair {
  const _DrivePair({required this.left, required this.right});

  final double left;
  final double right;
}
