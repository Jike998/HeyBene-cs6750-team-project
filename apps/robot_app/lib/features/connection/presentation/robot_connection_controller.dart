import 'package:flutter/foundation.dart';

import '../../../app/robot_app_bootstrap.dart';
import '../domain/connection_snapshot.dart';

class RobotConnectionController extends ChangeNotifier {
  RobotConnectionController({required this.bootstrap});

  final RobotAppBootstrap bootstrap;

  ConnectionSnapshot get snapshot => ConnectionSnapshot(
        bluetoothConnected: bootstrap.networkService.controllerConnected,
        usbConnected: bootstrap.robotConnectionService.usbConnected,
        videoStable: bootstrap.networkService.isRunning,
      );

  Future<void> connectUsb() async {
    await bootstrap.robotConnectionService.connectUsb();
    notifyListeners();
  }

  Future<void> disconnectUsb() async {
    await bootstrap.robotConnectionService.disconnect();
    notifyListeners();
  }

  Future<void> connectBluetooth() async {
    await bootstrap.networkService.startServer();
    notifyListeners();
  }

  Future<void> disconnectBluetooth() async {
    await bootstrap.networkService.stopServer();
    notifyListeners();
  }

  Future<void> connectBle() async {
    await bootstrap.robotConnectionService.connectBle();
    notifyListeners();
  }

  Future<void> disconnect() async {
    await bootstrap.robotConnectionService.disconnect();
    notifyListeners();
  }
}
