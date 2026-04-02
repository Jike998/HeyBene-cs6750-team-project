import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'robot_network_service.dart';

class BluetoothControllerLinkServiceAdapter implements RobotNetworkService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.openbothci.robot_app/controller_link/methods');
  static const EventChannel _eventChannel =
      EventChannel('com.openbothci.robot_app/controller_link/events');

  final StreamController<Map<String, dynamic>> _commandController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _linkStateController =
      StreamController<bool>.broadcast();

  StreamSubscription<dynamic>? _eventSubscription;
  bool _isRunning = false;
  bool _controllerConnected = false;
  String? _lastClientAddress;

  @override
  bool get isRunning => _isRunning;

  @override
  int get port => 1;

  @override
  String? get lastClientAddress => _lastClientAddress;

  @override
  Stream<Map<String, dynamic>> get commandStream => _commandController.stream;

  @override
  Stream<bool> get linkStateStream => _linkStateController.stream;

  @override
  bool get controllerConnected => _controllerConnected;

  @override
  Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    await _ensureBluetoothPermission();
    _eventSubscription ??=
        _eventChannel.receiveBroadcastStream().listen(_handleEvent);
  }

  @override
  Future<void> startServer() async {
    if (!Platform.isAndroid) return;
    final granted = await _ensureBluetoothPermission();
    if (!granted) {
      _isRunning = false;
      _controllerConnected = false;
      _lastClientAddress = null;
      return;
    }

    final result =
        await _methodChannel.invokeMethod<Map<Object?, Object?>>('startServer');
    _isRunning = (result?['success'] as bool?) ?? false;
  }

  @override
  Future<void> sendStatus(Map<String, dynamic> payload) async {
    if (!Platform.isAndroid || !_isRunning) return;
    await _methodChannel.invokeMethod<bool>(
      'sendStatus',
      jsonEncode(payload),
    );
  }

  @override
  Future<void> stopServer() async {
    if (!Platform.isAndroid) return;
    await _methodChannel.invokeMethod<void>('stopServer');
    _isRunning = false;
    _controllerConnected = false;
    _lastClientAddress = null;
    _linkStateController.add(false);
  }

  Future<bool> _ensureBluetoothPermission() async {
    final status = await Permission.bluetoothConnect.request();
    return status.isGranted;
  }

  void _handleEvent(dynamic event) {
    if (event is! Map) return;

    final mapped = event.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final eventType = mapped['event'] as String?;

    switch (eventType) {
      case 'command':
        final raw = mapped['raw'] as String?;
        if (raw == null) return;
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _commandController.add(decoded);
        }
        return;

      case 'link_state':
        final connected = mapped['connected'] == true;
        _controllerConnected = connected;
        _lastClientAddress =
            connected ? mapped['deviceName'] as String? : null;
        _linkStateController.add(connected);
        if (!connected) {
          _commandController.add({'cmd': 'stop'});
        }
        return;

      default:
        return;
    }
  }
}
