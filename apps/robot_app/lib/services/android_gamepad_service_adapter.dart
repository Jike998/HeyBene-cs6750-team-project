import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class AndroidGamepadServiceAdapter {
  static const EventChannel _eventChannel = EventChannel(
    'com.openbothci.robot_app/gamepad/events',
  );
  static const MethodChannel _methodChannel = MethodChannel(
    'com.openbothci.robot_app/gamepad/methods',
  );

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<dynamic>? _eventSubscription;
  bool _isInitialized = false;
  bool _connected = false;

  bool get connected => _connected;

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  Future<void> initialize() async {
    if (_isInitialized || !Platform.isAndroid) return;
    await refreshConnectionState();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleEvent,
    );
    _isInitialized = true;
  }

  Future<bool> refreshConnectionState() async {
    if (!Platform.isAndroid) {
      _connected = false;
      return _connected;
    }
    _connected =
        await _methodChannel.invokeMethod<bool>('hasConnectedController') ??
        false;
    return _connected;
  }

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _connected = false;
    _isInitialized = false;
  }

  void _handleEvent(dynamic event) {
    if (event is! Map) return;
    final mapped = event.map(
      (key, value) => MapEntry(key.toString(), value),
    );

    final eventType = mapped['event'] as String?;
    if (eventType == 'axes') {
      _connected = true;
    } else if (eventType == 'button') {
      _connected = true;
    }

    _eventController.add(Map<String, dynamic>.from(mapped));
  }
}
