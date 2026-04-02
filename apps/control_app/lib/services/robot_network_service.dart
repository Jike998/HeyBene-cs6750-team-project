import 'dart:async';

abstract class RobotNetworkService {
  bool get isRunning;
  int get port;
  String? get lastClientAddress;
  bool get controllerConnected;
  Stream<Map<String, dynamic>> get commandStream;
  Stream<bool> get linkStateStream;

  Future<void> initialize();
  Future<void> startServer();
  Future<void> stopServer();
  Future<void> sendStatus(Map<String, dynamic> payload);
}
