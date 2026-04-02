import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class BondedRobotDevice {
  const BondedRobotDevice({
    required this.name,
    required this.address,
    required this.lastUsed,
  });

  final String name;
  final String address;
  final bool lastUsed;
}

class BluetoothRobotLinkServiceAdapter {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.openbothci.control_app/robot_link/methods',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.openbothci.control_app/robot_link/events',
  );

  final StreamController<bool> _linkStateController =
      StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _statusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  StreamSubscription<dynamic>? _eventSubscription;
  bool _initialized = false;
  bool _connected = false;
  String? _deviceName;
  String? _deviceAddress;

  bool get connected => _connected;
  String? get deviceName => _deviceName;
  String? get deviceAddress => _deviceAddress;

  Stream<bool> get linkStateStream => _linkStateController.stream;
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;
  Stream<String> get errorStream => _errorController.stream;

  Future<void> initialize() async {
    if (_initialized || !Platform.isAndroid) return;
    await _ensureBluetoothPermissions();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleEvent,
    );
    _initialized = true;
  }

  Future<List<BondedRobotDevice>> getBondedDevices() async {
    if (!Platform.isAndroid) return const [];
    final granted = await _ensureBluetoothPermissions();
    if (!granted) {
      _errorController.add('Bluetooth permission is required to read bonded devices.');
      return const [];
    }

    final rawDevices = await _methodChannel.invokeMethod<List<dynamic>>(
      'getBondedDevices',
    );
    if (rawDevices == null) return const [];

    return rawDevices
        .whereType<Map>()
        .map(
          (entry) => BondedRobotDevice(
            name: entry['name']?.toString() ?? 'Robot phone',
            address: entry['address']?.toString() ?? '',
            lastUsed: entry['lastUsed'] == true,
          ),
        )
        .where((device) => device.address.isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>> connect(String address) async {
    if (!Platform.isAndroid) {
      return const {
        'success': false,
        'error': 'Bluetooth client is only available on Android.',
      };
    }
    final granted = await _ensureBluetoothPermissions();
    if (!granted) {
      const error = 'Bluetooth permission is required to connect to the robot phone.';
      _errorController.add(error);
      return const {
        'success': false,
        'error': error,
      };
    }

    final response = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'connect',
      {'address': address},
    );
    return Map<String, dynamic>.from(response ?? const {});
  }

  Future<void> disconnect() async {
    if (!Platform.isAndroid) return;
    await _methodChannel.invokeMethod<bool>('disconnect');
  }

  Future<bool> sendPayload(Map<String, dynamic> payload) async {
    if (!Platform.isAndroid || !_connected) return false;
    final sent = await _methodChannel.invokeMethod<bool>(
      'sendCommand',
      jsonEncode(payload),
    );
    return sent == true;
  }

  Future<void> dispose() async {
    await disconnect();
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _connected = false;
    _deviceName = null;
    _deviceAddress = null;
    _initialized = false;
  }

  void _handleEvent(dynamic event) {
    if (event is! Map) return;

    final mapped = Map<String, dynamic>.from(
      event.map((key, value) => MapEntry(key.toString(), value)),
    );
    final type = mapped['event']?.toString();

    switch (type) {
      case 'link_state':
        final connected = mapped['connected'] == true;
        _connected = connected;
        _deviceName = connected ? mapped['deviceName']?.toString() : null;
        _deviceAddress = connected ? mapped['deviceAddress']?.toString() : null;
        _linkStateController.add(connected);
        if (!connected) {
          _statusController.add(const {'cmd': 'stop'});
        }
        return;

      case 'status':
        final raw = mapped['raw']?.toString();
        if (raw == null || raw.isEmpty) return;
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _statusController.add(
            decoded.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          );
        }
        return;

      case 'error':
        final message = mapped['message']?.toString();
        if (message != null && message.isNotEmpty) {
          _errorController.add(message);
        }
        return;

      default:
        return;
    }
  }

  Future<bool> _ensureBluetoothPermissions() async {
    final connectStatus = await Permission.bluetoothConnect.request();
    final scanStatus = await Permission.bluetoothScan.request();
    return connectStatus.isGranted && scanStatus.isGranted;
  }
}
