import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/fusion_surface_tokens.dart';
import '../../../services/robot_backend_service.dart';
import '../../connection/presentation/robot_connection_controller.dart';
import '../../modes/domain/robot_mode.dart';
import '../../telemetry/domain/telemetry_snapshot.dart';
import '../state/robot_camera_controller.dart';
import '../state/robot_camera_state.dart';


class RobotCameraScreen extends StatefulWidget {
  const RobotCameraScreen({
    super.key,
    required this.onOpenControllerMode,
  });

  final Future<void> Function() onOpenControllerMode;

  @override
  State<RobotCameraScreen> createState() => _RobotCameraScreenState();
}

class _RobotCameraScreenState extends State<RobotCameraScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _modeFx;
  RobotMode _transitionMode = RobotMode.drive;
  bool _showModeLabel = false;
  Timer? _hideLabelTimer;

  @override
  void initState() {
    super.initState();
    _modeFx = AnimationController(vsync: this, lowerBound: 0, upperBound: 1, duration: const Duration(milliseconds: 520));
  }

  @override
  void dispose() {
    _hideLabelTimer?.cancel();
    _modeFx.dispose();
    super.dispose();
  }

  void _handleModeDragProgress(double progress) {
    _hideLabelTimer?.cancel();
    _showModeLabel = false;
    _modeFx.value = progress.clamp(0.0, 1.0);
  }

  void _handleModeCommitted(RobotMode mode) {
    final controller = context.read<RobotCameraController>();
    unawaited(controller.applyModeFromUi(mode));
    _transitionMode = mode;
    _showModeLabel = true;
    _modeFx.value = 1;
    _modeFx.animateTo(0, curve: Curves.easeOutCubic);

    _hideLabelTimer?.cancel();
    _hideLabelTimer = Timer(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      setState(() => _showModeLabel = false);
    });

    setState(() {});
  }

  void _handleModeDragEnd() {
    if (_showModeLabel) return;
    _modeFx.animateTo(0, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final connectionController = context.watch<RobotConnectionController>();
    final cameraController = context.watch<RobotCameraController>();

    return Consumer<RobotCameraState>(
      builder: (context, state, child) {
        final connection = connectionController.snapshot;
        final liveCameraController = cameraController.bootstrap.cameraService.controller;
        final cameraReady = liveCameraController != null && liveCameraController.value.isInitialized;
        final shouldShowLivePreview = state.isRunning && cameraReady;

        if (_transitionMode != state.mode && _modeFx.value == 0) {
          _transitionMode = state.mode;
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(
                child: shouldShowLivePreview
                    ? _LiveCameraFeed(controller: liveCameraController)
                    : const _BackgroundFeed(),
              ),
              const Positioned.fill(child: _FeedOverlay()),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _modeFx,
                    builder: (context, child) {
                      return _ModeTransitionFeedback(
                        mode: _transitionMode,
                        progress: _modeFx.value,
                        showLabel: _showModeLabel,
                      );
                    },
                  ),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: null,
                  child: const SizedBox.expand(),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    Positioned(
                      top: 4,
                      left: 10,
                      right: 10,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TelemetryTray(
                            state: state,
                            connection: connection,
                            initialized: cameraController.initialized,
                            onOpenControllerMode: widget.onOpenControllerMode,
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _TopRoleIconButton(
                              icon: Icons.sports_esports_rounded,
                              onPressed: () {
                                unawaited(widget.onOpenControllerMode());
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (state.mode == RobotMode.track && state.isRunning && state.trackingBox != null)
                      Positioned.fill(
                        child: _TrackOverlay(
                          box: state.trackingBox!,
                          label: state.trackingLabel ?? state.trackTargetType.name,
                        ),
                      ),
                  ],
                ),
              ),
              _BottomControls(
                state: state,
                cameraController: cameraController,
                onModeDragProgress: _handleModeDragProgress,
                onModeCommitted: _handleModeCommitted,
                onModeDragEnd: _handleModeDragEnd,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BackgroundFeed extends StatelessWidget {
  const _BackgroundFeed();

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.orientationOf(context);
    return Image.asset(
      orientation == Orientation.portrait
          ? 'assets/images/robot.png'
          : 'assets/images/robot2.png',
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );
  }
}

class _LiveCameraFeed extends StatelessWidget {
  const _LiveCameraFeed({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (!controller.value.isInitialized || previewSize == null) {
      return const _BackgroundFeed();
    }

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewSize.height,
            height: previewSize.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _FeedOverlay extends StatelessWidget {
  const _FeedOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(255, 255, 255, 0.05),
            Color.fromRGBO(232, 238, 246, 0.015),
            Color.fromRGBO(173, 187, 203, 0.06),
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
              Colors.white.withValues(alpha: 0.04),
              Colors.transparent,
              FusionSurfaceTokens.accentSoft.withValues(alpha: 0.35),
            ],
            stops: const [0, 0.56, 1],
          ),
        ),
      ),
    );
  }
}

class _ModeTransitionFeedback extends StatelessWidget {
  const _ModeTransitionFeedback({
    required this.mode,
    required this.progress,
    required this.showLabel,
  });

  final RobotMode mode;
  final double progress;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final label = switch (mode) {
      RobotMode.auto => 'AUTO',
      RobotMode.drive => 'DRIVE',
      RobotMode.track => 'TRACK',
    };

    final t = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final blur = lerpDouble(0, 18, t)!;
    final veil = lerpDouble(0, 0.16, t)!;

    final labelOpacity = showLabel ? (1 - t).clamp(0.0, 1.0) : 0.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (progress > 0)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(color: Colors.black.withValues(alpha: veil)),
          ),
        if (showLabel)
          Center(
            child: Opacity(
              opacity: labelOpacity,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: FusionSurfaceTokens.chromeFill,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: FusionSurfaceTokens.chromeBorderSoft),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: FusionSurfaceTokens.textPrimary.withValues(alpha: 0.92),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TelemetryTray extends StatefulWidget {
  const _TelemetryTray({
    required this.state,
    required this.connection,
    required this.initialized,
    required this.onOpenControllerMode,
  });

  final RobotCameraState state;
  final dynamic connection;
  final bool initialized;
  final Future<void> Function() onOpenControllerMode;

  @override
  State<_TelemetryTray> createState() => _TelemetryTrayState();
}

class _TelemetryTrayState extends State<_TelemetryTray> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.state.telemetry;
    final modeMetric = _modeMetric(telemetry);

    return Padding(
      padding: EdgeInsets.zero,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: _expanded ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: FusionSurfaceTokens.chromeBorderSoft),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: _expanded ? 256 : 214,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: FusionSurfaceTokens.chromeFillStrong,
                        border: Border.all(color: FusionSurfaceTokens.chromeBorderSoft),
                        boxShadow: const [
                          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.24), blurRadius: 24, offset: Offset(0, 12)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                            child: Row(
                              children: [
                                _ConnectionGlyph(icon: Icons.bluetooth_rounded, connected: widget.connection.bluetoothConnected),
                                const SizedBox(width: 8),
                                _ConnectionGlyph(icon: Icons.usb_rounded, connected: widget.connection.usbConnected),
                                const SizedBox(width: 10),
                                _BatteryMini(value: telemetry.battery),
                                const Spacer(),
                                _StatusTogglePill(
                                  expanded: _expanded,
                                  onPressed: () => setState(() => _expanded = !_expanded),
                                ),
                              ],
                            ),
                          ),
                          ClipRect(
                            child: Align(
                              alignment: Alignment.topCenter,
                              heightFactor: progress,
                              child: Opacity(
                                opacity: Curves.easeOut.transform(progress),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          _TrayMetric(icon: Icons.schedule_rounded, label: 'PING', value: '${telemetry.latency}ms'),
                                          _divider(),
                                          _TrayMetric(icon: Icons.speed_rounded, label: 'SPEED', value: telemetry.speed.toStringAsFixed(2)),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          _TrayMetric(icon: Icons.motion_photos_on_rounded, label: 'STEERING', value: telemetry.steering.toStringAsFixed(2)),
                                          _divider(),
                                          _TrayMetric(
                                            icon: modeMetric.icon,
                                            label: modeMetric.label,
                                            value: modeMetric.value,
                                          ),
                                        ],
                                      ),
                                      if (widget.state.collecting) ...[
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            _TrayMetric(
                                              icon: Icons.fiber_manual_record_rounded,
                                              label: 'REC',
                                              value: '${widget.state.telemetry.samples}',
                                            ),
                                            _divider(),
                                            _TrayMetric(
                                              icon: Icons.folder_rounded,
                                              label: 'SESSION',
                                              value: widget.state.collectionSessionPath ?? 'Preparing…',
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (widget.state.mode != RobotMode.drive) ...[
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            _TrayMetric(
                                              icon: Icons.memory_rounded,
                                              label: 'BACKEND',
                                              value: widget.state.backendStatus,
                                            ),
                                            _divider(),
                                            _TrayMetric(
                                              icon: Icons.timelapse_rounded,
                                              label: 'INF',
                                              value: '${widget.state.backendLastInferenceMs}ms',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            _TrayMetric(
                                              icon: Icons.turn_left_rounded,
                                              label: 'LEFT',
                                              value: widget.state.backendSuggestedLeft.toStringAsFixed(2),
                                            ),
                                            _divider(),
                                            _TrayMetric(
                                              icon: Icons.turn_right_rounded,
                                              label: 'RIGHT',
                                              value: widget.state.backendSuggestedRight.toStringAsFixed(2),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: FusionSurfaceTokens.chromeBorderSoft,
    );
  }

  ({IconData icon, String label, String value}) _modeMetric(TelemetrySnapshot telemetry) {
    return switch (widget.state.mode) {
      RobotMode.drive => (
          icon: Icons.bolt_rounded,
          label: 'VOLTAGE',
          value: '${telemetry.voltage.toStringAsFixed(1)}V',
        ),
      RobotMode.auto => (
          icon: Icons.gps_fixed_rounded,
          label: 'CONFIDENCE',
          value: '${telemetry.confidence}%',
        ),
      RobotMode.track => (
          icon: Icons.center_focus_strong_rounded,
          label: 'DISTANCE',
          value: '${telemetry.distance.toStringAsFixed(1)}m',
        ),
    };
  }
}

class _StatusTogglePill extends StatelessWidget {
  const _StatusTogglePill({
    required this.expanded,
    required this.onPressed,
  });

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: FusionSurfaceTokens.chromeFill,
          borderRadius: BorderRadius.circular(999),
          border: FusionSurfaceTokens.tokenBorder(),
        ),
        child: Text(
          expanded ? 'Hide' : 'Info',
          style: TextStyle(
            color: FusionSurfaceTokens.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TopRoleIconButton extends StatelessWidget {
  const _TopRoleIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: FusionSurfaceTokens.chromeFill,
          shape: BoxShape.circle,
          border: FusionSurfaceTokens.tokenBorder(),
        ),
        child: Icon(
          icon,
          size: 18,
          color: FusionSurfaceTokens.textPrimary,
        ),
      ),
    );
  }
}

class _ConnectionGlyph extends StatelessWidget {
  const _ConnectionGlyph({required this.icon, required this.connected});

  final IconData icon;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final on = FusionSurfaceTokens.success;
    final off = FusionSurfaceTokens.textTertiary;

    return SizedBox(
      width: 22,
      height: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: 18, color: connected ? on : off),
          if (!connected)
            Positioned.fill(
              child: CustomPaint(
                painter: _SlashPainter(color: off.withValues(alpha: 0.92), strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class _SlashPainter extends CustomPainter {
  const _SlashPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(size.width * 0.18, size.height * 0.92), Offset(size.width * 0.82, size.height * 0.10), p);
  }

  @override
  bool shouldRepaint(covariant _SlashPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

class _BatteryMini extends StatelessWidget {
  const _BatteryMini({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final percent = value.clamp(0, 100);
    final icon = switch (percent) {
      >= 95 => Icons.battery_full_rounded,
      >= 75 => Icons.battery_5_bar_rounded,
      >= 55 => Icons.battery_4_bar_rounded,
      >= 35 => Icons.battery_3_bar_rounded,
      >= 15 => Icons.battery_2_bar_rounded,
      > 0 => Icons.battery_1_bar_rounded,
      _ => Icons.battery_0_bar_rounded,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: FusionSurfaceTokens.textPrimary),
        const SizedBox(width: 4),
        Text(
          '$percent%',
          style: const TextStyle(color: FusionSurfaceTokens.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _TrayMetric extends StatelessWidget {
  const _TrayMetric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: FusionSurfaceTokens.textSecondary),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: FusionSurfaceTokens.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: FusionSurfaceTokens.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.state,
    required this.cameraController,
    required this.onModeDragProgress,
    required this.onModeCommitted,
    required this.onModeDragEnd,
  });

  final RobotCameraState state;
  final RobotCameraController cameraController;
  final ValueChanged<double> onModeDragProgress;
  final ValueChanged<RobotMode> onModeCommitted;
  final VoidCallback onModeDragEnd;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 0, 14, safeBottom > 0 ? 6 : 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SwipeModeSelector(
                state: state,
                onModeDragProgress: onModeDragProgress,
                onModeCommitted: onModeCommitted,
                onModeDragEnd: onModeDragEnd,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 40),
                  _MainActionFab(state: state, cameraController: cameraController),
                  const SizedBox(width: 12),
                  _GearButton(state: state),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeModeSelector extends StatefulWidget {
  const _SwipeModeSelector({
    required this.state,
    required this.onModeDragProgress,
    required this.onModeCommitted,
    required this.onModeDragEnd,
  });

  final RobotCameraState state;
  final ValueChanged<double> onModeDragProgress;
  final ValueChanged<RobotMode> onModeCommitted;
  final VoidCallback onModeDragEnd;

  @override
  State<_SwipeModeSelector> createState() => _SwipeModeSelectorState();
}

class _SwipeModeSelectorState extends State<_SwipeModeSelector> {
  static const _order = <RobotMode>[RobotMode.auto, RobotMode.drive, RobotMode.track];
  static const _labels = <String>['AUTO', 'DRIVE', 'TRACK'];

  double _dragDx = 0;
  double _dragVisualOffset = 0;
  int get _index => _order.indexOf(widget.state.mode);

  int _wrap(int value) {
    final length = _order.length;
    return ((value % length) + length) % length;
  }

  void _setIndex(int nextIndex) {
    final wrapped = _wrap(nextIndex);
    widget.onModeCommitted(_order[wrapped]);
  }

  @override
  Widget build(BuildContext context) {
    final index = _index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 76),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = constraints.maxWidth / 3;
          final stripWidth = slotWidth * 5;
          final maxVisualOffset = slotWidth * 0.5;
          final visualOffset = _dragVisualOffset.clamp(-maxVisualOffset, maxVisualOffset);
          final centeredOffset = constraints.maxWidth / 2 - slotWidth / 2 - slotWidth * 2 + visualOffset;
          final visibleIndexes = [index - 2, index - 1, index, index + 1, index + 2];

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) {
              _dragDx = 0;
            },
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragDx += details.delta.dx;
                _dragVisualOffset = (_dragDx * 0.42).clamp(-maxVisualOffset, maxVisualOffset);
              });
              widget.onModeDragProgress((_dragVisualOffset.abs() / maxVisualOffset).clamp(0.0, 1.0));
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              final dx = _dragDx;
              int nextIndex = index;

              if (velocity.abs() > 280) {
                nextIndex = velocity < 0 ? index + 1 : index - 1;
              } else if (dx.abs() > slotWidth * 0.22) {
                nextIndex = dx < 0 ? index + 1 : index - 1;
              }

              final committedMode = _order[_wrap(nextIndex)];
              widget.onModeCommitted(committedMode);
              setState(() {
                _dragDx = 0;
                _dragVisualOffset = 0;
              });
            },
            onHorizontalDragCancel: () {
              widget.onModeDragEnd();
              setState(() {
                _dragDx = 0;
                _dragVisualOffset = 0;
              });
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 4,
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.10),
                                Colors.white.withValues(alpha: 0.10),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 4,
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.10),
                                Colors.white.withValues(alpha: 0.10),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: centeredOffset, end: centeredOffset),
                        duration: const Duration(milliseconds: 340),
                        curve: Curves.easeOutQuart,
                        builder: (context, animatedOffset, child) {
                          return Positioned(
                            left: animatedOffset,
                            width: stripWidth,
                            top: 0,
                            bottom: 0,
                            child: child!,
                          );
                        },
                        child: Row(
                          children: List.generate(visibleIndexes.length, (visibleI) {
                            final actualIndex = visibleIndexes[visibleI];
                            final wrappedIndex = _wrap(actualIndex);
                            final distance = ((visibleI * slotWidth) + centeredOffset + slotWidth / 2 - constraints.maxWidth / 2).abs() / slotWidth;
                            final emphasis = (1 - distance).clamp(0.0, 1.0);
                            final scale = lerpDouble(0.94, 1.0, emphasis)!;
                            final opacity = lerpDouble(0.18, 1.0, Curves.easeOut.transform(emphasis))!;

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _setIndex(actualIndex),
                              child: SizedBox(
                                width: slotWidth,
                                child: Center(
                                  child: AnimatedScale(
                                    scale: scale,
                                    duration: const Duration(milliseconds: 140),
                                    curve: Curves.easeOut,
                                    child: Opacity(
                                      opacity: opacity,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _labels[wrappedIndex],
                                          maxLines: 1,
                                          softWrap: false,
                                          style: TextStyle(
                                            color: wrappedIndex == index
                                                ? FusionSurfaceTokens.textPrimary
                                                : FusionSurfaceTokens.textTertiary,
                                            fontSize: wrappedIndex == index ? 15 : 12,
                                            fontWeight: wrappedIndex == index ? FontWeight.w800 : FontWeight.w600,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MainActionFab extends StatelessWidget {
  const _MainActionFab({required this.state, required this.cameraController});

  final RobotCameraState state;
  final RobotCameraController cameraController;

  @override
  Widget build(BuildContext context) {
    final active = state.isRunning;
    final startEnabled = state.connection.usbConnected;

    final (icon, label) = switch (state.mode) {
      RobotMode.drive => active
          ? (Icons.stop_rounded, 'STOP')
          : (Icons.play_arrow_rounded, 'START'),
      RobotMode.auto => active
          ? (Icons.stop_rounded, 'STOP AUTO')
          : (Icons.auto_awesome_rounded, 'START AUTO'),
      RobotMode.track => active
          ? (Icons.stop_rounded, 'STOP TRACK')
          : (Icons.center_focus_strong_rounded, 'START TRACK'),
    };

    final gradient = active
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF657D95), Color(0xFF51667E)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF627A92), Color(0xFF4F647A)],
          );

    final shadow = active
        ? const BoxShadow(color: Color.fromRGBO(64, 82, 104, 0.18), blurRadius: 18, offset: Offset(0, 10))
        : const BoxShadow(color: Color.fromRGBO(70, 103, 138, 0.20), blurRadius: 18, offset: Offset(0, 10));

    final canTap = active || startEnabled;

    return GestureDetector(
      onTap: canTap
          ? () {
              if (active) {
                cameraController.stopFromUi();
              } else {
                cameraController.startFromUi();
              }
            }
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: canTap ? 1 : 0.55,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient,
            border: Border.all(color: FusionSurfaceTokens.chromeBorderSoft),
            boxShadow: [
              shadow,
              const BoxShadow(
                color: Color.fromRGBO(255, 255, 255, 0.03),
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: Column(
                key: ValueKey('${state.mode.name}-$active-${state.trackTargetType.name}'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: FusionSurfaceTokens.textPrimary),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: FusionSurfaceTokens.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
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

class _GearButton extends StatelessWidget {
  const _GearButton({required this.state});

  final RobotCameraState state;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) => MultiProvider(
          providers: [
            ChangeNotifierProvider<RobotCameraState>.value(
              value: context.read<RobotCameraState>(),
            ),
            ChangeNotifierProvider<RobotConnectionController>.value(
              value: context.read<RobotConnectionController>(),
            ),
          ],
          child: const _SettingsSheet(),
        ),
      ),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: FusionSurfaceTokens.chromeFill,
          border: FusionSurfaceTokens.tokenBorder(),
        ),
        child: Icon(Icons.settings_rounded, color: FusionSurfaceTokens.textSecondary, size: 22),
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  static const _speedLow = Color(0xFFB7C5D4);
  static const _speedNormal = Color(0xFFEAF4FF);
  static const _speedHigh = Color(0xFFD6E2EE);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RobotCameraState>();
    final connectionController = context.watch<RobotConnectionController>();
    final snapshot = connectionController.snapshot;

    final connectionRows = [
      _SettingsRow(
        label: 'Car USB',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ConnectionActionButton(
              label: 'USB',
              active: snapshot.usbConnected,
              onPressed: snapshot.usbConnected
                  ? connectionController.disconnectUsb
                  : connectionController.connectUsb,
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      _SettingsRow(
        label: 'Controller Links',
        trailing: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ConnectionActionButton(
              label: 'Phone Link',
              active: snapshot.bluetoothConnected,
              onPressed: snapshot.bluetoothConnected
                  ? connectionController.disconnectBluetooth
                  : connectionController.connectBluetooth,
            ),
            _ConnectionActionButton(
              label: snapshot.pcConnected ? 'PC Linked' : 'PC Link',
              active: snapshot.pcConnected,
              onPressed: snapshot.pcConnected
                  ? connectionController.stopPcLink
                  : connectionController.startPcLink,
            ),
          ],
        ),
      ),
      if (snapshot.pcLinkPort != null) ...[
        const SizedBox(height: 10),
        _SettingsRow(
          label: 'PC Status',
          trailing: SizedBox(
            width: 170,
            child: Text(
              snapshot.pcConnected
                  ? 'Client ${snapshot.pcClientAddress ?? 'connected'} · Port ${snapshot.pcLinkPort}'
                  : 'Listening on ${snapshot.pcLinkPort}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: FusionSurfaceTokens.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
      const SizedBox(height: 10),
      _SettingsRow(
        label: 'Car BLE',
        trailing: Text(
          'Unavailable',
          style: TextStyle(
            color: FusionSurfaceTokens.textTertiary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(height: 10),
    ];

    final rows = switch (state.mode) {
      RobotMode.drive => [
          _SettingsRow(
            label: 'Collect data',
            trailing: Switch.adaptive(
              value: state.collecting,
              activeColor: _speedNormal,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: snapshot.usbConnected ? (_) => context.read<RobotCameraController>().toggleCollectingFromUi() : null,
            ),
          ),
          if (state.collectionSessionPath != null) ...[
            const SizedBox(height: 10),
            _SettingsRow(
              label: 'Session',
              trailing: SizedBox(
                width: 170,
                child: Text(
                  state.collectionSessionPath!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: FusionSurfaceTokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _SettingsRow(
            label: 'Controller',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  switch (state.driveController) {
                    DriveControllerType.pc => Icons.computer_rounded,
                    DriveControllerType.gamepad => Icons.sports_esports_rounded,
                    DriveControllerType.phone => Icons.smartphone_rounded,
                    DriveControllerType.none => Icons.remove_circle_outline_rounded,
                  },
                  size: 18,
                  color: FusionSurfaceTokens.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  switch (state.driveController) {
                    DriveControllerType.pc => 'PC',
                    DriveControllerType.gamepad => 'Gamepad',
                    DriveControllerType.phone => 'Phone',
                    DriveControllerType.none => 'None',
                  },
                  style: const TextStyle(
                    color: FusionSurfaceTokens.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SettingsRow(
            label: 'Speed mode',
            trailing: _SettingsPicker<SpeedMode>(
              value: state.driveSpeedMode,
              values: const [SpeedMode.low, SpeedMode.normal, SpeedMode.high],
              labelFor: (v) => switch (v) { SpeedMode.low => 'Low', SpeedMode.normal => 'Normal', SpeedMode.high => 'High' },
              colorFor: (v) => switch (v) { SpeedMode.low => _speedLow, SpeedMode.normal => _speedNormal, SpeedMode.high => _speedHigh },
              onSelected: state.setDriveSpeedMode,
            ),
          ),
        ],
      RobotMode.auto => [
          _SettingsRow(
            label: 'Model',
            trailing: SizedBox(
              width: 170,
              child: Text(
                state.backendModels.firstWhere(
                  (model) => model.id == 'autopilot_float',
                  orElse: () => const RobotBackendModel(
                    id: 'autopilot_float',
                    label: 'OpenBot Autopilot',
                    kind: RobotBackendModelKind.autopilot,
                    source: 'asset',
                    inputWidth: 256,
                    inputHeight: 96,
                  ),
                ).label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: FusionSurfaceTokens.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsRow(
            label: 'Device',
            trailing: _SettingsPicker<ComputeDevice>(
              value: state.autoDevice,
              values: const [ComputeDevice.cpu, ComputeDevice.gpu, ComputeDevice.nnapi],
              labelFor: (v) => switch (v) { ComputeDevice.cpu => 'CPU', ComputeDevice.gpu => 'GPU', ComputeDevice.nnapi => 'NNAPI' },
              iconFor: (v) => switch (v) { ComputeDevice.cpu => Icons.memory_rounded, ComputeDevice.gpu => Icons.graphic_eq_rounded, ComputeDevice.nnapi => Icons.bolt_rounded },
              onSelected: state.setAutoDevice,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsRow(
            label: 'Speed mode',
            trailing: _SettingsPicker<SpeedMode>(
              value: state.autoSpeedMode,
              values: const [SpeedMode.low, SpeedMode.normal, SpeedMode.high],
              labelFor: (v) => switch (v) { SpeedMode.low => 'Low', SpeedMode.normal => 'Normal', SpeedMode.high => 'High' },
              colorFor: (v) => switch (v) { SpeedMode.low => _speedLow, SpeedMode.normal => _speedNormal, SpeedMode.high => _speedHigh },
              onSelected: state.setAutoSpeedMode,
            ),
          ),
        ],
      RobotMode.track => [
          _SettingsRow(
            label: 'Model',
            trailing: SizedBox(
              width: 170,
              child: Text(
                state.backendModels.firstWhere(
                  (model) => model.id == 'ssd_mobilenet_v1',
                  orElse: () => const RobotBackendModel(
                    id: 'ssd_mobilenet_v1',
                    label: 'SSD MobileNet V1',
                    kind: RobotBackendModelKind.detector,
                    source: 'asset',
                    inputWidth: 300,
                    inputHeight: 300,
                  ),
                ).label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: FusionSurfaceTokens.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsRow(
            label: 'Target type',
            trailing: _SettingsPicker<TrackTargetType>(
              value: state.trackTargetType,
              values: const [
                TrackTargetType.person,
                TrackTargetType.dog,
                TrackTargetType.cat,
                TrackTargetType.bicycle,
                TrackTargetType.car,
                TrackTargetType.banana,
              ],
              labelFor: (v) => switch (v) {
                TrackTargetType.person => 'Person',
                TrackTargetType.dog => 'Dog',
                TrackTargetType.cat => 'Cat',
                TrackTargetType.bicycle => 'Bicycle',
                TrackTargetType.car => 'Car',
                TrackTargetType.banana => 'Banana',
              },
              iconFor: (v) => switch (v) {
                TrackTargetType.person => Icons.person_rounded,
                TrackTargetType.dog => Icons.pets_rounded,
                TrackTargetType.cat => Icons.pets_rounded,
                TrackTargetType.bicycle => Icons.directions_bike_rounded,
                TrackTargetType.car => Icons.directions_car_rounded,
                TrackTargetType.banana => Icons.local_grocery_store_rounded,
              },
              onSelected: state.setTrackTargetType,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsRow(
            label: 'Device',
            trailing: _SettingsPicker<ComputeDevice>(
              value: state.trackDevice,
              values: const [ComputeDevice.cpu, ComputeDevice.gpu, ComputeDevice.nnapi],
              labelFor: (v) => switch (v) { ComputeDevice.cpu => 'CPU', ComputeDevice.gpu => 'GPU', ComputeDevice.nnapi => 'NNAPI' },
              iconFor: (v) => switch (v) { ComputeDevice.cpu => Icons.memory_rounded, ComputeDevice.gpu => Icons.graphic_eq_rounded, ComputeDevice.nnapi => Icons.bolt_rounded },
              onSelected: state.setTrackDevice,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsRow(
            label: 'Speed mode',
            trailing: _SettingsPicker<SpeedMode>(
              value: state.trackSpeedMode,
              values: const [SpeedMode.low, SpeedMode.normal, SpeedMode.high],
              labelFor: (v) => switch (v) { SpeedMode.low => 'Low', SpeedMode.normal => 'Normal', SpeedMode.high => 'High' },
              colorFor: (v) => switch (v) { SpeedMode.low => _speedLow, SpeedMode.normal => _speedNormal, SpeedMode.high => _speedHigh },
              onSelected: state.setTrackSpeedMode,
            ),
          ),
        ],
    };

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              decoration: BoxDecoration(
                color: FusionSurfaceTokens.chromeFillStrong,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: FusionSurfaceTokens.chromeBorderSoft),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: FusionSurfaceTokens.textSecondary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    switch (state.mode) { RobotMode.drive => 'Drive settings', RobotMode.auto => 'Auto settings', RobotMode.track => 'Track settings' },
                    style: const TextStyle(color: FusionSurfaceTokens.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Connection',
                    style: TextStyle(color: FusionSurfaceTokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 10),
                  ...connectionRows,
                  const SizedBox(height: 18),
                  const Text(
                    'Settings',
                    style: TextStyle(color: FusionSurfaceTokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 10),
                  ...rows,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.trailing});

  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: FusionSurfaceTokens.chromeFillStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FusionSurfaceTokens.chromeBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: FusionSurfaceTokens.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _ConnectionActionButton extends StatelessWidget {
  const _ConnectionActionButton({
    required this.label,
    required this.active,
    required this.onPressed,
  });

  final String label;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = active ? FusionSurfaceTokens.textPrimary : FusionSurfaceTokens.textSecondary;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: onPressed == null ? FusionSurfaceTokens.textTertiary : color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SettingsPicker<T> extends StatelessWidget {
  const _SettingsPicker({
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onSelected,
    this.iconFor,
    this.colorFor,
  });

  final T value;
  final List<T> values;
  final String Function(T v) labelFor;
  final IconData Function(T v)? iconFor;
  final Color Function(T v)? colorFor;
  final ValueChanged<T> onSelected;

  static const _menuColor = Color.fromRGBO(20, 26, 36, 0.94);

  @override
  Widget build(BuildContext context) {
    final label = labelFor(value);
    final color = colorFor?.call(value);
    final icon = iconFor?.call(value);

    return Builder(
      builder: (buttonContext) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final overlay = Overlay.of(buttonContext).context.findRenderObject() as RenderBox;
            final box = buttonContext.findRenderObject() as RenderBox;
            final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
            final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, box.size.width, box.size.height);

            final estimatedMenuHeight = values.length * 48.0 + 16.0;
            final spaceBelow = overlay.size.height - rect.bottom;
            final spaceAbove = rect.top;
            final shouldOpenUp = spaceBelow < estimatedMenuHeight && spaceAbove > spaceBelow;

            final anchorRect = shouldOpenUp
                ? Rect.fromLTWH(
                    rect.left,
                    math.max(0, rect.top - estimatedMenuHeight),
                    rect.width,
                    estimatedMenuHeight,
                  )
                : rect;

            final position = RelativeRect.fromRect(anchorRect, Offset.zero & overlay.size);

            final selection = await showMenu<T>(
              context: buttonContext,
              color: _menuColor,
              position: position,
              items: values
                  .map(
                    (v) => PopupMenuItem<T>(
                      value: v,
                      child: Row(
                        children: [
                          if (iconFor != null) ...[
                            Icon(iconFor!(v), size: 18, color: FusionSurfaceTokens.textSecondary),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            labelFor(v),
                            style: TextStyle(
                              color: (colorFor?.call(v)) ?? FusionSurfaceTokens.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            );

            if (selection != null) {
              onSelected(selection);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: FusionSurfaceTokens.textSecondary),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: color ?? FusionSurfaceTokens.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.expand_more_rounded, color: FusionSurfaceTokens.textTertiary, size: 20),
            ],
          ),
        );
      },
    );
  }
}

class _TrackOverlay extends StatelessWidget {
  const _TrackOverlay({required this.box, required this.label});

  final Rect box;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: box.left,
          top: box.top - 40,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: FusionSurfaceTokens.chromeFill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: FusionSurfaceTokens.accentSoft),
            ),
            child: Text(label, style: const TextStyle(color: FusionSurfaceTokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
        Positioned(
          left: box.left,
          top: box.top,
          width: box.width,
          height: box.height,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: FusionSurfaceTokens.accent, width: 2),
              color: FusionSurfaceTokens.accentSoft.withValues(alpha: 0.20),
            ),
            child: Stack(
              children: const [
                _TrackCorner(top: 14, left: 14),
                _TrackCorner(top: 14, right: 14, rightSide: true),
                _TrackCorner(bottom: 14, left: 14, bottomSide: true),
                _TrackCorner(bottom: 14, right: 14, rightSide: true, bottomSide: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackCorner extends StatelessWidget {
  const _TrackCorner({this.top, this.left, this.right, this.bottom, this.rightSide = false, this.bottomSide = false});

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final bool rightSide;
  final bool bottomSide;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: !bottomSide ? BorderSide(color: FusionSurfaceTokens.textPrimary, width: 2) : BorderSide.none,
            left: !rightSide ? BorderSide(color: FusionSurfaceTokens.textPrimary, width: 2) : BorderSide.none,
            right: rightSide ? BorderSide(color: FusionSurfaceTokens.textPrimary, width: 2) : BorderSide.none,
            bottom: bottomSide ? BorderSide(color: FusionSurfaceTokens.textPrimary, width: 2) : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: !rightSide && !bottomSide ? const Radius.circular(14) : Radius.zero,
            topRight: rightSide && !bottomSide ? const Radius.circular(14) : Radius.zero,
            bottomLeft: !rightSide && bottomSide ? const Radius.circular(14) : Radius.zero,
            bottomRight: rightSide && bottomSide ? const Radius.circular(14) : Radius.zero,
          ),
        ),
      ),
    );
  }
}
