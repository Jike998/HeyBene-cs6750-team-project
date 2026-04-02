import 'package:flutter/foundation.dart';

import '../../connection/domain/connection_snapshot.dart';
import '../../telemetry/domain/telemetry_snapshot.dart';
import '../domain/control_layout.dart';

class ControlState extends ChangeNotifier {
  ControlLayout layout = ControlLayout.dual;
  ConnectionSnapshot connection = ConnectionSnapshot.initial;
  TelemetrySnapshot telemetry = TelemetrySnapshot.initial.copyWith(
    speed: 0,
    steering: 0,
  );

  bool initialized = false;
  bool cameraInitialized = false;
  bool usbBusy = false;
  bool gamepadConnected = false;
  String gamepadDebug = 'Waiting for gamepad input';
  String? initializationError;

  double dualSteering = 0;
  double dualThrottle = 0;
  double arrowSteering = 0;
  double arrowThrottle = 0;
  bool arrowLeftPressed = false;
  bool arrowRightPressed = false;
  bool goPressed = false;
  bool stopPressed = false;

  bool get showCamera => gamepadConnected && cameraInitialized;

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

  void setUsbBusy(bool value) {
    if (usbBusy == value) return;
    usbBusy = value;
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

  void setLayout(ControlLayout value) {
    if (layout == value) return;
    layout = value;
    resetVisuals(notify: false);
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
        dualThrottle == 0) {
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
    notifyListeners();
  }

  void resetVisuals({bool notify = true}) {
    dualSteering = 0;
    dualThrottle = 0;
    arrowSteering = 0;
    arrowThrottle = 0;
    arrowLeftPressed = false;
    arrowRightPressed = false;
    goPressed = false;
    stopPressed = false;
    telemetry = telemetry.copyWith(speed: 0, steering: 0);
    if (notify) {
      notifyListeners();
    }
  }
}
