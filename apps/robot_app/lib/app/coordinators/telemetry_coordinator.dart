import 'package:flutter/foundation.dart';

import '../../features/telemetry/domain/telemetry_snapshot.dart';

class TelemetryCoordinator extends ChangeNotifier {
  TelemetrySnapshot snapshot = TelemetrySnapshot.initial;
  bool expanded = false;

  void setExpanded(bool value) {
    if (expanded == value) return;
    expanded = value;
    notifyListeners();
  }

  void update(TelemetrySnapshot value) {
    snapshot = value;
    notifyListeners();
  }
}
