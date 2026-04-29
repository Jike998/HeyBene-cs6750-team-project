import 'package:flutter/foundation.dart';

import '../../connection/domain/connection_snapshot.dart';
import '../../telemetry/domain/telemetry_snapshot.dart';
import '../domain/control_layout.dart';
import '../domain/control_mode_config.dart';
import '../domain/controller_driving_mode.dart';

class ControlState extends ChangeNotifier {
  bool _disposed = false;

  ControlState();

  final Map<ControllerDrivingMode, ControllerModeControlConfig> _modeConfigs = {
    ControllerDrivingMode.manual: ControllerModeControlConfig.initial(),
    ControllerDrivingMode.autoTracking: ControllerModeControlConfig.initial(),
  };

  ControllerDrivingMode drivingMode = ControllerDrivingMode.manual;
  ConnectionSnapshot connection = ConnectionSnapshot.initial;
  TelemetrySnapshot telemetry = TelemetrySnapshot.initial.copyWith(
    speed: 0,
    steering: 0,
  );

  bool initialized = false;
  bool cameraInitialized = false;
  bool linkBusy = false;
  bool gamepadConnected = false;
  Uint8List? remotePreviewBytes;
  String gamepadDebug = 'Waiting for gamepad input';
  String? initializationError;
  bool robotIsRunning = false;
  String robotMode = 'drive';
  String controlOwner = 'none';
  bool videoEnabled = false;
  bool acceptsRemoteDrive = false;
  bool videoStarting = false;
  String? lastRejectReason;

  double dualSteering = 0;
  double dualThrottle = 0;
  double arrowSteering = 0;
  double arrowThrottle = 0;
  double oneHandSteering = 0;
  double oneHandThrottle = 0;
  bool oneHandActive = false;
  bool arrowLeftPressed = false;
  bool arrowRightPressed = false;
  bool goPressed = false;
  bool stopPressed = false;

  bool get showCamera =>
      videoEnabled && remotePreviewBytes != null && remotePreviewBytes!.isNotEmpty;
  bool get isPortraitLayout => layout.isPortrait;

  ControllerModeControlConfig configFor(ControllerDrivingMode mode) {
    return _modeConfigs[mode] ?? ControllerModeControlConfig.initial();
  }

  ControllerModeControlConfig get activeModeConfig => configFor(drivingMode);

  ControlLayout get layout => activeModeConfig.activeLayout;

  ControlLayoutPreset get activeLayoutPreset => activeModeConfig.activePreset;

  void setInitialized(bool value) {
    if (initialized == value) return;
    initialized = value;
    notifyListeners();
  }

  void setCameraInitialized(bool value) {
    if (cameraInitialized == value) return;
    cameraInitialized = value;
    notifyListeners();
  }

  void setInitializationError(String? value) {
    if (initializationError == value) return;
    initializationError = value;
    notifyListeners();
  }

  void setLinkBusy(bool value) {
    if (linkBusy == value) return;
    linkBusy = value;
    notifyListeners();
  }

  void setGamepadConnected(bool value) {
    if (gamepadConnected == value) return;
    gamepadConnected = value;
    notifyListeners();
  }

  void setGamepadDebug(String value) {
    if (gamepadDebug == value) return;
    gamepadDebug = value;
    notifyListeners();
  }

  void setRemotePreviewBytes(Uint8List? value) {
    remotePreviewBytes = value;
    if (value != null && value.isNotEmpty) {
      videoStarting = false;
    }
    notifyListeners();
  }

  void setRobotRuntimeStatus({
    bool? isRunning,
    String? mode,
    String? controlOwner,
    bool? videoEnabled,
    bool? acceptsRemoteDrive,
    bool? videoStarting,
    String? lastRejectReason,
  }) {
    var changed = false;
    if (isRunning != null && robotIsRunning != isRunning) {
      robotIsRunning = isRunning;
      changed = true;
    }
    if (mode != null && robotMode != mode) {
      robotMode = mode;
      changed = true;
    }
    if (controlOwner != null && this.controlOwner != controlOwner) {
      this.controlOwner = controlOwner;
      changed = true;
    }
    if (videoEnabled != null && this.videoEnabled != videoEnabled) {
      this.videoEnabled = videoEnabled;
      changed = true;
    }
    if (acceptsRemoteDrive != null && this.acceptsRemoteDrive != acceptsRemoteDrive) {
      this.acceptsRemoteDrive = acceptsRemoteDrive;
      changed = true;
    }
    if (videoStarting != null && this.videoStarting != videoStarting) {
      this.videoStarting = videoStarting;
      changed = true;
    }
    if (this.lastRejectReason != lastRejectReason) {
      this.lastRejectReason = lastRejectReason;
      changed = true;
    }
    if (!robotIsRunning || !this.videoEnabled) {
      this.videoStarting = false;
      remotePreviewBytes = null;
    }
    if (changed) {
      notifyListeners();
    }
  }

  void setDrivingMode(ControllerDrivingMode value) {
    if (drivingMode == value) return;
    drivingMode = value;
    resetVisuals(notify: false);
    notifyListeners();
  }

  void setLayoutForCurrentMode(ControlLayout value) {
    final config = activeModeConfig;
    if (config.activeLayout == value) return;
    _modeConfigs[drivingMode] = config.setLayout(value);
    resetVisuals(notify: false);
    notifyListeners();
  }

  void nudgeCurrentLayoutPreset(
    ControlClusterSide side, {
    required double dx,
    required double dy,
  }) {
    final config = activeModeConfig;
    final nextPreset = config.activePreset.nudge(side, dx: dx, dy: dy);
    _modeConfigs[drivingMode] = config.updatePreset(config.activeLayout, nextPreset);
    notifyListeners();
  }

  void resetCurrentLayoutSide(ControlClusterSide side) {
    final config = activeModeConfig;
    final nextPreset = config.activePreset.resetSide(side);
    _modeConfigs[drivingMode] = config.updatePreset(config.activeLayout, nextPreset);
    notifyListeners();
  }

  void resetCurrentLayoutPreset() {
    final config = activeModeConfig;
    _modeConfigs[drivingMode] = config.resetPreset(config.activeLayout);
    notifyListeners();
  }

  void setConnection({
    bool? usbConnected,
    bool? bluetoothConnected,
    bool? videoStable,
  }) {
    final next = connection.copyWith(
      usbConnected: usbConnected,
      bluetoothConnected: bluetoothConnected,
      videoStable: videoStable,
    );
    if (next == connection) return;
    connection = next;
    notifyListeners();
  }

  void applyHardwareTelemetry({
    int? battery,
    int? latency,
    double? voltage,
    double? distance,
    double? speed,
    double? steering,
  }) {
    telemetry = telemetry.copyWith(
      battery: battery,
      latency: latency,
      voltage: voltage,
      distance: distance,
      speed: speed,
      steering: steering,
    );
    notifyListeners();
  }

  void applyDriveTelemetry({
    required double left,
    required double right,
  }) {
    final speed = ((left + right) / 2).clamp(-1.0, 1.0);
    final steering = ((right - left) / 2).clamp(-1.0, 1.0);
    telemetry = telemetry.copyWith(
      speed: double.parse(speed.toStringAsFixed(2)),
      steering: double.parse(steering.toStringAsFixed(2)),
    );
    notifyListeners();
  }

  void updateDualInput({
    required double steering,
    required double throttle,
  }) {
    if ((dualSteering - steering).abs() < 0.001 &&
        (dualThrottle - throttle).abs() < 0.001 &&
        arrowSteering == 0 &&
        arrowThrottle == 0 &&
        oneHandSteering == 0 &&
        oneHandThrottle == 0 &&
        !oneHandActive &&
        !arrowLeftPressed &&
        !arrowRightPressed &&
        !goPressed &&
        !stopPressed) {
      return;
    }

    dualSteering = steering;
    dualThrottle = throttle;
    arrowSteering = 0;
    arrowThrottle = 0;
    oneHandSteering = 0;
    oneHandThrottle = 0;
    oneHandActive = false;
    arrowLeftPressed = false;
    arrowRightPressed = false;
    goPressed = false;
    stopPressed = false;
    notifyListeners();
  }

  void updateArrowInput({
    required double steering,
    required double throttle,
    required bool leftPressed,
    required bool rightPressed,
    required bool go,
    required bool stop,
  }) {
    if ((arrowSteering - steering).abs() < 0.001 &&
        (arrowThrottle - throttle).abs() < 0.001 &&
        arrowLeftPressed == leftPressed &&
        arrowRightPressed == rightPressed &&
        goPressed == go &&
        stopPressed == stop &&
        dualSteering == 0 &&
        dualThrottle == 0 &&
        oneHandSteering == 0 &&
        oneHandThrottle == 0 &&
        !oneHandActive) {
      return;
    }

    arrowSteering = steering;
    arrowThrottle = throttle;
    arrowLeftPressed = leftPressed;
    arrowRightPressed = rightPressed;
    goPressed = go;
    stopPressed = stop;
    dualSteering = 0;
    dualThrottle = 0;
    oneHandSteering = 0;
    oneHandThrottle = 0;
    oneHandActive = false;
    notifyListeners();
  }

  void updateOneHandInput({
    required double steering,
    required double throttle,
    required bool active,
  }) {
    if ((oneHandSteering - steering).abs() < 0.001 &&
        (oneHandThrottle - throttle).abs() < 0.001 &&
        oneHandActive == active &&
        dualSteering == 0 &&
        dualThrottle == 0 &&
        arrowSteering == 0 &&
        arrowThrottle == 0 &&
        !arrowLeftPressed &&
        !arrowRightPressed &&
        !goPressed &&
        !stopPressed) {
      return;
    }

    oneHandSteering = steering;
    oneHandThrottle = throttle;
    oneHandActive = active;
    dualSteering = 0;
    dualThrottle = 0;
    arrowSteering = 0;
    arrowThrottle = 0;
    arrowLeftPressed = false;
    arrowRightPressed = false;
    goPressed = false;
    stopPressed = false;
    notifyListeners();
  }

  void resetVisuals({bool notify = true}) {
    dualSteering = 0;
    dualThrottle = 0;
    arrowSteering = 0;
    arrowThrottle = 0;
    oneHandSteering = 0;
    oneHandThrottle = 0;
    oneHandActive = false;
    arrowLeftPressed = false;
    arrowRightPressed = false;
    goPressed = false;
    stopPressed = false;
    telemetry = telemetry.copyWith(speed: 0, steering: 0);
    if (notify) {
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
