import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';

bool get _usbSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

class UsbRobotBridgeService {
  UsbPort? _port;
  StreamSubscription<Uint8List>? _subscription;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Line buffer for OpenBot protocol (newline-delimited)
  String _lineBuffer = '';

  final StreamController<bool> _connectionStateController = StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _sensorController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  Stream<Map<String, dynamic>> get sensorStream => _sensorController.stream;

  Future<bool> connect() async {
    if (!_usbSupported) return false;

    try {
      await disconnect();

      final devices = await UsbSerial.listDevices();
      if (devices.isEmpty) return false;

      final port = await devices.first.create();
      if (port == null) return false;

      final opened = await port.open();
      if (!opened) {
        await port.close();
        return false;
      }

      await port.setDTR(true);
      await port.setRTS(true);
      await port.setPortParameters(
        115200,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _port = port;
      _subscription = port.inputStream?.listen(_onData);
      _isConnected = true;
      _connectionStateController.add(true);

      await requestFeatures();
      return true;
    } catch (_) {
      await disconnect();
      return false;
    }
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;

    await _port?.close();
    _port = null;

    if (_isConnected) {
      _isConnected = false;
      _connectionStateController.add(false);
    } else {
      _isConnected = false;
    }

    _lineBuffer = '';
  }

  void _onData(Uint8List data) {
    try {
      _lineBuffer += utf8.decode(data, allowMalformed: true);
      final lines = _lineBuffer.split('\n');
      _lineBuffer = lines.last;

      for (var i = 0; i < lines.length - 1; i++) {
        final line = lines[i].replaceAll('\r', '').trim();
        if (line.isEmpty) continue;
        _parseLine(line);
      }
    } catch (_) {
      _lineBuffer = '';
    }
  }

  void _parseLine(String line) {
    if (line.isEmpty) return;

    final header = line[0];
    final body = line.length > 1 ? line.substring(1) : '';

    switch (header) {
      case 'f':
        _sensorController.add({'type': 'features', 'raw': body});
        return;

      case 'v':
        final voltage = double.tryParse(body);
        if (voltage != null) {
          _sensorController.add({'type': 'voltage', 'value': voltage});
        }
        return;

      case 'w':
        final parts = body.split(',');
        if (parts.length == 2) {
          final left = double.tryParse(parts[0]);
          final right = double.tryParse(parts[1]);
          if (left != null && right != null) {
            _sensorController.add({'type': 'wheel', 'left_rpm': left, 'right_rpm': right});
          }
        }
        return;

      case 's':
        final distance = double.tryParse(body);
        if (distance != null) {
          _sensorController.add({'type': 'sonar', 'distance': distance});
        }
        return;

      case 'b':
        _sensorController.add({'type': 'bumper', 'id': body});
        return;

      default:
        return;
    }
  }

  Future<void> sendDrive(double left, double right) async {
    final leftInt = (left.clamp(-1.0, 1.0) * 255).round();
    final rightInt = (right.clamp(-1.0, 1.0) * 255).round();
    await sendRaw('c$leftInt,$rightInt');
  }

  Future<void> stop() async {
    await sendRaw('c0,0');
  }

  Future<void> setHeartbeat(int intervalMs) async {
    await sendRaw('h$intervalMs');
  }

  Future<void> requestFeatures() async {
    await sendRaw('f');
  }

  Future<void> sendRaw(String command) async {
    final port = _port;
    if (!_isConnected || port == null) return;

    try {
      await port.write(Uint8List.fromList(utf8.encode('$command\n')));
    } catch (_) {
      await disconnect();
    }
  }
}
