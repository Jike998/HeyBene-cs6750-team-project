import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'robot_network_service.dart';

class OpenBeneNetworkServiceAdapter implements RobotNetworkService {
  HttpServer? _server;
  WebSocket? _client;
  final int _port = 8765;
  String? _lastClientAddress;
  final StreamController<Map<String, dynamic>> _commandController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _linkStateController =
      StreamController<bool>.broadcast();

  @override
  bool get isRunning => _server != null;

  @override
  int get port => _port;

  @override
  String? get lastClientAddress => _lastClientAddress;

  @override
  bool get controllerConnected => _client != null;

  @override
  Stream<Map<String, dynamic>> get commandStream => _commandController.stream;

  @override
  Stream<bool> get linkStateStream => _linkStateController.stream;

  @override
  Future<void> initialize() async {
    // Placeholder for future discovery and connection-state stream migration.
    // The current minimal protocol uses a single WebSocket client and JSON payloads.
  }

  @override
  Future<void> startServer() async {
    if (_server != null) return;

    _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
    _server!.listen((request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'status': 'ok',
          'service': 'robot_app',
          'port': _port,
        }));
        await request.response.close();
        return;
      }

      final socket = await WebSocketTransformer.upgrade(request);
      await _client?.close();
      _client = socket;
      _lastClientAddress = request.connectionInfo?.remoteAddress.address;
      _linkStateController.add(true);
      socket.listen(
        (data) {
          if (data is! String) return;
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map<String, dynamic>) {
              _commandController.add(decoded);
            }
          } catch (_) {
            // Ignore malformed controller payloads for now.
          }
        },
        onDone: () {
          _client = null;
          _lastClientAddress = null;
          _linkStateController.add(false);
        },
        onError: (_) {
          _client = null;
          _lastClientAddress = null;
          _linkStateController.add(false);
        },
      );
    });
  }

  @override
  Future<void> sendStatus(Map<String, dynamic> payload) async {
    if (_client == null) return;
    _client!.add(jsonEncode(payload));
  }

  @override
  Future<void> stopServer() async {
    await _client?.close();
    _client = null;
    _lastClientAddress = null;
    _linkStateController.add(false);
    await _server?.close(force: true);
    _server = null;
  }
}
