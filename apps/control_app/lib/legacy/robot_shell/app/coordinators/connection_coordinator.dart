import 'package:flutter/foundation.dart';

import '../../features/connection/domain/connection_snapshot.dart';

class ConnectionCoordinator extends ChangeNotifier {
  ConnectionSnapshot snapshot = ConnectionSnapshot.initial;

  void setBluetoothConnected(bool value) {
    snapshot = snapshot.copyWith(bluetoothConnected: value);
    notifyListeners();
  }

  void setUsbConnected(bool value) {
    snapshot = snapshot.copyWith(usbConnected: value);
    notifyListeners();
  }

  void setVideoStable(bool value) {
    snapshot = snapshot.copyWith(videoStable: value);
    notifyListeners();
  }
}
