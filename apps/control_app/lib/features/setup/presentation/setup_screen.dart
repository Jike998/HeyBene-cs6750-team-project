import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../connection/presentation/robot_connection_controller.dart';
import '../../robot_camera/state/robot_camera_controller.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final connectionController = context.watch<RobotConnectionController>();
    final cameraController = context.watch<RobotCameraController>();
    final snapshot = connectionController.snapshot;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Robot App',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'This app runs on the robot phone. It manages camera, robot connection, Drive / Auto / Track modes, telemetry, tracking, and data collection.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                _SetupItem(
                  title: 'USB / BLE bridge',
                  subtitle: snapshot.usbConnected
                      ? 'USB bridge connected and ready'
                      : snapshot.bluetoothConnected
                          ? 'Bluetooth bridge connected and ready'
                          : 'Robot bridge not connected yet',
                ),
                _SetupItem(
                  title: 'Camera and telemetry',
                  subtitle: cameraController.initialized
                      ? 'Camera bootstrap initialized'
                      : cameraController.initializationError ?? 'Camera bootstrap starting',
                ),
                _SetupItem(
                  title: 'Network server',
                  subtitle: snapshot.videoStable
                      ? 'Robot server running and ready for controller connection'
                      : 'Robot server not running yet',
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: connectionController.connectBle,
                        child: const Text('Use BLE'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: connectionController.connectUsb,
                        child: const Text('Use USB'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onContinue,
                    child: const Text('Enter Robot Camera'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupItem extends StatelessWidget {
  const _SetupItem({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}
