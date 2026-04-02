import 'package:camera/camera.dart';

import 'camera_stream_service.dart';

class OpenBeneCameraServiceAdapter implements CameraStreamService {
  CameraController? controller;

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
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller!.initialize();
  }

  @override
  Future<void> start() async {
    // TODO: migrate OpenBene image stream pipeline and frame transport.
  }

  @override
  Future<void> stop() async {
    if (controller != null && controller!.value.isStreamingImages) {
      await controller!.stopImageStream();
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await controller?.dispose();
    controller = null;
  }
}
