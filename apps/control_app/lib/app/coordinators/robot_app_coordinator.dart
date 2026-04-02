import 'package:flutter/foundation.dart';

import '../../features/connection/domain/connection_snapshot.dart';
import '../../features/modes/domain/robot_mode.dart';
import '../../features/telemetry/domain/telemetry_snapshot.dart';
import '../coordinators/connection_coordinator.dart';
import '../coordinators/mode_coordinator.dart';
import '../coordinators/telemetry_coordinator.dart';
import '../coordinators/tracking_coordinator.dart';

class RobotAppCoordinator extends ChangeNotifier {
  RobotAppCoordinator({
    required this.connectionCoordinator,
    required this.modeCoordinator,
    required this.telemetryCoordinator,
    required this.trackingCoordinator,
  }) {
    connectionCoordinator.addListener(notifyListeners);
    modeCoordinator.addListener(notifyListeners);
    telemetryCoordinator.addListener(notifyListeners);
    trackingCoordinator.addListener(notifyListeners);
  }

  final ConnectionCoordinator connectionCoordinator;
  final ModeCoordinator modeCoordinator;
  final TelemetryCoordinator telemetryCoordinator;
  final TrackingCoordinator trackingCoordinator;

  ConnectionSnapshot get connection => connectionCoordinator.snapshot;
  TelemetrySnapshot get telemetry => telemetryCoordinator.snapshot;
  RobotMode get mode => modeCoordinator.mode;
  String get autoModel => modeCoordinator.autoModel;
  bool get collecting => modeCoordinator.collecting;
  bool get telemetryExpanded => telemetryCoordinator.expanded;

  void disposeCoordinator() {
    connectionCoordinator.removeListener(notifyListeners);
    modeCoordinator.removeListener(notifyListeners);
    telemetryCoordinator.removeListener(notifyListeners);
    trackingCoordinator.removeListener(notifyListeners);
  }
}
