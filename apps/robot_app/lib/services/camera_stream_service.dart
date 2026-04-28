import 'dart:async';

import 'package:camera/camera.dart';

import 'robot_backend_service.dart';

abstract class CameraStreamService {
  CameraController? get controller;

  Future<void> initialize();
  Future<void> startPreview();
  Future<void> stopPreview();
  Future<void> startBackendStream(RobotBackendService backendService);
  Future<void> stopBackendStream();
  Future<void> dispose();
}
