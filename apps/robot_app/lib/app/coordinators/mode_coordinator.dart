import 'package:flutter/foundation.dart';

import '../../features/modes/domain/robot_mode.dart';

class ModeCoordinator extends ChangeNotifier {
  RobotMode mode = RobotMode.drive;
  String autoModel = 'Balanced';
  bool collecting = false;

  void setMode(RobotMode value) {
    mode = value;
    notifyListeners();
  }

  void setAutoModel(String value) {
    autoModel = value;
    notifyListeners();
  }

  void toggleCollect() {
    collecting = !collecting;
    notifyListeners();
  }
}
