import '../services/android_gamepad_service_adapter.dart';
import '../services/bluetooth_robot_link_service_adapter.dart';
import '../services/openbene_camera_service_adapter.dart';
import '../services/openbene_robot_connection_adapter.dart';

class ControllerModeBootstrap {
  ControllerModeBootstrap({
    OpenBeneCameraServiceAdapter? cameraService,
    OpenBeneRobotConnectionAdapter? robotConnectionService,
    AndroidGamepadServiceAdapter? gamepadService,
    BluetoothRobotLinkServiceAdapter? linkService,
  })  : cameraService = cameraService ?? OpenBeneCameraServiceAdapter(),
        robotConnectionService =
            robotConnectionService ?? OpenBeneRobotConnectionAdapter(),
        gamepadService = gamepadService ?? AndroidGamepadServiceAdapter(),
        linkService = linkService ?? BluetoothRobotLinkServiceAdapter();

  final OpenBeneCameraServiceAdapter cameraService;
  final OpenBeneRobotConnectionAdapter robotConnectionService;
  final AndroidGamepadServiceAdapter gamepadService;
  final BluetoothRobotLinkServiceAdapter linkService;

  Future<void> initializeCore() async {
    await robotConnectionService.initialize();
    await gamepadService.initialize();
    await linkService.initialize();
  }

  Future<void> initializeCamera() async {
    await cameraService.initialize();
  }

  Future<void> dispose() async {
    await cameraService.dispose();
    await gamepadService.dispose();
    await linkService.dispose();
    await robotConnectionService.disconnect();
  }
}
