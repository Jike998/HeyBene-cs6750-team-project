import 'dart:ui';

import 'package:flutter/foundation.dart';

class TrackingCoordinator extends ChangeNotifier {
  Offset? point;
  String status = 'Target locked';

  void clear() {
    point = null;
    status = 'Target locked';
    notifyListeners();
  }

  void setPoint(Offset value) {
    point = value;
    status = 'Acquiring…';
    notifyListeners();
  }

  void lock() {
    if (point == null) return;
    status = 'Target locked';
    notifyListeners();
  }
}
