import 'package:camera/camera.dart';

import 'camera_stream_service.dart';
import 'robot_backend_service.dart';

class OpenBeneCameraServiceAdapter implements CameraStreamService {
  @override
  CameraController? controller;

  RobotBackendService? _backendService;
  bool _backendStreaming = false;

  @override
  Future<void> initialize() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    controller = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller!.initialize();
  }

  @override
  Future<void> startPreview() async {
    if (controller == null) return;
    if (!controller!.value.isInitialized) {
      await controller!.initialize();
    }
  }

  @override
  Future<void> stopPreview() async {
    await stopBackendStream();
  }

  @override
  Future<void> startBackendStream(RobotBackendService backendService) async {
    if (controller == null || _backendStreaming) return;
    _backendService = backendService;
    await controller!.startImageStream((frame) async {
      final service = _backendService;
      if (service == null) return;
      final planes = frame.planes
          .map(
            (plane) => RobotBackendFramePlane(
              bytes: plane.bytes,
              bytesPerRow: plane.bytesPerRow,
              bytesPerPixel: plane.bytesPerPixel,
              width: plane.width,
              height: plane.height,
            ),
          )
          .toList(growable: false);
      await service.submitCameraFrame(
        width: frame.width,
        height: frame.height,
        sensorOrientation: controller!.description.sensorOrientation,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        planes: planes,
      );
    });
    _backendStreaming = true;
  }

  @override
  Future<void> stopBackendStream() async {
    _backendService = null;
    if (controller != null && controller!.value.isStreamingImages) {
      await controller!.stopImageStream();
    }
    _backendStreaming = false;
  }

  @override
  Future<void> dispose() async {
    await stopBackendStream();
    await controller?.dispose();
    controller = null;
  }
}
