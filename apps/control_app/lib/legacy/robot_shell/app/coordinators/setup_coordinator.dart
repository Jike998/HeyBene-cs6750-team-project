import 'package:flutter/foundation.dart';

class SetupCoordinator extends ChangeNotifier {
  bool hasCompletedSetup = false;

  void completeSetup() {
    hasCompletedSetup = true;
    notifyListeners();
  }
}
