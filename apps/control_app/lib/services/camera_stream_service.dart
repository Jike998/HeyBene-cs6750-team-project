abstract class CameraStreamService {
  Future<void> initialize();
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}
