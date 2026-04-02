import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../connection/domain/connection_snapshot.dart';
import '../../modes/domain/robot_mode.dart';
import '../../telemetry/domain/telemetry_snapshot.dart';

enum DriveControllerType { pc, gamepad, phone }

enum SpeedMode { low, normal, high }

enum AutoModel { modelA, modelB, modelC }

enum TrackModel { modelA, modelB, modelC }

enum ComputeDevice { cpu, gpu, nnapi }

enum TrackTargetType { person, dog, bicycle, cat }

class RobotCameraState extends ChangeNotifier {
  RobotMode mode = RobotMode.drive;

  bool isRunning = false;
  bool driveArmed = false;
  bool gamepadConnected = false;
  String gamepadDebug = 'No gamepad input yet';

  // Drive mode
  bool collecting = false;
  DriveControllerType driveController = DriveControllerType.gamepad;
  SpeedMode driveSpeedMode = SpeedMode.normal;

  // Auto mode
  AutoModel autoModel = AutoModel.modelA;
  ComputeDevice autoDevice = ComputeDevice.cpu;
  SpeedMode autoSpeedMode = SpeedMode.normal;

  // Track mode
  TrackModel trackModel = TrackModel.modelA;
  TrackTargetType trackTargetType = TrackTargetType.person;
  ComputeDevice trackDevice = ComputeDevice.cpu;
  SpeedMode trackSpeedMode = SpeedMode.normal;

  bool telemetryExpanded = false;

  ConnectionSnapshot connection = ConnectionSnapshot.initial;
  TelemetrySnapshot telemetry = TelemetrySnapshot.initial;
  Offset? trackingPoint;
  String trackingStatus = 'Target locked';

  Timer? _timer;
  final _random = Random();

  // When real USB/BLE telemetry is present, the controller will override
  // the relevant fields. This timer only keeps the UI alive in demo mode.
  void start() {
    _timer ??= Timer.periodic(const Duration(milliseconds: 1500), (_) {
      telemetry = telemetry.copyWith(
        battery: max(68, min(98, telemetry.battery + (_random.nextDouble() > 0.84 ? -1 : 0))),
        latency: max(24, min(88, telemetry.latency + _random.nextInt(9) - 4)),
        voltage: double.parse((max(7.4, min(8.2, telemetry.voltage + (_random.nextDouble() * 0.08 - 0.04)))).toStringAsFixed(1)),
        distance: double.parse((max(0.8, min(3.6, telemetry.distance + (_random.nextDouble() * 0.32 - 0.16)))).toStringAsFixed(1)),
        samples: telemetry.samples + (collecting ? 3 : 0),
        confidence: mode == RobotMode.auto ? _confidenceForAutoModel() : telemetry.confidence,
      );
      notifyListeners();
    });
  }

  void applyHardwareTelemetry({
    int? battery,
    double? voltage,
    double? distance,
    double? speed,
  }) {
    telemetry = telemetry.copyWith(
      battery: battery,
      voltage: voltage,
      distance: distance,
      speed: speed,
    );
    notifyListeners();
  }

  void disposeState() {
    _timer?.cancel();
  }

  void setMode(RobotMode nextMode) {
    mode = nextMode;
    if (mode != RobotMode.track) {
      trackingPoint = null;
      trackingStatus = 'Target locked';
    }
    if (mode != RobotMode.drive) {
      driveArmed = false;
      isRunning = false;
    }
    telemetry = telemetry.copyWith(
      confidence: switch (mode) {
        RobotMode.drive => collecting ? 88 : 91,
        RobotMode.auto => _confidenceForAutoModel(),
        RobotMode.track => trackingPoint == null ? 81 : 95,
      },
    );
    notifyListeners();
  }

  void startRobot() {
    isRunning = true;
    notifyListeners();
  }

  void stopRobot() {
    isRunning = false;
    collecting = false;
    telemetry = telemetry.copyWith(
      speed: 0,
      steering: 0,
      confidence: mode == RobotMode.track ? 88 : telemetry.confidence,
    );
    notifyListeners();
  }

  void toggleCollect() {
    if (!isRunning) return;
    collecting = !collecting;
    notifyListeners();
  }

  void toggleTelemetry() {
    telemetryExpanded = !telemetryExpanded;
    notifyListeners();
  }

  void setTelemetryExpanded(bool expanded) {
    telemetryExpanded = expanded;
    notifyListeners();
  }

  void setTrackingPoint(Offset point) {
    if (mode != RobotMode.track) return;
    trackingPoint = point;
    trackingStatus = 'Acquiring\u2026';
    telemetry = telemetry.copyWith(confidence: 76);
    notifyListeners();

    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (mode != RobotMode.track || trackingPoint == null) return;
      trackingStatus = 'Target locked';
      telemetry = telemetry.copyWith(confidence: 95);
      notifyListeners();
    });
  }

  void setDriveController(DriveControllerType v) {
    if (driveController == v) return;
    driveController = v;
    notifyListeners();
  }

  void setDriveArmed(bool armed) {
    if (driveArmed == armed) return;
    driveArmed = armed;
    if (!armed) {
      isRunning = false;
      collecting = false;
      telemetry = telemetry.copyWith(
        speed: 0,
        steering: 0,
      );
    }
    notifyListeners();
  }

  void setGamepadConnected(bool connected) {
    if (gamepadConnected == connected) return;
    gamepadConnected = connected;
    notifyListeners();
  }

  void setGamepadDebug(String value) {
    if (gamepadDebug == value) return;
    gamepadDebug = value;
    notifyListeners();
  }
  void setDriveSpeedMode(SpeedMode v) { driveSpeedMode = v; notifyListeners(); }

  void setAutoModel(AutoModel v) { autoModel = v; notifyListeners(); }
  void setAutoDevice(ComputeDevice v) { autoDevice = v; notifyListeners(); }
  void setAutoSpeedMode(SpeedMode v) { autoSpeedMode = v; notifyListeners(); }

  void setTrackModel(TrackModel v) { trackModel = v; notifyListeners(); }
  void setTrackTargetType(TrackTargetType v) { trackTargetType = v; notifyListeners(); }
  void setTrackDevice(ComputeDevice v) { trackDevice = v; notifyListeners(); }
  void setTrackSpeedMode(SpeedMode v) { trackSpeedMode = v; notifyListeners(); }

  void applyRemoteDrive({required double left, required double right}) {
    final speed = ((left + right) / 2).clamp(-1.0, 1.0);
    final steering = ((right - left) / 2).clamp(-1.0, 1.0);
    telemetry = telemetry.copyWith(
      speed: double.parse(speed.toStringAsFixed(2)),
      steering: double.parse(steering.toStringAsFixed(2)),
      confidence: mode == RobotMode.drive ? 91 : telemetry.confidence,
    );
    notifyListeners();
  }

  int _confidenceForAutoModel() {
    return switch (autoModel) {
      AutoModel.modelA => 94,
      AutoModel.modelB => 89,
      AutoModel.modelC => 97,
    };
  }

  @override
  void dispose() {
    disposeState();
    super.dispose();
  }
}
