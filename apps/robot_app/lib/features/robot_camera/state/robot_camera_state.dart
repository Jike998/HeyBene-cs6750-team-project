import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../services/robot_backend_service.dart';
import '../../connection/domain/connection_snapshot.dart';
import '../../modes/domain/robot_mode.dart';
import '../../telemetry/domain/telemetry_snapshot.dart';

enum DriveControllerType { pc, gamepad, phone, none }

enum VideoPhase { stopped, starting, live }

enum SpeedMode { low, normal, high }

enum AutoModel { modelA, modelB, modelC }

enum TrackModel { modelA, modelB, modelC }

enum ComputeDevice { cpu, gpu, nnapi }

enum TrackTargetType { person, dog, cat, bicycle, car, banana }

class RobotCameraState extends ChangeNotifier {
  RobotMode mode = RobotMode.drive;

  bool isRunning = false;
  bool gamepadConnected = false;

  bool backendReady = false;
  bool backendActive = false;
  bool collecting = false;
  String backendStatus = 'Backend idle';
  String? collectionSessionPath;
  List<RobotBackendModel> backendModels = const [];
  double backendSuggestedLeft = 0;
  double backendSuggestedRight = 0;
  int backendFramesProcessed = 0;
  int backendLastInferenceMs = 0;
  double backendFps = 0;
  String? backendModelId;
  String? previewFrameBase64;
  VideoPhase videoPhase = VideoPhase.stopped;
  String? lastRejectReason;
  Rect? trackingBox;
  String? trackingLabel;
  double? trackingConfidence;

  // Drive mode
  DriveControllerType driveController = DriveControllerType.none;
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
  String trackingStatus = 'Target locked';

  Timer? _timer;
  final _random = Random();

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

  void applyBackendModels(List<RobotBackendModel> models) {
    backendModels = models;
    notifyListeners();
  }

  void setCollectionSessionPath(String? value) {
    if (collectionSessionPath == value) return;
    collectionSessionPath = value;
    notifyListeners();
  }

  void setCollecting(bool value) {
    if (collecting == value) return;
    collecting = value;
    notifyListeners();
  }

  void applyBackendSnapshot(RobotBackendSnapshot snapshot) {
    backendReady = snapshot.initialized;
    backendActive = snapshot.active;
    backendStatus = snapshot.status;
    backendSuggestedLeft = snapshot.suggestedLeft;
    backendSuggestedRight = snapshot.suggestedRight;
    backendFramesProcessed = snapshot.framesProcessed;
    backendLastInferenceMs = snapshot.lastInferenceMs;
    backendFps = snapshot.framesPerSecond;
    backendModelId = snapshot.activeModelId;
    previewFrameBase64 = snapshot.previewFrameBase64;
    trackingLabel = snapshot.detectionLabel;
    trackingConfidence = snapshot.detectionScore;
    if (snapshot.trackingBoxLeft != null &&
        snapshot.trackingBoxTop != null &&
        snapshot.trackingBoxRight != null &&
        snapshot.trackingBoxBottom != null) {
      trackingBox = Rect.fromLTRB(
        snapshot.trackingBoxLeft!,
        snapshot.trackingBoxTop!,
        snapshot.trackingBoxRight!,
        snapshot.trackingBoxBottom!,
      );
    } else {
      trackingBox = null;
    }
    if (snapshot.detectionLabel != null && snapshot.detectionScore != null && mode == RobotMode.track) {
      trackingStatus = 'Tracking ${snapshot.detectionLabel}';
    }
    if (snapshot.previewFrameBase64 != null && snapshot.previewFrameBase64!.isNotEmpty) {
      videoPhase = VideoPhase.live;
    }
    notifyListeners();
  }

  void disposeState() {
    _timer?.cancel();
  }

  void _resetRuntimeState() {
    isRunning = false;
    collecting = false;
    previewFrameBase64 = null;
    videoPhase = VideoPhase.stopped;
    clearDriveController();
  }

  void setMode(RobotMode nextMode) {
    mode = nextMode;
    if (mode != RobotMode.track) {
      trackingStatus = 'Target locked';
      trackingBox = null;
      trackingLabel = null;
      trackingConfidence = null;
    }
    _resetRuntimeState();
    lastRejectReason = null;
    telemetry = telemetry.copyWith(
      confidence: switch (mode) {
        RobotMode.drive => collecting ? 88 : 91,
        RobotMode.auto => _confidenceForAutoModel(),
        RobotMode.track => 91,
      },
    );
    notifyListeners();
  }

  void startRobot() {
    isRunning = true;
    lastRejectReason = null;
    if (videoPhase == VideoPhase.stopped) {
      videoPhase = VideoPhase.starting;
    }
    notifyListeners();
  }

  void stopRobot() {
    _resetRuntimeState();
    telemetry = telemetry.copyWith(
      speed: 0,
      steering: 0,
      confidence: mode == RobotMode.track ? 88 : telemetry.confidence,
    );
    notifyListeners();
  }

  void toggleCollect() {
    if (mode != RobotMode.drive) return;
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

  void setTrackingLocked() {
    if (mode != RobotMode.track) return;
    trackingStatus = 'Target locked';
    telemetry = telemetry.copyWith(confidence: 95);
    notifyListeners();
  }

  void setDriveController(DriveControllerType v) {
    if (driveController == v) return;
    driveController = v;
    notifyListeners();
  }

  void clearDriveController() {
    setDriveController(DriveControllerType.none);
  }

  void setLastRejectReason(String? reason) {
    if (lastRejectReason == reason) return;
    lastRejectReason = reason;
    notifyListeners();
  }

  void setVideoPhase(VideoPhase phase) {
    if (videoPhase == phase) return;
    videoPhase = phase;
    if (phase != VideoPhase.live) {
      previewFrameBase64 = null;
    }
    notifyListeners();
  }

  bool get videoEnabled => isRunning && videoPhase != VideoPhase.stopped;

  bool get acceptsRemoteDrive => isRunning && mode == RobotMode.drive;

  void setGamepadConnected(bool connected) {
    if (gamepadConnected == connected) return;
    gamepadConnected = connected;
    notifyListeners();
  }
  void setDriveSpeedMode(SpeedMode v) { driveSpeedMode = v; notifyListeners(); }

  void setAutoModel(AutoModel v) { autoModel = v; notifyListeners(); }
  void setAutoDevice(ComputeDevice v) { autoDevice = v; notifyListeners(); }
  void setAutoSpeedMode(SpeedMode v) { autoSpeedMode = v; notifyListeners(); }

  void setTrackModel(TrackModel v) { trackModel = v; notifyListeners(); }
  void setTrackTargetType(TrackTargetType v) {
    trackTargetType = v;
    if (mode == RobotMode.track) {
      trackingLabel = null;
      trackingConfidence = null;
      trackingStatus = 'Looking for ${switch (v) {
        TrackTargetType.person => 'person',
        TrackTargetType.dog => 'dog',
        TrackTargetType.cat => 'cat',
        TrackTargetType.bicycle => 'bicycle',
        TrackTargetType.car => 'car',
        TrackTargetType.banana => 'banana',
      }}';
    }
    notifyListeners();
  }
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
