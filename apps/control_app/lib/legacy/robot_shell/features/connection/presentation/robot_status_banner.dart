import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'robot_connection_controller.dart';
import '../../robot_camera/state/robot_camera_controller.dart';
import '../../robot_camera/state/robot_camera_state.dart';

class RobotStatusBanner extends StatelessWidget {
  const RobotStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final cameraController = context.watch<RobotCameraController>();
    final connectionController = context.watch<RobotConnectionController>();
    final state = context.watch<RobotCameraState>();
    final connection = connectionController.snapshot;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cameraController.initialized ? 'Robot runtime active' : 'Robot runtime booting',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'USB: ${connection.usbConnected ? 'ready' : 'down'} · BLE: ${connection.bluetoothConnected ? 'ready' : 'down'} · Server: ${connection.videoStable ? 'live' : 'down'} · Samples: ${state.telemetry.samples}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
