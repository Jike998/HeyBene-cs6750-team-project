import 'dart:async';

abstract class RobotConnectionService {
  bool get usbConnected;
  bool get bleConnected;
  Stream<Map<String, dynamic>>? get sensorStream;

  Future<void> initialize();
  Future<void> connectUsb();
  Future<void> connectBle();
  Future<void> disconnect();
  Future<void> sendDrive(double left, double right);
  Future<void> stopDrive();
}
