import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/fusion_surface_tokens.dart';
import '../../../services/bluetooth_robot_link_service_adapter.dart';
import '../domain/control_layout.dart';
import '../domain/control_mode_config.dart';
import '../domain/controller_driving_mode.dart';
import '../state/control_controller.dart';
import '../state/control_state.dart';

class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key, required this.onOpenRobotMode});

  final Future<void> Function() onOpenRobotMode;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ControlState>();
    final controller = context.watch<ControlController>();
    final safePadding = MediaQuery.paddingOf(context);
    final layoutPreset = state.activeLayoutPreset;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _SceneBackground(
            showCamera: state.showCamera,
            showVideoStarting: state.videoStarting,
            remotePreviewBytes: state.remotePreviewBytes,
          ),
          const _SceneOverlay(),
          const _TopScrim(),
          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned(
                  top: 18,
                  left: 18,
                  right: 18,
                  child: _TopBar(
                    state: state,
                    onOpenRobotMode: onOpenRobotMode,
                  ),
                ),
                if (state.initializationError != null)
                  Positioned(
                    top: state.isPortraitLayout ? 126 : 104,
                    left: 18,
                    child: _InfoPill(
                      label: state.initializationError!,
                      tone: _PillTone.warning,
                      compact: true,
                    ),
                  ),
              ],
            ),
          ),
          if (!state.isPortraitLayout)
            Positioned(
              left: 0,
              right: 0,
              bottom: safePadding.bottom + 20,
              child: Center(
                child: _DrivingModeSwitcher(
                  drivingMode: state.drivingMode,
                  onSelected: controller.setDrivingMode,
                ),
              ),
            ),
          if (state.isPortraitLayout)
            Positioned.fill(
              child: _OneHandPortraitSurface(
                steering: state.oneHandSteering,
                throttle: state.oneHandThrottle,
                active: state.oneHandActive,
              ),
            ),
          if (!state.isPortraitLayout)
            Positioned(
              left: 18,
              bottom: safePadding.bottom + 18,
              width: 248,
              height: 142,
              child: Transform.translate(
                offset: layoutPreset.leftClusterOffset.toOffset(),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child:
                      state.layout == ControlLayout.dual
                          ? _DualSteeringPad(
                            key: const ValueKey('dual-left'),
                            value: state.dualSteering,
                            onChanged: (steering) {
                              unawaited(
                                controller.handleDualTouch(
                                  steering: steering,
                                  throttle: state.dualThrottle,
                                ),
                              );
                            },
                          )
                          : _ArrowSteeringCluster(
                            key: const ValueKey('arrow-left'),
                            steering: state.arrowSteering,
                            leftPressed: state.arrowLeftPressed,
                            rightPressed: state.arrowRightPressed,
                            onChanged: (steering, leftPressed, rightPressed) {
                              unawaited(
                                controller.handleArrowTouch(
                                  steering: steering,
                                  throttle: state.arrowThrottle,
                                  leftPressed: leftPressed,
                                  rightPressed: rightPressed,
                                  goPressed: state.goPressed,
                                  stopPressed: state.stopPressed,
                                ),
                              );
                            },
                          ),
                ),
              ),
            ),
          if (!state.isPortraitLayout)
            Positioned(
              right: 18,
              bottom: safePadding.bottom + 14,
              width: 176,
              height: 194,
              child: Transform.translate(
                offset: layoutPreset.rightClusterOffset.toOffset(),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child:
                      state.layout == ControlLayout.dual
                          ? _DualThrottlePad(
                            key: const ValueKey('dual-right'),
                            value: state.dualThrottle,
                            onChanged: (throttle) {
                              unawaited(
                                controller.handleDualTouch(
                                  steering: state.dualSteering,
                                  throttle: throttle,
                                ),
                              );
                            },
                          )
                          : _PedalCluster(
                            key: const ValueKey('arrow-right'),
                            goPressed: state.goPressed,
                            stopPressed: state.stopPressed,
                            onChanged: (throttle, goPressed, stopPressed) {
                              unawaited(
                                controller.handleArrowTouch(
                                  steering: state.arrowSteering,
                                  throttle: throttle,
                                  leftPressed: state.arrowLeftPressed,
                                  rightPressed: state.arrowRightPressed,
                                  goPressed: goPressed,
                                  stopPressed: stopPressed,
                                ),
                              );
                            },
                          ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SceneBackground extends StatelessWidget {
  const _SceneBackground({
    required this.showCamera,
    required this.showVideoStarting,
    required this.remotePreviewBytes,
  });

  final bool showCamera;
  final bool showVideoStarting;
  final Uint8List? remotePreviewBytes;

  @override
  Widget build(BuildContext context) {
    final previewBytes = remotePreviewBytes;
    if (showCamera && previewBytes != null && previewBytes.isNotEmpty) {
      return Image.memory(
        previewBytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    if (showVideoStarting) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(context),
          const Center(
            child: _InfoPill(
              label: 'Video starting',
              tone: _PillTone.neutral,
              compact: true,
            ),
          ),
        ],
      );
    }

    return _buildBackground(context);
  }

  Widget _buildBackground(BuildContext context) {
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          isPortrait
              ? 'assets/images/controller2.png'
              : 'assets/images/control.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        if (isPortrait)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromRGBO(7, 10, 16, 0.26),
                  Color.fromRGBO(7, 10, 16, 0.12),
                  Color.fromRGBO(7, 10, 16, 0.32),
                ],
                stops: [0, 0.34, 1],
              ),
            ),
          ),
      ],
    );
  }
}

class _SceneOverlay extends StatelessWidget {
  const _SceneOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(6, 10, 18, 0.18),
            Color.fromRGBO(9, 14, 24, 0.08),
            Color.fromRGBO(8, 12, 22, 0.48),
          ],
          stops: [0, 0.28, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.03),
              Colors.transparent,
              const Color(0xFF66D7FF).withValues(alpha: 0.05),
            ],
            stops: const [0, 0.56, 1],
          ),
        ),
      ),
    );
  }
}

class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 122,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(5, 8, 14, 0.72),
                Color.fromRGBO(5, 8, 14, 0.16),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.onOpenRobotMode});

  final ControlState state;
  final Future<void> Function() onOpenRobotMode;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ControlController>();
    final bluetoothLinked = controller.bluetoothLinked;
    final usbLinked = controller.directUsbConnected;
    final linkActive = bluetoothLinked || usbLinked;
    final latency = state.telemetry.latency;
    final linkLabel = switch ((bluetoothLinked, usbLinked)) {
      (true, _) => 'BT Linked',
      (false, true) => 'USB Linked',
      _ => 'Robot Link',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(
                    label: linkLabel,
                    tone: _PillTone.neutral,
                    compact: true,
                    onTap:
                        state.linkBusy
                            ? null
                            : () {
                              unawaited(
                                _handleRobotLinkTap(context, controller),
                              );
                            },
                  ),
                  _InfoPill(
                    label: linkActive && latency > 0 ? '${latency}ms' : '--',
                    compact: true,
                    tone: _PillTone.neutral,
                  ),
                  _InfoPill(
                    label: state.layout.label,
                    compact: true,
                    tone: _PillTone.neutral,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _TopIconButton(
              icon: Icons.tune_rounded,
              onPressed: () {
                unawaited(_openControllerSettings(context));
              },
            ),
            const SizedBox(width: 8),
            _TopIconButton(
              icon: Icons.smart_toy_rounded,
              onPressed: () {
                unawaited(onOpenRobotMode());
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: _DrivingModeSwitcher(
            drivingMode: state.drivingMode,
            onSelected: controller.setDrivingMode,
          ),
        ),
      ],
    );
  }

  Future<void> _openControllerSettings(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final state = context.read<ControlState>();
    final controller = context.read<ControlController>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<ControlState>.value(value: state),
            ChangeNotifierProvider<ControlController>.value(value: controller),
          ],
          child: const _ControllerSettingsSheet(),
        );
      },
    );
  }

  Future<void> _handleRobotLinkTap(
    BuildContext context,
    ControlController controller,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (controller.bluetoothLinked) {
      await controller.disconnectBluetoothRobotLink();
      return;
    }

    if (controller.directUsbConnected) {
      await controller.toggleDirectUsbLink();
      return;
    }

    final choice = await showModalBottomSheet<_RobotLinkChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _RobotLinkChooserSheet(),
    );
    if (!context.mounted || choice == null) return;

    switch (choice) {
      case _RobotLinkChoice.usb:
        await controller.toggleDirectUsbLink();
        return;
      case _RobotLinkChoice.bluetooth:
        final devices = await controller.getBondedRobotDevices();
        if (!context.mounted || devices.isEmpty) return;

        final address = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => _BondedRobotPicker(devices: devices),
        );
        if (!context.mounted || address == null || address.isEmpty) return;

        await controller.connectBluetoothRobotLink(address);
        return;
    }
  }
}

enum _RobotLinkChoice { bluetooth, usb }

enum _PillTone { good, warning, danger, neutral }

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    required this.tone,
    this.compact = false,
    this.onTap,
  });

  final String label;
  final _PillTone tone;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gradientColors = switch (tone) {
      _PillTone.good => const [Color(0x4C1A212C), Color(0x381A212C)],
      _PillTone.warning => const [Color(0x5A4A3520), Color(0x40322216)],
      _PillTone.danger => const [Color(0x5A4A232B), Color(0x402F181F)],
      _PillTone.neutral => const [Color(0x661A212C), Color(0x4A1A212C)],
    };
    final borderColor = switch (tone) {
      _PillTone.good => FusionSurfaceTokens.chromeBorderSoft,
      _PillTone.warning => const Color(0x36FFF2D9),
      _PillTone.danger => const Color(0x36FFE2E5),
      _PillTone.neutral => FusionSurfaceTokens.chromeBorderSoft,
    };
    final foreground = switch (tone) {
      _PillTone.good => FusionSurfaceTokens.textPrimary,
      _PillTone.warning => const Color(0xFFFFF9EE),
      _PillTone.danger => const Color(0xFFFFF3F5),
      _PillTone.neutral => FusionSurfaceTokens.textPrimary,
    };

    final pill = _GlassPanel(
      borderRadius: BorderRadius.circular(999),
      blurSigma: 22,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: gradientColors,
      ),
      innerGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.03),
          Colors.transparent,
        ],
        stops: const [0, 0.32, 1],
      ),
      borderColor: borderColor,
      boxShadow: const [
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.22),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 8 : 10,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );

    if (onTap == null) return pill;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: pill,
    );
  }
}

class _RobotLinkChooserSheet extends StatelessWidget {
  const _RobotLinkChooserSheet();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, math.max(14, bottomInset + 8)),
        child: _GlassPanel(
          borderRadius: BorderRadius.circular(28),
          blurSigma: 28,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC11161F), Color(0xC4171C26)],
          ),
          innerGradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x18FFFFFF), Color(0x06FFFFFF)],
          ),
          borderColor: const Color(0x34FFFFFF),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.28),
              blurRadius: 26,
              offset: Offset(0, 18),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose Link Type',
                  style: TextStyle(
                    color: Color(0xFFF2F5FF),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Use Bluetooth to connect this controller phone to the robot phone. USB is fallback/debug only.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                _RobotLinkOptionTile(
                  icon: Icons.bluetooth_rounded,
                  title: 'Robot Phone via Bluetooth',
                  subtitle:
                      'Primary remote-control path. Choose a paired Android phone running the robot role.',
                  onTap: () {
                    Navigator.of(context).pop(_RobotLinkChoice.bluetooth);
                  },
                ),
                const SizedBox(height: 10),
                _RobotLinkOptionTile(
                  icon: Icons.usb_rounded,
                  title: 'Direct USB',
                  subtitle:
                      'Fallback/debug path. Connect this controller phone directly to robot hardware through USB.',
                  onTap: () {
                    Navigator.of(context).pop(_RobotLinkChoice.usb);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RobotLinkOptionTile extends StatelessWidget {
  const _RobotLinkOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _GlassPanel(
        borderRadius: BorderRadius.circular(22),
        blurSigma: 18,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x4AFFFFFF), Color(0x18FFFFFF)],
        ),
        innerGradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x16FFFFFF), Color(0x04FFFFFF)],
        ),
        borderColor: const Color(0x2FFFFFFF),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19),
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.92),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFF5F8FF),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.60),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.74),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _BondedRobotPicker extends StatelessWidget {
  const _BondedRobotPicker({required this.devices});

  final List<BondedRobotDevice> devices;

  @override
  Widget build(BuildContext context) {
    final sortedDevices = [...devices]..sort((left, right) {
      final leftLastUsed = left.lastUsed;
      final rightLastUsed = right.lastUsed;
      if (leftLastUsed != rightLastUsed) {
        return leftLastUsed ? -1 : 1;
      }
      final leftName = left.name.toLowerCase();
      final rightName = right.name.toLowerCase();
      return leftName.compareTo(rightName);
    });
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, math.max(14, bottomInset + 8)),
        child: _GlassPanel(
          borderRadius: BorderRadius.circular(28),
          blurSigma: 28,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC11161F), Color(0xC4171C26)],
          ),
          innerGradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x18FFFFFF), Color(0x06FFFFFF)],
          ),
          borderColor: const Color(0x34FFFFFF),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.28),
              blurRadius: 26,
              offset: Offset(0, 18),
            ),
          ],
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose Robot Phone',
                    style: TextStyle(
                      color: Color(0xFFF2F5FF),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select a bonded Android device running robot_app in robot mode.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: sortedDevices.length,
                      separatorBuilder:
                          (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final device = sortedDevices[index];
                        return _BondedRobotTile(
                          name:
                              device.name.trim().isNotEmpty
                                  ? device.name.trim()
                                  : 'Robot phone',
                          address: device.address,
                          lastUsed: device.lastUsed,
                          onTap: () {
                            Navigator.of(context).pop(device.address);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BondedRobotTile extends StatelessWidget {
  const _BondedRobotTile({
    required this.name,
    required this.address,
    required this.lastUsed,
    required this.onTap,
  });

  final String name;
  final String address;
  final bool lastUsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _GlassPanel(
        borderRadius: BorderRadius.circular(22),
        blurSigma: 18,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x4AFFFFFF), Color(0x18FFFFFF)],
        ),
        innerGradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x16FFFFFF), Color(0x04FFFFFF)],
        ),
        borderColor: const Color(0x2FFFFFFF),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF5F8FF),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.60),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (lastUsed) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0x2A8BFFB1),
                  border: Border.all(color: const Color(0x4095FFC0)),
                ),
                child: const Text(
                  'Last',
                  style: TextStyle(
                    color: Color(0xFFDFFFE9),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.74),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrivingModeSwitcher extends StatelessWidget {
  const _DrivingModeSwitcher({
    required this.drivingMode,
    required this.onSelected,
  });

  final ControllerDrivingMode drivingMode;
  final Future<void> Function(ControllerDrivingMode value) onSelected;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.84,
      child: _GlassPanel(
        borderRadius: BorderRadius.circular(20),
        blurSigma: 14,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x321A212C), Color(0x261A212C)],
        ),
        innerGradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x14FFFFFF), Color(0x06FFFFFF)],
        ),
        borderColor: FusionSurfaceTokens.chromeBorderSoft,
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ControllerDrivingMode.values)
              _ModeChip(
                label:
                    mode == ControllerDrivingMode.autoTracking
                        ? 'Auto'
                        : mode.label,
                width: mode == ControllerDrivingMode.autoTracking ? 64 : 72,
                height: 34,
                fontSize: 10,
                active: drivingMode == mode,
                onTap: () {
                  unawaited(onSelected(mode));
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _LayoutSwitcher extends StatelessWidget {
  const _LayoutSwitcher({required this.layout, required this.onSelected});

  final ControlLayout layout;
  final Future<void> Function(ControlLayout value) onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in ControlLayout.values)
          _LayoutChip(
            label: option.label,
            active: layout == option,
            onTap: () {
              unawaited(onSelected(option));
            },
          ),
      ],
    );
  }
}

class _LayoutChip extends StatelessWidget {
  const _LayoutChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 92),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient:
              active
                  ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x26FFFFFF), Color(0x10FFFFFF)],
                  )
                  : const LinearGradient(
                    colors: [Colors.transparent, Colors.transparent],
                  ),
          border: Border.all(
            color:
                active
                    ? const Color(0x40FFFFFF)
                    : FusionSurfaceTokens.chromeBorderSoft,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: FusionSurfaceTokens.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ControllerSettingsSheet extends StatelessWidget {
  const _ControllerSettingsSheet();

  static const _stepX = 12.0;
  static const _stepY = 10.0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ControlState>();
    final controller = context.read<ControlController>();
    final preset = state.activeLayoutPreset;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, math.max(14, bottomInset + 8)),
        child: _GlassPanel(
          borderRadius: BorderRadius.circular(28),
          blurSigma: 28,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: FusionSurfaceTokens.modalGradient,
          ),
          innerGradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: FusionSurfaceTokens.panelInnerGradient,
          ),
          borderColor: FusionSurfaceTokens.chromeBorderSoft,
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.22),
              blurRadius: 26,
              offset: Offset(0, 18),
            ),
          ],
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Controller Settings',
                    style: TextStyle(
                      color: FusionSurfaceTokens.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Layouts and positions are saved per driving mode.',
                    style: const TextStyle(
                      color: FusionSurfaceTokens.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    title: 'Driving Mode',
                    child: _DrivingModeSwitcher(
                      drivingMode: state.drivingMode,
                      onSelected: controller.setDrivingMode,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SettingsSection(
                    title: 'Layout',
                    subtitle:
                        'Controller-only shell presets. They do not change robot runtime mode.',
                    child: _LayoutSwitcher(
                      layout: state.layout,
                      onSelected: controller.setLayout,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SettingsSection(
                    title: 'Control Position',
                    subtitle:
                        'Editing ${state.drivingMode.label} / ${state.layout.label}',
                    child:
                        state.layout == ControlLayout.oneHandedPortrait
                            ? _PositionEditor(
                              title: 'Joystick',
                              offset: preset.centerClusterOffset,
                              onUp: () {
                                controller.nudgeControlPosition(
                                  ControlClusterSide.center,
                                  dx: 0,
                                  dy: -_stepY,
                                );
                              },
                              onLeft: () {
                                controller.nudgeControlPosition(
                                  ControlClusterSide.center,
                                  dx: -_stepX,
                                  dy: 0,
                                );
                              },
                              onRight: () {
                                controller.nudgeControlPosition(
                                  ControlClusterSide.center,
                                  dx: _stepX,
                                  dy: 0,
                                );
                              },
                              onDown: () {
                                controller.nudgeControlPosition(
                                  ControlClusterSide.center,
                                  dx: 0,
                                  dy: _stepY,
                                );
                              },
                              onReset: () {
                                controller.resetControlPosition(
                                  ControlClusterSide.center,
                                );
                              },
                            )
                            : Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _PositionEditor(
                                        title: 'Left Control',
                                        offset: preset.leftClusterOffset,
                                        onUp: () {
                                          controller.nudgeControlPosition(
                                            ControlClusterSide.left,
                                            dx: 0,
                                            dy: -_stepY,
                                          );
                                        },
                                        onLeft: () {
                                          controller.nudgeControlPosition(
                                            ControlClusterSide.left,
                                            dx: -_stepX,
                                            dy: 0,
                                          );
                                        },
                                        onRight: () {
                                          controller.nudgeControlPosition(
                                            ControlClusterSide.left,
                                            dx: _stepX,
                                            dy: 0,
                                          );
                                        },
                                        onDown: () {
                                          controller.nudgeControlPosition(
                                            ControlClusterSide.left,
                                            dx: 0,
                                            dy: _stepY,
                                          );
                                        },
                                        onReset: () {
                                          controller.resetControlPosition(
                                            ControlClusterSide.left,
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _PositionEditor(
                                        title: 'Right Control',
                                        offset: preset.rightClusterOffset,
                                        onUp: () {
                                          controller.nudgeControlPosition(
                                            ControlClusterSide.right,
                                            dx: 0,
                                            dy: -_stepY,
                                          );
                                        },
                                        onLeft: () {
                                          controller.nudgeControlPosition(
                                            ControlClusterSide.right,
                                            dx: -_stepX,
                                            dy: 0,
                                          );
                                        },
                                        onRight: () {
                                          controller.nudgeControlPosition(
                                            ControlClusterSide.right,
                                            dx: _stepX,
                                            dy: 0,
                                          );
                                        },
                                        onDown: () {
                                          controller.nudgeControlPosition(
                                            ControlClusterSide.right,
                                            dx: 0,
                                            dy: _stepY,
                                          );
                                        },
                                        onReset: () {
                                          controller.resetControlPosition(
                                            ControlClusterSide.right,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed:
                                        controller.resetCurrentLayoutPreset,
                                    child: const Text('Reset Both Controls'),
                                  ),
                                ),
                              ],
                            ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: FusionSurfaceTokens.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              color: FusionSurfaceTokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _PositionEditor extends StatelessWidget {
  const _PositionEditor({
    required this.title,
    required this.offset,
    required this.onUp,
    required this.onLeft,
    required this.onRight,
    required this.onDown,
    required this.onReset,
  });

  final String title;
  final ControlClusterOffset offset;
  final VoidCallback onUp;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onDown;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      borderRadius: BorderRadius.circular(22),
      blurSigma: 18,
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x4AFFFFFF), Color(0x18FFFFFF)],
      ),
      innerGradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x16FFFFFF), Color(0x04FFFFFF)],
      ),
      borderColor: const Color(0x2FFFFFFF),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: FusionSurfaceTokens.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'x ${offset.dx.toStringAsFixed(0)} · y ${offset.dy.toStringAsFixed(0)}',
            style: const TextStyle(
              color: FusionSurfaceTokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MiniActionButton(
                icon: Icons.keyboard_arrow_up_rounded,
                onTap: onUp,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MiniActionButton(
                icon: Icons.keyboard_arrow_left_rounded,
                onTap: onLeft,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniActionButton(
                  icon: Icons.restart_alt_rounded,
                  label: 'Reset',
                  onTap: onReset,
                ),
              ),
              const SizedBox(width: 8),
              _MiniActionButton(
                icon: Icons.keyboard_arrow_right_rounded,
                onTap: onRight,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MiniActionButton(
                icon: Icons.keyboard_arrow_down_rounded,
                onTap: onDown,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    required this.onTap,
    this.label,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: label == null ? 10 : 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: FusionSurfaceTokens.chromeFillStrong,
          border: Border.all(color: FusionSurfaceTokens.chromeBorderSoft),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: FusionSurfaceTokens.textPrimary),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: FusionSurfaceTokens.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          color: FusionSurfaceTokens.chromeFillStrong,
          border: Border.all(color: FusionSurfaceTokens.chromeBorderSoft),
        ),
        child: Icon(icon, color: FusionSurfaceTokens.textPrimary, size: 18),
      ),
    );
  }
}

class _OneHandPortraitSurface extends StatelessWidget {
  const _OneHandPortraitSurface({
    required this.steering,
    required this.throttle,
    required this.active,
  });

  final double steering;
  final double throttle;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ControlController>();
    final state = context.watch<ControlState>();
    final safePadding = MediaQuery.paddingOf(context);
    final preset = state.activeLayoutPreset;

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: safePadding.bottom + 24,
          child: Center(
            child: Transform.translate(
              offset: preset.centerClusterOffset.toOffset(),
              child: _OneHandJoystick(
                steering: steering,
                throttle: throttle,
                active: active,
                onChanged: (steering, throttle, active) {
                  unawaited(
                    controller.handleOneHandTouch(
                      steering: steering,
                      throttle: throttle,
                      active: active,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OneHandJoystick extends StatefulWidget {
  const _OneHandJoystick({
    required this.steering,
    required this.throttle,
    required this.active,
    required this.onChanged,
  });

  final double steering;
  final double throttle;
  final bool active;
  final void Function(double steering, double throttle, bool active) onChanged;

  @override
  State<_OneHandJoystick> createState() => _OneHandJoystickState();
}

class _OneHandJoystickState extends State<_OneHandJoystick> {
  static const _radius = 88.0;

  Offset _dragOffset = Offset.zero;
  bool _dragActive = false;

  @override
  void didUpdateWidget(covariant _OneHandJoystick oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragActive) {
      _dragOffset = Offset(
        widget.steering * _radius,
        -widget.throttle * _radius,
      );
    }
  }

  void _updateFromLocal(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rawOffset = localPosition - center;
    final distance = rawOffset.distance;
    final clampedOffset =
        distance <= _radius ? rawOffset : rawOffset / distance * _radius;

    setState(() {
      _dragActive = true;
      _dragOffset = clampedOffset;
    });

    widget.onChanged(
      (clampedOffset.dx / _radius).clamp(-1.0, 1.0),
      (-clampedOffset.dy / _radius).clamp(-1.0, 1.0),
      true,
    );
  }

  void _reset() {
    setState(() {
      _dragActive = false;
      _dragOffset = Offset.zero;
    });
    widget.onChanged(0, 0, false);
  }

  @override
  Widget build(BuildContext context) {
    final intensity = (_dragOffset.distance / _radius).clamp(0.0, 1.0);

    return GestureDetector(
      onPanStart: (details) {
        final box = context.findRenderObject() as RenderBox;
        _updateFromLocal(box.globalToLocal(details.globalPosition), box.size);
      },
      onPanUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        _updateFromLocal(box.globalToLocal(details.globalPosition), box.size);
      },
      onPanEnd: (_) => _reset(),
      onPanCancel: _reset,
      child: SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.18, -0.20),
                  radius: 0.96,
                  colors: [
                    Color.fromRGBO(255, 255, 255, 0.10),
                    Color.fromRGBO(28, 31, 40, 0.64),
                    Color.fromRGBO(10, 12, 18, 0.88),
                  ],
                ),
                border: Border.all(color: FusionSurfaceTokens.chromeBorderSoft),
              ),
            ),
            Container(
              width: 164 + (intensity * 18),
              height: 164 + (intensity * 18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: 0.14 + intensity * 0.18,
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: _dragOffset,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.24, -0.30),
                    colors: [
                      Color.fromRGBO(240, 247, 255, 0.82),
                      Color.fromRGBO(177, 194, 212, 0.62),
                      Color.fromRGBO(59, 69, 86, 0.94),
                    ],
                  ),
                  border: Border.all(
                    color: FusionSurfaceTokens.chromeBorderSoft,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.22),
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.borderRadius,
    required this.gradient,
    required this.borderColor,
    this.child,
    this.innerGradient,
    this.padding = EdgeInsets.zero,
    this.blurSigma = 18,
    this.boxShadow = const [],
  });

  final BorderRadius borderRadius;
  final Gradient gradient;
  final Color borderColor;
  final Widget? child;
  final Gradient? innerGradient;
  final EdgeInsetsGeometry padding;
  final double blurSigma;
  final List<BoxShadow> boxShadow;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor),
            boxShadow: boxShadow,
          ),
          child: Container(
            margin: innerGradient != null ? const EdgeInsets.all(1) : null,
            decoration:
                innerGradient == null
                    ? null
                    : BoxDecoration(
                      borderRadius: borderRadius,
                      gradient: innerGradient,
                    ),
            child:
                child == null ? null : Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.width = 96,
    this.height = 52,
    this.fontSize = 12,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final double width;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient:
              active
                  ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x26FFFFFF), Color(0x10FFFFFF)],
                  )
                  : const LinearGradient(
                    colors: [Colors.transparent, Colors.transparent],
                  ),
          border: active ? Border.all(color: const Color(0x40FFFFFF)) : null,
        ),
        alignment: Alignment.center,
        child: Opacity(
          opacity: active ? 1 : 0.7,
          child: Text(
            label,
            style: TextStyle(
              color: FusionSurfaceTokens.textPrimary,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _DualSteeringPad extends StatelessWidget {
  const _DualSteeringPad({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: _StickPad(
        valueX: value,
        valueY: 0,
        onChanged: (valueX, _) => onChanged(valueX),
      ),
    );
  }
}

class _DualThrottlePad extends StatelessWidget {
  const _DualThrottlePad({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: _StickPad(
        valueX: 0,
        valueY: -value,
        onChanged: (_, valueY) => onChanged((-valueY).clamp(-1.0, 1.0)),
      ),
    );
  }
}

class _StickPad extends StatefulWidget {
  const _StickPad({required this.valueX, required this.valueY, this.onChanged});

  final double valueX;
  final double valueY;
  final void Function(double valueX, double valueY)? onChanged;

  @override
  State<_StickPad> createState() => _StickPadState();
}

class _StickPadState extends State<_StickPad> {
  static const _radius = 40.0;

  void _emit(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final raw = localPosition - center;
    final distance = raw.distance;
    final clamped = distance <= _radius ? raw : raw / distance * _radius;
    widget.onChanged?.call(
      (clamped.dx / _radius).clamp(-1.0, 1.0),
      (clamped.dy / _radius).clamp(-1.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final intensity = math
        .max(widget.valueX.abs(), widget.valueY.abs())
        .clamp(0.0, 1.0);
    final thumbOffset = Offset(widget.valueX * 26, widget.valueY * 26);

    return GestureDetector(
      onPanStart:
          widget.onChanged == null
              ? null
              : (details) {
                final box = context.findRenderObject() as RenderBox;
                _emit(box.globalToLocal(details.globalPosition), box.size);
              },
      onPanUpdate:
          widget.onChanged == null
              ? null
              : (details) {
                final box = context.findRenderObject() as RenderBox;
                _emit(box.globalToLocal(details.globalPosition), box.size);
              },
      onPanEnd:
          widget.onChanged == null ? null : (_) => widget.onChanged?.call(0, 0),
      onPanCancel:
          widget.onChanged == null ? null : () => widget.onChanged?.call(0, 0),
      child: SizedBox(
        width: 126,
        height: 126,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(-0.18, -0.20),
              radius: 0.96,
              colors: [
                Color.fromRGBO(255, 255, 255, 0.14),
                Color.fromRGBO(28, 31, 40, 0.86),
                Color.fromRGBO(10, 12, 18, 0.96),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.32),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 86 + (intensity * 18),
                height: 86 + (intensity * 18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(
                        0xFF8BC6FF,
                      ).withValues(alpha: 0.34 + intensity * 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Container(
                width: 94 + (intensity * 10),
                height: 94 + (intensity * 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: 0.14 + intensity * 0.18,
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: thumbOffset,
                child: Transform.scale(
                  scale: 1 + intensity * 0.14,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        center: Alignment(-0.24, -0.30),
                        colors: [
                          Color.fromRGBO(255, 255, 255, 0.76),
                          Color.fromRGBO(185, 194, 214, 0.66),
                          Color.fromRGBO(64, 70, 84, 0.94),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.28),
                          blurRadius: 14,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrowSteeringCluster extends StatelessWidget {
  const _ArrowSteeringCluster({
    super.key,
    required this.steering,
    required this.leftPressed,
    required this.rightPressed,
    required this.onChanged,
  });

  final double steering;
  final bool leftPressed;
  final bool rightPressed;
  final void Function(double steering, bool leftPressed, bool rightPressed)
  onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: SizedBox(
        width: 224,
        height: 100,
        child: _GlassPanel(
          borderRadius: BorderRadius.circular(38),
          blurSigma: 24,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x72F6ECEF), Color(0x32D1C7CC), Color(0x46E8DDE1)],
          ),
          innerGradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x2EFFFFFF), Color(0x14FFFFFF)],
          ),
          borderColor: const Color(0x60FFFFFF),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.24),
              blurRadius: 24,
              offset: Offset(0, 14),
            ),
          ],
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 12,
                child: _DirectionButton(
                  direction: AxisDirection.left,
                  active: leftPressed,
                  onChanged:
                      (pressed) =>
                          onChanged(pressed ? -1.0 : 0.0, pressed, false),
                ),
              ),
              Positioned(
                right: 12,
                child: _DirectionButton(
                  direction: AxisDirection.right,
                  active: rightPressed,
                  onChanged:
                      (pressed) =>
                          onChanged(pressed ? 1.0 : 0.0, false, pressed),
                ),
              ),
              Container(
                width: 46,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0x08FFFFFF), Color(0x15FFFFFF)],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _trackTick(8, 0.58),
                    _trackTick(6, 0.40),
                    _trackTick(10, 0.62, width: 2),
                    _trackTick(6, 0.40),
                    _trackTick(8, 0.58),
                  ],
                ),
              ),
              Transform.translate(
                offset: Offset(steering * 38, 0),
                child: Transform.rotate(
                  angle: steering * 0.78,
                  child: _SteeringWheelGlyph(
                    size: 34,
                    color: Colors.white.withValues(alpha: 0.96),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trackTick(double height, double opacity, {double width = 1}) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      color: Colors.white.withValues(alpha: opacity),
    );
  }
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({
    required this.direction,
    required this.active,
    required this.onChanged,
  });

  final AxisDirection direction;
  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final gradient =
        active
            ? const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x40FFFFFF), Color(0x1EFFFFFF)],
            )
            : const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x18FFFFFF), Color(0x0BFFFFFF)],
            );

    return GestureDetector(
      onTapDown: (_) => onChanged(true),
      onTapUp: (_) => onChanged(false),
      onTapCancel: () => onChanged(false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: active ? 0.985 : 1,
        child: SizedBox(
          width: 62,
          height: 62,
          child: _GlassPanel(
            borderRadius: BorderRadius.circular(30),
            blurSigma: 18,
            gradient: gradient,
            borderColor:
                active ? const Color(0x50FFFFFF) : const Color(0x2CFFFFFF),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.14),
                blurRadius: 12,
                offset: Offset(0, 8),
              ),
            ],
            child: Center(
              child: Transform.scale(
                scale: active ? 1.06 : 1,
                child: _DoubleChevronGlyph(
                  direction: direction,
                  size: 30,
                  color: Colors.white.withValues(alpha: active ? 0.98 : 0.92),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PedalCluster extends StatelessWidget {
  const _PedalCluster({
    super.key,
    required this.goPressed,
    required this.stopPressed,
    required this.onChanged,
  });

  final bool goPressed;
  final bool stopPressed;
  final void Function(double throttle, bool goPressed, bool stopPressed)
  onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: SizedBox(
        width: 118,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _PedalButton(
              width: 118,
              height: 112,
              active: goPressed,
              label: 'GO',
              tint: const Color(0xFFB9F5C4),
              textTint: const Color(0x7EA8F1B0),
              glyph: const _AccelerateChevronGlyph(),
              borderRadius: BorderRadius.circular(30),
              defaultGradientColors: const [
                Color(0xA794A890),
                Color(0x8E728D79),
                Color(0x73506E57),
              ],
              activeGradientColors: const [
                Color(0xA57E9F88),
                Color(0x7B54745C),
              ],
              defaultBorderColor: const Color(0x64D6F0D2),
              activeBorderColor: const Color(0x7DD9F4D7),
              plateGradientColors: const [Color(0x80C0D4C1), Color(0x46749074)],
              plateBorderColor: const Color(0x54DDF4E2),
              plateBorderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(24),
              ),
              plateWidth: 62,
              plateHeight: 78,
              glyphSize: 50,
              glyphTop: 16,
              labelBottom: 14,
              labelSize: 12,
            ),
            const SizedBox(height: 10),
            _PedalButton(
              width: 92,
              height: 64,
              active: stopPressed,
              label: 'STOP',
              tint: const Color(0xFFF1A2A8),
              textTint: const Color(0x7EF4A0A6),
              glyph: const _BrakeChevronGlyph(),
              borderRadius: BorderRadius.circular(22),
              defaultGradientColors: const [
                Color(0xAA74575A),
                Color(0x965F3F42),
                Color(0x854A292D),
              ],
              activeGradientColors: const [
                Color(0xB0774D4F),
                Color(0x8E5E3034),
              ],
              defaultBorderColor: const Color(0x60F1B9BD),
              activeBorderColor: const Color(0x70F0BCBF),
              plateGradientColors: const [Color(0x736E4346), Color(0x3C6D373B)],
              plateBorderColor: const Color(0x48F0B0B5),
              plateBorderRadius: const BorderRadius.all(Radius.circular(18)),
              plateWidth: 58,
              plateHeight: 42,
              glyphSize: 30,
              glyphTop: 8,
              labelBottom: 6,
              labelSize: 9,
            ),
          ],
        ),
      ),
    );
  }
}

class _PedalButton extends StatelessWidget {
  const _PedalButton({
    required this.width,
    required this.height,
    required this.active,
    required this.label,
    required this.tint,
    required this.textTint,
    required this.glyph,
    required this.borderRadius,
    required this.defaultGradientColors,
    required this.activeGradientColors,
    required this.defaultBorderColor,
    required this.activeBorderColor,
    required this.plateGradientColors,
    required this.plateBorderColor,
    required this.plateBorderRadius,
    required this.plateWidth,
    required this.plateHeight,
    required this.glyphSize,
    required this.glyphTop,
    required this.labelBottom,
    required this.labelSize,
  });

  final double width;
  final double height;
  final bool active;
  final String label;
  final Color tint;
  final Color textTint;
  final Widget glyph;
  final BorderRadius borderRadius;
  final List<Color> defaultGradientColors;
  final List<Color> activeGradientColors;
  final Color defaultBorderColor;
  final Color activeBorderColor;
  final List<Color> plateGradientColors;
  final Color plateBorderColor;
  final BorderRadius plateBorderRadius;
  final double plateWidth;
  final double plateHeight;
  final double glyphSize;
  final double glyphTop;
  final double labelBottom;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    final outerColors = active ? activeGradientColors : defaultGradientColors;

    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: active ? 0.97 : 1,
      child: SizedBox(
        width: width,
        height: height,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: _GlassPanel(
            borderRadius: borderRadius,
            blurSigma: 20,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: outerColors,
            ),
            innerGradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: active ? 0.16 : 0.10),
                Colors.white.withValues(alpha: 0.04),
                Colors.transparent,
              ],
              stops: const [0, 0.24, 1],
            ),
            borderColor: active ? activeBorderColor : defaultBorderColor,
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: active ? 0.18 : 0.08),
                blurRadius: active ? 24 : 18,
                offset: const Offset(0, 10),
              ),
            ],
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 8,
                  left: 12,
                  right: 12,
                  child: IgnorePointer(
                    child: Container(
                      height: height * 0.24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.18),
                            Colors.white.withValues(alpha: 0.02),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: plateWidth,
                  height: plateHeight,
                  decoration: BoxDecoration(
                    borderRadius: plateBorderRadius,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: plateGradientColors,
                    ),
                    border: Border.all(color: plateBorderColor),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: glyphTop),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
                      child: SizedBox(
                        width: glyphSize,
                        height: glyphSize,
                        child: glyph,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: labelBottom,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textTint,
                      fontSize: labelSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.15,
                    ),
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

class _SteeringWheelGlyph extends StatelessWidget {
  const _SteeringWheelGlyph({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SteeringWheelPainter(color: color)),
    );
  }
}

class _SteeringWheelPainter extends CustomPainter {
  const _SteeringWheelPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.09
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final hubPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.082
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final center = size.center(Offset.zero);
    final radius = size.width * 0.40;
    final rimRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rimRect, 0, math.pi * 2, false, strokePaint);

    final topArcRect = Rect.fromCircle(center: center, radius: radius * 0.72);
    canvas.drawArc(topArcRect, math.pi * 1.12, math.pi * 0.76, false, hubPaint);

    final hubPath =
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(
            center.dx - (size.width * 0.18),
            center.dy - (size.height * 0.04),
          )
          ..moveTo(center.dx, center.dy)
          ..lineTo(
            center.dx + (size.width * 0.18),
            center.dy - (size.height * 0.04),
          )
          ..moveTo(center.dx, center.dy)
          ..lineTo(
            center.dx - (size.width * 0.10),
            center.dy + (size.height * 0.23),
          )
          ..moveTo(center.dx, center.dy)
          ..lineTo(
            center.dx + (size.width * 0.10),
            center.dy + (size.height * 0.23),
          );
    canvas.drawPath(hubPath, hubPaint);

    canvas.drawCircle(
      center,
      size.width * 0.07,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _SteeringWheelPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _DoubleChevronGlyph extends StatelessWidget {
  const _DoubleChevronGlyph({
    required this.direction,
    required this.size,
    required this.color,
  });

  final AxisDirection direction;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _DoubleChevronPainter(direction: direction, color: color),
      ),
    );
  }
}

class _DoubleChevronPainter extends CustomPainter {
  const _DoubleChevronPainter({required this.direction, required this.color});

  final AxisDirection direction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);

    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final leadingPath = Path();
    final trailingPath = Path();
    if (direction == AxisDirection.left) {
      leadingPath
        ..moveTo(28, 10)
        ..lineTo(15, 24)
        ..lineTo(28, 38)
        ..lineTo(33, 33)
        ..lineTo(24, 24)
        ..lineTo(33, 15)
        ..close();
      trailingPath
        ..moveTo(17, 10)
        ..lineTo(4, 24)
        ..lineTo(17, 38)
        ..lineTo(22, 33)
        ..lineTo(13, 24)
        ..lineTo(22, 15)
        ..close();
    } else {
      leadingPath
        ..moveTo(20, 10)
        ..lineTo(15, 15)
        ..lineTo(24, 24)
        ..lineTo(15, 33)
        ..lineTo(20, 38)
        ..lineTo(33, 24)
        ..close();
      trailingPath
        ..moveTo(31, 10)
        ..lineTo(26, 15)
        ..lineTo(35, 24)
        ..lineTo(26, 33)
        ..lineTo(31, 38)
        ..lineTo(44, 24)
        ..close();
    }

    canvas.drawPath(leadingPath, paint);
    canvas.drawPath(trailingPath, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DoubleChevronPainter oldDelegate) {
    return oldDelegate.direction != direction || oldDelegate.color != color;
  }
}

class _AccelerateChevronGlyph extends StatelessWidget {
  const _AccelerateChevronGlyph();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _AccelerateChevronPainter());
  }
}

class _AccelerateChevronPainter extends CustomPainter {
  const _AccelerateChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);

    final paints = [
      Paint()
        ..color = Colors.white.withValues(alpha: 0.62)
        ..style = PaintingStyle.fill,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.78)
        ..style = PaintingStyle.fill,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    ];
    final paths = [
      Path()
        ..moveTo(8, 23)
        ..lineTo(15, 16)
        ..lineTo(8, 9)
        ..lineTo(10.8, 6.2)
        ..lineTo(20.6, 16)
        ..lineTo(10.8, 25.8)
        ..close(),
      Path()
        ..moveTo(13, 23)
        ..lineTo(20, 16)
        ..lineTo(13, 9)
        ..lineTo(15.8, 6.2)
        ..lineTo(25.6, 16)
        ..lineTo(15.8, 25.8)
        ..close(),
      Path()
        ..moveTo(18, 23)
        ..lineTo(25, 16)
        ..lineTo(18, 9)
        ..lineTo(20.8, 6.2)
        ..lineTo(30.6, 16)
        ..lineTo(20.8, 25.8)
        ..close(),
    ];

    for (var i = 0; i < paths.length; i++) {
      canvas.drawPath(paths[i], paints[i]);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BrakeChevronGlyph extends StatelessWidget {
  const _BrakeChevronGlyph();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _BrakeChevronPainter());
  }
}

class _BrakeChevronPainter extends CustomPainter {
  const _BrakeChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);

    final paints = [
      Paint()
        ..color = Colors.white.withValues(alpha: 0.48)
        ..style = PaintingStyle.fill,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.72)
        ..style = PaintingStyle.fill,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    ];
    final paths = [
      Path()
        ..moveTo(9, 6.4)
        ..lineTo(16, 13.4)
        ..lineTo(23, 6.4)
        ..lineTo(25.8, 9.2)
        ..lineTo(16, 19)
        ..lineTo(6.2, 9.2)
        ..close(),
      Path()
        ..moveTo(9, 12.4)
        ..lineTo(16, 19.4)
        ..lineTo(23, 12.4)
        ..lineTo(25.8, 15.2)
        ..lineTo(16, 25)
        ..lineTo(6.2, 15.2)
        ..close(),
      Path()
        ..moveTo(9, 18.4)
        ..lineTo(16, 25.4)
        ..lineTo(23, 18.4)
        ..lineTo(25.8, 21.2)
        ..lineTo(16, 31)
        ..lineTo(6.2, 21.2)
        ..close(),
    ];

    for (var i = 0; i < paths.length; i++) {
      canvas.drawPath(paths[i], paints[i]);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
