import 'dart:async';

import 'robot_connection_service.dart';
import 'usb_robot_bridge_service.dart';

class OpenBeneRobotConnectionAdapter implements RobotConnectionService {
  final UsbRobotBridgeService _usbBridge = UsbRobotBridgeService();

  StreamSubscription<bool>? _usbConnectionSub;
  Timer? _heartbeatTimer;

  @override
  bool usbConnected = false;

  @override
  bool bleConnected = false;

  @override
  Stream<Map<String, dynamic>>? get sensorStream => _usbBridge.sensorStream;

  @override
  Stream<bool> get connectionStateStream => _usbBridge.connectionStateStream;

  @override
  Future<void> initialize() async {
    usbConnected = false;
    bleConnected = false;

    await _usbConnectionSub?.cancel();
    _usbConnectionSub = _usbBridge.connectionStateStream.listen((connected) {
      usbConnected = connected;
      if (!connected) {
        _stopHeartbeat();
      }
    });
  }

  @override
  Future<void> connectUsb() async {
    final connected = await _usbBridge.connect();
    usbConnected = connected;
    bleConnected = false;

    if (connected) {
      _startHeartbeat();
    } else {
      _stopHeartbeat();
    }
  }

  @override
  Future<void> connectBle() async {
    // Phase-1: USB first. BLE wiring comes next.
    bleConnected = false;
  }

  @override
  Future<void> disconnect() async {
    _stopHeartbeat();
    await _usbBridge.stop();
    await _usbBridge.disconnect();
    bleConnected = false;
    usbConnected = false;
  }

  @override
  Future<void> sendDrive(double left, double right) async {
    if (!usbConnected || !_usbBridge.isConnected) {
      usbConnected = false;
      _stopHeartbeat();
      return;
    }
    await _usbBridge.sendDrive(left, right);
    usbConnected = _usbBridge.isConnected;
  }

  @override
  Future<void> stopDrive() async {
    if (!usbConnected || !_usbBridge.isConnected) {
      usbConnected = false;
      _stopHeartbeat();
      return;
    }
    await _usbBridge.stop();
    usbConnected = _usbBridge.isConnected;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!usbConnected || !_usbBridge.isConnected) {
        _stopHeartbeat();
        return;
      }
      _usbBridge.setHeartbeat(1000);
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
}
