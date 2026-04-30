import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';

class WebSocketRobotLinkServiceAdapter {
  final StreamController<bool> _linkStateController =
      StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _statusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _connected = false;
  String? _targetAddress;

  bool get connected => _connected;
  String? get targetAddress => _targetAddress;

  Stream<bool> get linkStateStream => _linkStateController.stream;
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;
  Stream<String> get errorStream => _errorController.stream;

  Future<void> initialize() async {}

  Future<Map<String, dynamic>> connect(String target) async {
    final uri = _normalizeTarget(target);
    if (uri == null) {
      const error = 'Enter a valid ws:// address or host.';
      _errorController.add(error);
      return const {
        'success': false,
        'error': error,
      };
    }

    await disconnect();

    try {
      final channel = IOWebSocketChannel.connect(uri);
      _channel = channel;
      _connected = true;
      _targetAddress = uri.toString();
      _linkStateController.add(true);
      _subscription = channel.stream.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
      );

      // Send test command immediately after connection
      await Future.delayed(const Duration(milliseconds: 100));
      final testPayload = {
        'cmd': 'stop',
        'source': 'phone',
        'seq': 1,
        'clientTs': 1234567891,
      };
      channel.sink.add(jsonEncode(testPayload));

      return {
        'success': true,
        'targetAddress': _targetAddress,
      };
    } catch (error) {
      await disconnect();
      final message = error.toString();
      _errorController.add(message);
      return {
        'success': false,
        'error': message,
      };
    }
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    if (_connected) {
      _connected = false;
      _linkStateController.add(false);
    }
    _targetAddress = null;
  }

  Future<bool> sendPayload(Map<String, dynamic> payload) async {
    final channel = _channel;
    if (!_connected || channel == null) return false;

    try {
      channel.sink.add(jsonEncode(payload));
      return true;
    } catch (_) {
      await disconnect();
      return false;
    }
  }

  Future<void> dispose() async {
    await disconnect();
  }

  Uri? _normalizeTarget(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    Uri? uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme != 'ws' && uri.scheme != 'wss') return null;
      if (uri.host.isEmpty) return null;
      return uri.hasPort ? uri : uri.replace(port: 8765);
    }

    uri = Uri.tryParse('ws://$value');
    if (uri == null || uri.host.isEmpty) return null;
    return uri.hasPort ? uri : uri.replace(port: 8765);
  }

  void _handleMessage(dynamic data) {
    if (data is! String) return;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        _statusController.add(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      // Ignore malformed payloads for now.
    }
  }

  void _handleDisconnect() {
    if (!_connected) return;
    _connected = false;
    _targetAddress = null;
    _linkStateController.add(false);
    _statusController.add(const {'cmd': 'stop'});
  }
}
