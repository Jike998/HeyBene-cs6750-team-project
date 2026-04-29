import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:async/async.dart';
import 'package:flutter/widgets.dart';

import '../../../app/robot_app_bootstrap.dart';
import '../../../services/robot_backend_service.dart';
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
  StreamSubscription<bool>? _usbConnectionSubscription;
  StreamSubscription<bool>? _linkStateSubscription;
  StreamSubscription<bool>? _pcLinkStateSubscription;
  StreamSubscription<Map<String, dynamic>>? _gamepadSubscription;
  StreamSubscription<RobotBackendSnapshot>? _backendSubscription;
  Timer? _statusTimer;
  Timer? _gamepadInactivityTimer;

  Map<String, double> _latestAxes = const {};
  double _lastSentLeft = 0;
  double _lastSentRight = 0;

  Future<void> initialize() async {
    try {
      WidgetsBinding.instance.addObserver(this);
      await bootstrap.initialize();
      await _refreshGamepadConnectionState();
      _backendSubscription = bootstrap.backendService.snapshotStream.listen(
        _handleBackendSnapshot,
      );
      state.applyBackendSnapshot(bootstrap.backendService.snapshot);
      state.applyBackendModels(await bootstrap.backendService.listModels());
      await _configureBackendForMode();
      initialized = true;
      _syncStateFromBootstrap();
      await _sendStatus();
      _statusTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        unawaited(_pushStatusTick());
      });
      _usbConnectionSubscription = bootstrap.robotConnectionService.connectionStateStream.listen((_) {
        _syncStateFromBootstrap();
      });
      _linkStateSubscription = bootstrap.networkService.linkStateStream.listen((connected) async {
        _syncStateFromBootstrap();
        if (!connected && state.driveController == DriveControllerType.phone && state.isRunning) {
          await _stopRobotActivity(disarm: true);
        }
        await _sendStatus();
      });
      _pcLinkStateSubscription = bootstrap.pcLinkService.linkStateStream.listen((connected) async {
        _syncStateFromBootstrap();
        if (!connected && state.driveController == DriveControllerType.pc && state.isRunning) {
          await _stopRobotActivity(disarm: true);
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

      _commandSubscription = StreamGroup.mergeBroadcast([
        bootstrap.networkService.commandStream.map(
          (command) => {'source': 'phone', ...command},
        ),
        bootstrap.pcLinkService.commandStream.map(
          (command) => {'source': 'pc', ...command},
        ),
      ]).listen((command) async {
        final cmd = command['cmd'];

        if (cmd == 'stop') {
          final source = command['source']?.toString() ?? 'phone';
          final owner = _ownerFromSource(source);
          final currentOwner = state.driveController;
          if (!state.isRunning || state.mode != RobotMode.drive) {
            state.setLastRejectReason('Robot drive is not active.');
            await _sendStatus(extra: _statusEcho(command));
            return;
          }
          if (currentOwner != DriveControllerType.none && currentOwner != owner) {
            state.setLastRejectReason('Control owned by ${_ownerLabel(currentOwner)}.');
            await _sendStatus(extra: _statusEcho(command));
            return;
          }
          state.setLastRejectReason(null);
          await _applyDriveCommand(left: 0, right: 0);
          await _sendStatus(extra: _statusEcho(command));
          return;
        }
        if (cmd == 'drive') {
          final left = (command['left'] as num?)?.toDouble() ?? 0;
          final right = (command['right'] as num?)?.toDouble() ?? 0;
          final source = command['source']?.toString() ?? 'phone';
          if (!state.acceptsRemoteDrive) {
            state.setLastRejectReason('Robot is not started.');
            await _sendStatus(extra: _statusEcho(command));
            return;
          }
          final owner = _ownerFromSource(source);
          final currentOwner = state.driveController;
          if (currentOwner != DriveControllerType.none && currentOwner != owner) {
            state.setLastRejectReason('Control owned by ${_ownerLabel(currentOwner)}.');
            await _sendStatus(extra: _statusEcho(command));
            return;
          }
          state.setDriveController(owner);
          state.setLastRejectReason(null);
          await _applyDriveCommand(left: left, right: right);
          await _sendStatus(extra: _statusEcho(command));
          return;
        }
        if (cmd == 'heartbeat') {
          _syncStateFromBootstrap();
          await _sendStatus(extra: _statusEcho(command));
          return;
        }
        if (cmd == 'set_mode') {
          final mode = command['mode'];
          if (mode == 'drive') state.setMode(RobotMode.drive);
          if (mode == 'auto') state.setMode(RobotMode.auto);
          if (mode == 'track') state.setMode(RobotMode.track);
          await _configureBackendForMode();
          await _stopRobotActivity(disarm: true);
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
      unawaited(_stopRobotActivity(disarm: true));
    }
  }

  Future<void> startFromUi() async {
    _syncStateFromBootstrap();
    if (!bootstrap.robotConnectionService.usbConnected) {
      state.setVideoPhase(VideoPhase.stopped);
      await _sendStatus();
      return;
    }

    state.setLastRejectReason(null);
    state.setVideoPhase(VideoPhase.starting);

    switch (state.mode) {
      case RobotMode.drive:
        await bootstrap.cameraService.startPreview();
        await bootstrap.cameraService.startBackendStream(bootstrap.backendService);
        state.startRobot();
        break;
      case RobotMode.auto:
        await bootstrap.cameraService.startPreview();
        await _configureBackendForMode();
        await bootstrap.backendService.startSession();
        await bootstrap.cameraService.startBackendStream(bootstrap.backendService);
        state.startRobot();
        break;
      case RobotMode.track:
        await bootstrap.cameraService.startPreview();
        await _configureBackendForMode();
        await bootstrap.backendService.startSession();
        await bootstrap.cameraService.startBackendStream(bootstrap.backendService);
        state.startRobot();
        break;
    }
    await _sendStatus();
  }

  Future<void> stopFromUi() async {
    await _stopRobotActivity(disarm: true);
    await bootstrap.cameraService.stopPreview();
    state.setVideoPhase(VideoPhase.stopped);
    await _sendStatus();
  }

  Future<void> toggleCollectingFromUi() async {
    final next = !state.collecting;
    await bootstrap.backendService.setCollecting(next);
    await _sendStatus();
  }

  Future<void> applyModeFromUi(RobotMode mode) async {
    if (state.mode == mode) return;
    await _stopRobotActivity(disarm: true);
    state.setMode(mode);
    await _configureBackendForMode();
    await _sendStatus();
  }

  Future<void> _pushStatusTick() async {
    await _refreshGamepadConnectionState();
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
      'gamepadConnected': state.gamepadConnected,
      'battery': state.telemetry.battery,
      'latency': state.telemetry.latency,
      'speed': state.telemetry.speed,
      'steering': state.telemetry.steering,
      'voltage': state.telemetry.voltage,
      'distance': state.telemetry.distance,
      'collecting': state.collecting,
      'controlOwner': state.driveController.name,
      'videoEnabled': state.videoEnabled,
      'acceptsRemoteDrive': state.acceptsRemoteDrive,
      'lastRejectReason': state.lastRejectReason,
      'driveSpeedMode': state.driveSpeedMode.name,
      'autoModel': state.autoModel.name,
      'autoDevice': state.autoDevice.name,
      'autoSpeedMode': state.autoSpeedMode.name,
      'trackModel': state.trackModel.name,
      'trackTargetType': state.trackTargetType.name,
      'trackDevice': state.trackDevice.name,
      'trackSpeedMode': state.trackSpeedMode.name,
      'tracking': state.mode == RobotMode.track && state.isRunning ? state.trackingStatus : 'none',
      'usbConnected': state.connection.usbConnected,
      'bluetoothConnected': state.connection.bluetoothConnected,
      'serverRunning': state.connection.videoStable,
      'backendReady': state.backendReady,
      'backendActive': state.backendActive,
      'backendStatus': state.backendStatus,
      'backendFramesProcessed': state.backendFramesProcessed,
      'backendFps': state.backendFps,
      'backendLastInferenceMs': state.backendLastInferenceMs,
      'backendModelId': state.backendModelId,
      'previewFrameBase64': state.videoEnabled ? state.previewFrameBase64 : null,
      ...extra,
    });
  }

  Future<void> _configureBackendForMode() async {
    await bootstrap.backendService.configure(
      mode: _backendModeForState(state.mode),
      device: _backendDeviceForState(),
      modelId: _backendModelIdForState(),
      trackTargetLabel: _backendTrackTargetLabelForState(),
    );
  }

  RobotBackendMode _backendModeForState(RobotMode mode) {
    return switch (mode) {
      RobotMode.auto => RobotBackendMode.auto,
      RobotMode.track => RobotBackendMode.track,
      RobotMode.drive => RobotBackendMode.drive,
    };
  }

  RobotBackendComputeDevice _backendDeviceForState() {
    final device = switch (state.mode) {
      RobotMode.auto => state.autoDevice,
      RobotMode.track => state.trackDevice,
      RobotMode.drive => ComputeDevice.cpu,
    };
    return switch (device) {
      ComputeDevice.cpu => RobotBackendComputeDevice.cpu,
      ComputeDevice.gpu => RobotBackendComputeDevice.gpu,
      ComputeDevice.nnapi => RobotBackendComputeDevice.nnapi,
    };
  }

  String? _backendModelIdForState() {
    return switch (state.mode) {
      RobotMode.auto => 'autopilot_float',
      RobotMode.track => 'ssd_mobilenet_v1',
      RobotMode.drive => null,
    };
  }

  String? _backendTrackTargetLabelForState() {
    return switch (state.trackTargetType) {
      TrackTargetType.person => 'person',
      TrackTargetType.dog => 'dog',
      TrackTargetType.cat => 'cat',
      TrackTargetType.bicycle => 'bicycle',
      TrackTargetType.car => 'car',
      TrackTargetType.banana => 'banana',
    };
  }

  DriveControllerType _ownerFromSource(String source) {
    return switch (source) {
      'pc' => DriveControllerType.pc,
      'phone' => DriveControllerType.phone,
      _ => DriveControllerType.phone,
    };
  }

  String _ownerLabel(DriveControllerType owner) {
    return switch (owner) {
      DriveControllerType.pc => 'PC',
      DriveControllerType.gamepad => 'Gamepad',
      DriveControllerType.phone => 'Phone',
      DriveControllerType.none => 'None',
    };
  }

  void _handleBackendSnapshot(RobotBackendSnapshot snapshot) {
    state.applyBackendSnapshot(snapshot);
    state.setCollecting(snapshot.collecting);
    state.setCollectionSessionPath(snapshot.collectionSessionPath);
    state.telemetry = state.telemetry.copyWith(samples: snapshot.sampleCount);
    state.notifyListeners();
    if (snapshot.active && state.mode != RobotMode.drive) {
      unawaited(
        _applyDriveCommand(
          left: snapshot.suggestedLeft,
          right: snapshot.suggestedRight,
        ),
      );
    }
  }

  void _syncStateFromBootstrap() {
    final nextConnection = state.connection.copyWith(
      bluetoothConnected: bootstrap.networkService.controllerConnected,
      usbConnected: bootstrap.robotConnectionService.usbConnected,
      videoStable: state.videoEnabled,
      pcConnected: bootstrap.pcLinkService.controllerConnected,
      pcLinkPort: bootstrap.pcLinkService.port,
      pcClientAddress: bootstrap.pcLinkService.lastClientAddress,
    );
    if (nextConnection != state.connection) {
      state.connection = nextConnection;
      state.notifyListeners();
    }
    if (!nextConnection.usbConnected && state.isRunning) {
      unawaited(_stopRobotActivity(disarm: true));
    }
  }

  Future<void> _refreshGamepadConnectionState() async {
    final connected = await bootstrap.gamepadService.refreshConnectionState();
    state.setGamepadConnected(connected);
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
    developer.log('gamepad eventType=$eventType payload=$event', name: 'RobotGamepad');

    if (eventType == 'button') {
      final button = event['button']?.toString();
      final pressed = event['pressed'] == true;
      if (button == null || button.isEmpty) return;

      final next = Map<String, double>.from(_latestAxes);
      switch (button) {
        case 'dpad_left':
          next['hatX'] = pressed ? -1 : 0;
          break;
        case 'dpad_right':
          next['hatX'] = pressed ? 1 : 0;
          break;
        case 'dpad_up':
          next['gas'] = pressed ? 1 : 0;
          next['hatY'] = pressed ? -1 : 0;
          break;
        case 'dpad_down':
          next['brake'] = pressed ? 1 : 0;
          next['hatY'] = pressed ? 1 : 0;
          break;
        case 'a':
        case 'r1':
        case 'r2':
          next['gas'] = pressed ? 1 : 0;
          next['rt'] = pressed ? 1 : 0;
          break;
        case 'b':
        case 'l1':
        case 'l2':
          next['brake'] = pressed ? 1 : 0;
          next['lt'] = pressed ? 1 : 0;
          break;
        default:
          return;
      }
      _latestAxes = next;
      _resetGamepadInactivityTimer();
      _syncStateFromBootstrap();
      if (!bootstrap.robotConnectionService.usbConnected || state.mode != RobotMode.drive || !state.isRunning) {
        return;
      }
      final currentOwner = state.driveController;
      if (currentOwner != DriveControllerType.none && currentOwner != DriveControllerType.gamepad) {
        return;
      }
      state.setDriveController(DriveControllerType.gamepad);
      state.setLastRejectReason(null);
      final drive = _computeGamepadDrive(_latestAxes);
      developer.log('button-mapped drive left=${drive.left} right=${drive.right} axes=$_latestAxes', name: 'RobotGamepad');
      await _applyDriveCommand(
        left: drive.left,
        right: drive.right,
      );
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

    if (!bootstrap.robotConnectionService.usbConnected || state.mode != RobotMode.drive || !state.isRunning) {
      return;
    }

    final currentOwner = state.driveController;
    if (currentOwner != DriveControllerType.none && currentOwner != DriveControllerType.gamepad) {
      return;
    }
    state.setDriveController(DriveControllerType.gamepad);
    state.setLastRejectReason(null);

    final drive = _computeGamepadDrive(_latestAxes);
    developer.log('axes-mapped drive left=${drive.left} right=${drive.right} axes=$_latestAxes', name: 'RobotGamepad');
    await _applyDriveCommand(
      left: drive.left,
      right: drive.right,
    );
  }

  _DrivePair _computeGamepadDrive(Map<String, double> axes) {
    final steeringRaw = _preferNonZeroAxis(axes, ['lx', 'hatX']);

    final leftStickThrottle = -_preferNonZeroAxis(axes, ['ly', 'hatY']);
    final rightStickThrottle = -_preferNonZeroAxis(axes, ['ry', 'ryAlt']);

    final triggerForward = _normalizedTrigger(
      _preferNonZeroAxis(axes, ['rt', 'gas']),
    );
    final triggerReverse = _normalizedTrigger(
      _preferNonZeroAxis(axes, ['lt', 'brake']),
    );

    final triggerThrottle = _applySignedResponse(
      _applyDeadZone(triggerForward - triggerReverse),
      _throttleExponent,
    );

    final stickThrottle = rightStickThrottle.abs() > 0.01
        ? _applySignedResponse(rightStickThrottle, _throttleExponent)
        : _applySignedResponse(leftStickThrottle, _throttleExponent);

    final throttle = triggerThrottle.abs() > 0.01 ? triggerThrottle : stickThrottle;
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
      SpeedMode.low => 0.40,
      SpeedMode.normal => 0.60,
      SpeedMode.high => 0.72,
    };

    final straightThrottle = throttle * speedScale;
    if (steering.abs() <= 0.08) {
      final forward = straightThrottle.clamp(-1.0, 1.0);
      return _DrivePair(left: forward, right: forward);
    }

    final left = (straightThrottle + steering * steeringScale)
        .clamp(-1.0, 1.0);
    final right = (straightThrottle - steering * steeringScale)
        .clamp(-1.0, 1.0);

    return _DrivePair(left: left, right: right);
  }

  Future<void> _applyDriveCommand({
    required double left,
    required double right,
  }) async {
    if (!state.isRunning || state.mode != RobotMode.drive) {
      return;
    }
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
      state.applyRemoteDrive(left: 0, right: 0);
    } else {
      await bootstrap.robotConnectionService.sendDrive(left, right);
      state.applyRemoteDrive(left: left, right: right);
    }

    _lastSentLeft = isStop ? 0 : left;
    _lastSentRight = isStop ? 0 : right;
  }

  Future<void> _stopRobotActivity({required bool disarm}) async {
    _gamepadInactivityTimer?.cancel();
    await bootstrap.cameraService.stopBackendStream();
    await bootstrap.backendService.stopSession();
    await bootstrap.robotConnectionService.stopDrive();
    await bootstrap.cameraService.stopPreview();
    state.stopRobot();
    state.setLastRejectReason(null);
    _lastSentLeft = 0;
    _lastSentRight = 0;
  }

  void _resetGamepadInactivityTimer() {
    _gamepadInactivityTimer?.cancel();
    _gamepadInactivityTimer = Timer(_gamepadInactivityTimeout, () {
      unawaited(_applyDriveCommand(left: 0, right: 0));
    });
  }

  double _preferNonZeroAxis(Map<String, double> axes, List<String> keys) {
    for (final key in keys) {
      final value = axes[key];
      if (value != null && value.abs() > _gamepadDeadZone) {
        return value;
      }
    }
    for (final key in keys) {
      final value = axes[key];
      if (value != null) {
        return value;
      }
    }
    return 0;
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
    await _backendSubscription?.cancel();
    await _usbConnectionSubscription?.cancel();
    await _linkStateSubscription?.cancel();
    await _pcLinkStateSubscription?.cancel();
    await _sensorSubscription?.cancel();
    await _commandSubscription?.cancel();
    await _stopRobotActivity(disarm: true);
    await bootstrap.dispose();
    state.disposeState();
  }
}

class _DrivePair {
  const _DrivePair({required this.left, required this.right});

  final double left;
  final double right;
}
