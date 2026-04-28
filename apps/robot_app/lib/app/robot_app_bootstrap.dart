import '../services/openbene_camera_service_adapter.dart';
import '../services/bluetooth_controller_link_service_adapter.dart';
import '../services/openbene_network_service_adapter.dart';
import '../services/openbene_robot_connection_adapter.dart';
import '../services/android_gamepad_service_adapter.dart';
import '../services/android_robot_backend_service.dart';

class RobotAppBootstrap {
  RobotAppBootstrap({
    OpenBeneCameraServiceAdapter? cameraService,
    BluetoothControllerLinkServiceAdapter? networkService,
    OpenBeneNetworkServiceAdapter? pcLinkService,
    OpenBeneRobotConnectionAdapter? robotConnectionService,
    AndroidGamepadServiceAdapter? gamepadService,
    AndroidRobotBackendService? backendService,
  })  : cameraService = cameraService ?? OpenBeneCameraServiceAdapter(),
        networkService = networkService ?? BluetoothControllerLinkServiceAdapter(),
        pcLinkService = pcLinkService ?? OpenBeneNetworkServiceAdapter(),
        robotConnectionService = robotConnectionService ?? OpenBeneRobotConnectionAdapter(),
        gamepadService = gamepadService ?? AndroidGamepadServiceAdapter(),
        backendService = backendService ?? AndroidRobotBackendService();

  final OpenBeneCameraServiceAdapter cameraService;
  final BluetoothControllerLinkServiceAdapter networkService;
  final OpenBeneNetworkServiceAdapter pcLinkService;
  final OpenBeneRobotConnectionAdapter robotConnectionService;
  final AndroidGamepadServiceAdapter gamepadService;
  final AndroidRobotBackendService backendService;

  Future<void> initialize() async {
    await networkService.initialize();
    await networkService.startServer();
    await pcLinkService.initialize();
    await pcLinkService.startServer();
    await gamepadService.initialize();
    await robotConnectionService.initialize();
    await backendService.initialize();
    await cameraService.initialize();
  }

  Future<void> dispose() async {
    await cameraService.dispose();
    await backendService.dispose();
    await networkService.stopServer();
    await pcLinkService.stopServer();
    await gamepadService.dispose();
    await robotConnectionService.disconnect();
  }
}
