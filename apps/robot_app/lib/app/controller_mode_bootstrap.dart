import '../services/android_gamepad_service_adapter.dart';
import '../services/bluetooth_robot_link_service_adapter.dart';
import '../services/openbene_camera_service_adapter.dart';
import '../services/websocket_robot_link_service_adapter.dart';

class ControllerModeBootstrap {
  ControllerModeBootstrap({
    OpenBeneCameraServiceAdapter? cameraService,
    AndroidGamepadServiceAdapter? gamepadService,
    BluetoothRobotLinkServiceAdapter? linkService,
    WebSocketRobotLinkServiceAdapter? webSocketLinkService,
  })  : cameraService = cameraService ?? OpenBeneCameraServiceAdapter(),
        gamepadService = gamepadService ?? AndroidGamepadServiceAdapter(),
        linkService = linkService ?? BluetoothRobotLinkServiceAdapter(),
        webSocketLinkService =
            webSocketLinkService ?? WebSocketRobotLinkServiceAdapter();

  final OpenBeneCameraServiceAdapter cameraService;
  final AndroidGamepadServiceAdapter gamepadService;
  final BluetoothRobotLinkServiceAdapter linkService;
  final WebSocketRobotLinkServiceAdapter webSocketLinkService;

  Future<void> initializeCore() async {
    await gamepadService.initialize();
    await linkService.initialize();
    await webSocketLinkService.initialize();
  }

  Future<void> initializeCamera() async {
    await cameraService.initialize();
  }

  Future<void> dispose() async {
    await cameraService.dispose();
    await gamepadService.dispose();
    await linkService.dispose();
    await webSocketLinkService.dispose();
  }
}
