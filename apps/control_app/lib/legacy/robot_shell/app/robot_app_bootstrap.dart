import '../../../services/android_gamepad_service_adapter.dart';
import '../../../services/bluetooth_controller_link_service_adapter.dart';
import '../../../services/openbene_camera_service_adapter.dart';
import '../../../services/openbene_robot_connection_adapter.dart';

class RobotAppBootstrap {
  RobotAppBootstrap({
    OpenBeneCameraServiceAdapter? cameraService,
    BluetoothControllerLinkServiceAdapter? networkService,
    OpenBeneRobotConnectionAdapter? robotConnectionService,
    AndroidGamepadServiceAdapter? gamepadService,
  })  : cameraService = cameraService ?? OpenBeneCameraServiceAdapter(),
        networkService = networkService ?? BluetoothControllerLinkServiceAdapter(),
        robotConnectionService = robotConnectionService ?? OpenBeneRobotConnectionAdapter(),
        gamepadService = gamepadService ?? AndroidGamepadServiceAdapter();

  final OpenBeneCameraServiceAdapter cameraService;
  final BluetoothControllerLinkServiceAdapter networkService;
  final OpenBeneRobotConnectionAdapter robotConnectionService;
  final AndroidGamepadServiceAdapter gamepadService;

  Future<void> initialize() async {
    await networkService.initialize();
    await networkService.startServer();
    await gamepadService.initialize();
    await robotConnectionService.initialize();
    await cameraService.initialize();
  }

  Future<void> dispose() async {
    await cameraService.dispose();
    await networkService.stopServer();
    await gamepadService.dispose();
    await robotConnectionService.disconnect();
  }
}
