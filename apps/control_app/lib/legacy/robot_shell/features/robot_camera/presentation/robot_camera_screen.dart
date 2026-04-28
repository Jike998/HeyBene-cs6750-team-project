import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../connection/presentation/robot_connection_controller.dart';
import '../../modes/domain/robot_mode.dart';
import '../state/robot_camera_controller.dart';
import '../state/robot_camera_state.dart';

class RobotCameraScreen extends StatefulWidget {
  const RobotCameraScreen({super.key});

  @override
  State<RobotCameraScreen> createState() => _RobotCameraScreenState();
}

class _RobotCameraScreenState extends State<RobotCameraScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _modeFx;
  RobotMode _transitionMode = RobotMode.drive;
  bool _showModeLabel = false;
  bool _advancedOpen = false;
  Timer? _hideLabelTimer;

  @override
  void initState() {
    super.initState();
    _modeFx = AnimationController(
      vsync: this,
      lowerBound: 0,
      upperBound: 1,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void dispose() {
    _hideLabelTimer?.cancel();
    _modeFx.dispose();
    super.dispose();
  }

  void _animateModeCommit(RobotMode mode) {
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

  void _selectMode(RobotMode mode, RobotCameraState state) {
    if (state.isRunning && mode != state.mode) return;
    if (state.mode != mode) {
      state.setMode(mode);
      _animateModeCommit(mode);
    }
    setState(() {
      _advancedOpen = mode != RobotMode.drive;
    });
  }

  void _toggleAdvanced(RobotCameraState state) {
    if (state.isRunning) return;
    if (_advancedOpen || state.mode != RobotMode.drive) {
      _selectMode(RobotMode.drive, state);
      return;
    }
    setState(() {
      _advancedOpen = true;
    });
  }

  void _openSettingsSheet(BuildContext context, RobotCameraState state) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SettingsSheet(state: state),
    );
  }

  Future<void> _handlePrimaryAction({
    required BuildContext context,
    required RobotConnectionController connectionController,
    required RobotCameraController cameraController,
    required RobotCameraState state,
  }) async {
    if (!cameraController.initialized) {
      return;
    }

    if (!state.connection.usbConnected) {
      await connectionController.connectUsb();
      return;
    }

    switch (state.mode) {
      case RobotMode.drive:
        if (state.isRunning) {
          await cameraController.stopFromUi();
        } else {
          await cameraController.startFromUi();
        }
        return;
      case RobotMode.auto:
        if (state.isRunning) {
          state.stopRobot();
        } else {
          state.startRobot();
        }
        return;
      case RobotMode.track:
        if (state.trackingPoint == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tap the camera view to select a target first.'),
            ),
          );
          return;
        }
        if (state.isRunning) {
          state.stopRobot();
        } else {
          state.startRobot();
        }
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionController = context.watch<RobotConnectionController>();
    final cameraController = context.watch<RobotCameraController>();

    return Consumer<RobotCameraState>(
      builder: (context, state, child) {
        final showAdvanced = _advancedOpen || state.mode != RobotMode.drive;

        if (_transitionMode != state.mode && _modeFx.value == 0) {
          _transitionMode = state.mode;
        }

        return Scaffold(
          backgroundColor: const Color(0xFF05070D),
          body: Stack(
            children: [
              const Positioned.fill(child: _BackgroundFeed()),
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
                  onTapDown: state.mode == RobotMode.track
                      ? (details) => state.setTrackingPoint(details.localPosition)
                      : null,
                  child: const SizedBox.expand(),
                ),
              ),
              if (state.mode == RobotMode.track && state.trackingPoint != null)
                Positioned.fill(
                  child: _TrackOverlay(
                    point: state.trackingPoint!,
                    label: state.trackingStatus,
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RuntimeTopBar(
                        state: state,
                        initialized: cameraController.initialized,
                        onOpenSettings: () => _openSettingsSheet(context, state),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _RuntimeStatusCard(
                          state: state,
                          initialized: cameraController.initialized,
                          advancedOpen: showAdvanced,
                        ),
                      ),
                      const Spacer(),
                      _RuntimeBottomPanel(
                        state: state,
                        initialized: cameraController.initialized,
                        advancedOpen: showAdvanced,
                        onToggleAdvanced: () => _toggleAdvanced(state),
                        onSelectMode: (mode) => _selectMode(mode, state),
                        onPrimaryAction: () => _handlePrimaryAction(
                          context: context,
                          connectionController: connectionController,
                          cameraController: cameraController,
                          state: state,
                        ),
                        onOpenSettings: () => _openSettingsSheet(context, state),
                      ),
                    ],
                  ),
                ),
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
    return Transform.scale(
      scale: 1.08,
      child: Image.asset(
        'assets/images/robot-road-background.jpg',
        fit: BoxFit.cover,
        alignment: Alignment.center,
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
            Color.fromRGBO(6, 10, 18, 0.24),
            Color.fromRGBO(9, 14, 24, 0.10),
            Color.fromRGBO(8, 12, 22, 0.56),
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
              Colors.cyanAccent.withValues(alpha: 0.05),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(16, 20, 30, 0.42),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
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

class _RuntimeTopBar extends StatelessWidget {
  const _RuntimeTopBar({
    required this.state,
    required this.initialized,
    required this.onOpenSettings,
  });

  final RobotCameraState state;
  final bool initialized;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final bridgeHealthy = initialized && state.connection.usbConnected;
    final bridgeLabel = !initialized
        ? 'Starting'
        : bridgeHealthy
            ? 'Bridge Ready'
            : 'Bridge Missing';
    final ownerLabel = _ownerLabel(state);
    final remoteLink = state.connection.bluetoothConnected ? 'Remote Linked' : 'Remote Idle';

    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              const _StatusPill(
                label: 'Robot',
                tone: _PillTone.neutral,
              ),
              const SizedBox(width: 8),
              _StatusPill(
                label: bridgeLabel,
                tone: bridgeHealthy ? _PillTone.good : _PillTone.bad,
              ),
              const Spacer(),
              IconButton(
                onPressed: onOpenSettings,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.tune_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                label: 'Owner: $ownerLabel',
                tone: _PillTone.neutral,
              ),
              _StatusPill(
                label: remoteLink,
                tone: state.connection.bluetoothConnected
                    ? _PillTone.good
                    : _PillTone.neutral,
              ),
              _StatusPill(
                label: '${state.telemetry.battery}% / ${state.telemetry.latency}ms',
                tone: _PillTone.neutral,
              ),
              _StatusPill(
                label: _modeLabel(state.mode),
                tone: _PillTone.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuntimeStatusCard extends StatelessWidget {
  const _RuntimeStatusCard({
    required this.state,
    required this.initialized,
    required this.advancedOpen,
  });

  final RobotCameraState state;
  final bool initialized;
  final bool advancedOpen;

  @override
  Widget build(BuildContext context) {
    final headline = _headline(state, initialized);
    final body = _body(state, initialized, advancedOpen);

    return _GlassPanel(
      width: 258,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuntimeBottomPanel extends StatelessWidget {
  const _RuntimeBottomPanel({
    required this.state,
    required this.initialized,
    required this.advancedOpen,
    required this.onToggleAdvanced,
    required this.onSelectMode,
    required this.onPrimaryAction,
    required this.onOpenSettings,
  });

  final RobotCameraState state;
  final bool initialized;
  final bool advancedOpen;
  final VoidCallback onToggleAdvanced;
  final ValueChanged<RobotMode> onSelectMode;
  final Future<void> Function() onPrimaryAction;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final primaryAction = _primaryActionFor(state, initialized);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (advancedOpen) ...[
          _AdvancedModePanel(
            state: state,
            onSelectMode: onSelectMode,
          ),
          const SizedBox(height: 12),
        ],
        _GlassPanel(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetaBox(
                      label: 'Current Mode',
                      value: _modeLabel(state.mode),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetaBox(
                      label: 'Next Step',
                      value: _nextStepLabel(state, initialized),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: primaryAction.enabled ? onPrimaryAction : null,
                  icon: Icon(primaryAction.icon),
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryAction.background,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        Colors.white.withValues(alpha: 0.10),
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.44),
                    minimumSize: const Size.fromHeight(64),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  label: Text(primaryAction.label),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state.isRunning ? null : onToggleAdvanced,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: Icon(
                        advancedOpen
                            ? Icons.arrow_back_rounded
                            : Icons.widgets_outlined,
                      ),
                      label: Text(
                        advancedOpen ? 'Back To Drive' : 'Advanced Modes',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 52,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: onOpenSettings,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Icon(Icons.settings_rounded, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _footerNote(state, advancedOpen),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdvancedModePanel extends StatelessWidget {
  const _AdvancedModePanel({
    required this.state,
    required this.onSelectMode,
  });

  final RobotCameraState state;
  final ValueChanged<RobotMode> onSelectMode;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Advanced Modes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.isRunning
                ? 'Stop the current run before changing advanced modes.'
                : 'Auto and Track stay secondary until you explicitly choose them.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ModeCard(
                  title: 'Auto',
                  subtitle:
                      '${_autoModelLabel(state.autoModel)} · ${_computeDeviceLabel(state.autoDevice)}',
                  status: state.isRunning && state.mode == RobotMode.auto
                      ? 'Active'
                      : 'Model ready',
                  selected: state.mode == RobotMode.auto,
                  enabled: !state.isRunning || state.mode == RobotMode.auto,
                  onTap: () => onSelectMode(RobotMode.auto),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ModeCard(
                  title: 'Track',
                  subtitle:
                      '${_trackModelLabel(state.trackModel)} · ${_targetTypeLabel(state.trackTargetType)}',
                  status: state.trackingPoint == null
                      ? 'Need target'
                      : state.isRunning && state.mode == RobotMode.track
                          ? 'Active'
                          : 'Target ready',
                  selected: state.mode == RobotMode.track,
                  enabled: !state.isRunning || state.mode == RobotMode.track,
                  onTap: () => onSelectMode(RobotMode.track),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String status;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.56,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: selected
                ? const Color.fromRGBO(67, 165, 255, 0.18)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color.fromRGBO(67, 165, 255, 0.42)
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              _StatusPill(
                label: status,
                tone: status == 'Need target'
                    ? _PillTone.warn
                    : selected
                        ? _PillTone.accent
                        : _PillTone.good,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaBox extends StatelessWidget {
  const _MetaBox({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.44),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(15, 21, 33, 0.78),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.22),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

enum _PillTone { neutral, accent, good, warn, bad }

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.tone,
  });

  final String label;
  final _PillTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      _PillTone.neutral => (
          background: Colors.white.withValues(alpha: 0.06),
          border: Colors.white.withValues(alpha: 0.10),
          foreground: Colors.white.withValues(alpha: 0.76),
        ),
      _PillTone.accent => (
          background: const Color.fromRGBO(67, 165, 255, 0.18),
          border: const Color.fromRGBO(67, 165, 255, 0.32),
          foreground: Colors.white,
        ),
      _PillTone.good => (
          background: const Color.fromRGBO(61, 220, 132, 0.16),
          border: const Color.fromRGBO(61, 220, 132, 0.24),
          foreground: const Color(0xFFD1FAE5),
        ),
      _PillTone.warn => (
          background: const Color.fromRGBO(246, 195, 68, 0.16),
          border: const Color.fromRGBO(246, 195, 68, 0.24),
          foreground: const Color(0xFFFEF3C7),
        ),
      _PillTone.bad => (
          background: const Color.fromRGBO(229, 91, 84, 0.16),
          border: const Color.fromRGBO(229, 91, 84, 0.24),
          foreground: const Color(0xFFFEE2E2),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PrimaryActionVisual {
  const _PrimaryActionVisual({
    required this.label,
    required this.icon,
    required this.background,
    required this.enabled,
  });

  final String label;
  final IconData icon;
  final Color background;
  final bool enabled;
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({required this.state});

  final RobotCameraState state;

  static const _speedLow = Color(0xFFF6C344);
  static const _speedNormal = Color(0xFF3DDC84);
  static const _speedHigh = Color(0xFFE55B54);

  @override
  Widget build(BuildContext context) {
    final rows = switch (state.mode) {
      RobotMode.drive => [
          _SettingsRow(
            label: 'Collect data',
            trailing: Switch.adaptive(
              value: state.collecting,
              onChanged: state.isRunning ? (_) => state.toggleCollect() : null,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsRow(
            label: 'Controller',
            trailing: _SettingsPicker<DriveControllerType>(
              value: state.driveController,
              values: const [
                DriveControllerType.pc,
                DriveControllerType.gamepad,
                DriveControllerType.phone,
              ],
              labelFor: (v) => switch (v) {
                DriveControllerType.pc => 'PC',
                DriveControllerType.gamepad => 'Gamepad',
                DriveControllerType.phone => 'Phone',
              },
              iconFor: (v) => switch (v) {
                DriveControllerType.pc => Icons.computer_rounded,
                DriveControllerType.gamepad => Icons.sports_esports_rounded,
                DriveControllerType.phone => Icons.smartphone_rounded,
              },
              onSelected: state.setDriveController,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsRow(
            label: 'Speed mode',
            trailing: _SettingsPicker<SpeedMode>(
              value: state.driveSpeedMode,
              values: const [SpeedMode.low, SpeedMode.normal, SpeedMode.high],
              labelFor: (v) => switch (v) {
                SpeedMode.low => 'Low',
                SpeedMode.normal => 'Normal',
                SpeedMode.high => 'High',
              },
              colorFor: (v) => switch (v) {
                SpeedMode.low => _speedLow,
                SpeedMode.normal => _speedNormal,
                SpeedMode.high => _speedHigh,
              },
              onSelected: state.setDriveSpeedMode,
            ),
          ),
        ],
      RobotMode.auto => [
          _SettingsRow(
            label: 'Model',
            trailing: _SettingsPicker<AutoModel>(
              value: state.autoModel,
              values: const [AutoModel.modelA, AutoModel.modelB, AutoModel.modelC],
              labelFor: (v) => switch (v) {
                AutoModel.modelA => 'Model A',
                AutoModel.modelB => 'Model B',
                AutoModel.modelC => 'Model C',
              },
              onSelected: state.setAutoModel,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsRow(
            label: 'Device',
            trailing: _SettingsPicker<ComputeDevice>(
              value: state.autoDevice,
              values: const [
                ComputeDevice.cpu,
                ComputeDevice.gpu,
                ComputeDevice.nnapi,
              ],
              labelFor: (v) => switch (v) {
                ComputeDevice.cpu => 'CPU',
                ComputeDevice.gpu => 'GPU',
                ComputeDevice.nnapi => 'NNAPI',
              },
              iconFor: (v) => switch (v) {
                ComputeDevice.cpu => Icons.memory_rounded,
                ComputeDevice.gpu => Icons.graphic_eq_rounded,
                ComputeDevice.nnapi => Icons.bolt_rounded,
              },
              onSelected: state.setAutoDevice,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsRow(
            label: 'Speed mode',
            trailing: _SettingsPicker<SpeedMode>(
              value: state.autoSpeedMode,
              values: const [SpeedMode.low, SpeedMode.normal, SpeedMode.high],
              labelFor: (v) => switch (v) {
                SpeedMode.low => 'Low',
                SpeedMode.normal => 'Normal',
                SpeedMode.high => 'High',
              },
              colorFor: (v) => switch (v) {
                SpeedMode.low => _speedLow,
                SpeedMode.normal => _speedNormal,
                SpeedMode.high => _speedHigh,
              },
              onSelected: state.setAutoSpeedMode,
            ),
          ),
        ],
      RobotMode.track => [
          _SettingsRow(
            label: 'Model',
            trailing: _SettingsPicker<TrackModel>(
              value: state.trackModel,
              values: const [TrackModel.modelA, TrackModel.modelB, TrackModel.modelC],
              labelFor: (v) => switch (v) {
                TrackModel.modelA => 'Model A',
                TrackModel.modelB => 'Model B',
                TrackModel.modelC => 'Model C',
              },
              onSelected: state.setTrackModel,
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
                TrackTargetType.bicycle,
                TrackTargetType.cat,
              ],
              labelFor: (v) => switch (v) {
                TrackTargetType.person => 'Person',
                TrackTargetType.dog => 'Dog',
                TrackTargetType.bicycle => 'Bicycle',
                TrackTargetType.cat => 'Cat',
              },
              iconFor: (v) => switch (v) {
                TrackTargetType.person => Icons.person_rounded,
                TrackTargetType.dog => Icons.pets_rounded,
                TrackTargetType.bicycle => Icons.directions_bike_rounded,
                TrackTargetType.cat => Icons.pets_rounded,
              },
              onSelected: state.setTrackTargetType,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsRow(
            label: 'Device',
            trailing: _SettingsPicker<ComputeDevice>(
              value: state.trackDevice,
              values: const [
                ComputeDevice.cpu,
                ComputeDevice.gpu,
                ComputeDevice.nnapi,
              ],
              labelFor: (v) => switch (v) {
                ComputeDevice.cpu => 'CPU',
                ComputeDevice.gpu => 'GPU',
                ComputeDevice.nnapi => 'NNAPI',
              },
              iconFor: (v) => switch (v) {
                ComputeDevice.cpu => Icons.memory_rounded,
                ComputeDevice.gpu => Icons.graphic_eq_rounded,
                ComputeDevice.nnapi => Icons.bolt_rounded,
              },
              onSelected: state.setTrackDevice,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsRow(
            label: 'Speed mode',
            trailing: _SettingsPicker<SpeedMode>(
              value: state.trackSpeedMode,
              values: const [SpeedMode.low, SpeedMode.normal, SpeedMode.high],
              labelFor: (v) => switch (v) {
                SpeedMode.low => 'Low',
                SpeedMode.normal => 'Normal',
                SpeedMode.high => 'High',
              },
              colorFor: (v) => switch (v) {
                SpeedMode.low => _speedLow,
                SpeedMode.normal => _speedNormal,
                SpeedMode.high => _speedHigh,
              },
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
                color: const Color.fromRGBO(18, 21, 31, 0.92),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    switch (state.mode) {
                      RobotMode.drive => 'Drive settings',
                      RobotMode.auto => 'Auto settings',
                      RobotMode.track => 'Track settings',
                    },
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
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
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          trailing,
        ],
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

  @override
  Widget build(BuildContext context) {
    final label = labelFor(value);
    final color = colorFor?.call(value);
    final icon = iconFor?.call(value);

    return PopupMenuButton<T>(
      tooltip: '',
      onSelected: onSelected,
      color: const Color.fromRGBO(18, 21, 31, 0.96),
      itemBuilder: (context) {
        return values
            .map(
              (v) => PopupMenuItem<T>(
                value: v,
                child: Row(
                  children: [
                    if (iconFor != null) ...[
                      Icon(
                        iconFor!(v),
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      labelFor(v),
                      style: TextStyle(
                        color: (colorFor?.call(v)) ?? Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.82)),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.expand_more_rounded,
            color: Colors.white.withValues(alpha: 0.62),
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _TrackOverlay extends StatelessWidget {
  const _TrackOverlay({required this.point, required this.label});

  final Offset point;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: point.dx - 58,
          top: point.dy - 74,
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(83, 205, 225, 0.26),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFF81E6FF),
                    width: 2,
                  ),
                  color: const Color.fromRGBO(103, 232, 249, 0.10),
                ),
                child: Stack(
                  children: const [
                    _TrackCorner(top: 14, left: 14),
                    _TrackCorner(top: 14, right: 14, rightSide: true),
                    _TrackCorner(bottom: 14, left: 14, bottomSide: true),
                    _TrackCorner(
                      bottom: 14,
                      right: 14,
                      rightSide: true,
                      bottomSide: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackCorner extends StatelessWidget {
  const _TrackCorner({
    this.top,
    this.left,
    this.right,
    this.bottom,
    this.rightSide = false,
    this.bottomSide = false,
  });

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
            top: !bottomSide
                ? const BorderSide(color: Colors.white, width: 2)
                : BorderSide.none,
            left: !rightSide
                ? const BorderSide(color: Colors.white, width: 2)
                : BorderSide.none,
            right: rightSide
                ? const BorderSide(color: Colors.white, width: 2)
                : BorderSide.none,
            bottom: bottomSide
                ? const BorderSide(color: Colors.white, width: 2)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: !rightSide && !bottomSide
                ? const Radius.circular(14)
                : Radius.zero,
            topRight: rightSide && !bottomSide
                ? const Radius.circular(14)
                : Radius.zero,
            bottomLeft: !rightSide && bottomSide
                ? const Radius.circular(14)
                : Radius.zero,
            bottomRight: rightSide && bottomSide
                ? const Radius.circular(14)
                : Radius.zero,
          ),
        ),
      ),
    );
  }
}

String _modeLabel(RobotMode mode) {
  return switch (mode) {
    RobotMode.drive => 'Drive',
    RobotMode.auto => 'Auto',
    RobotMode.track => 'Track',
  };
}

String _ownerLabel(RobotCameraState state) {
  if (state.driveController == DriveControllerType.gamepad &&
      state.gamepadConnected) {
    return 'Gamepad';
  }
  if (state.driveController == DriveControllerType.phone &&
      state.connection.bluetoothConnected) {
    return 'Remote Phone';
  }
  if (state.driveController == DriveControllerType.pc) {
    return 'PC';
  }
  if (state.gamepadConnected) {
    return 'Gamepad standby';
  }
  return 'None';
}

String _headline(RobotCameraState state, bool initialized) {
  if (!initialized) return 'Starting Robot Runtime';
  if (!state.connection.usbConnected) return 'Connect Robot';
  return switch (state.mode) {
    RobotMode.drive => state.isRunning ? 'Drive Active' : 'Drive Standby',
    RobotMode.auto => state.isRunning ? 'Auto Active' : 'Auto Ready',
    RobotMode.track => state.trackingPoint == null
        ? 'Track Needs Target'
        : state.isRunning
            ? 'Tracking Active'
            : 'Track Ready',
  };
}

String _body(RobotCameraState state, bool initialized, bool advancedOpen) {
  if (!initialized) {
    return 'Core services are still starting. Controls stay secondary until the runtime is ready.';
  }
  if (!state.connection.usbConnected) {
    return 'The robot bridge is not connected yet. Connect the robot first before entering normal runtime.';
  }
  return switch (state.mode) {
    RobotMode.drive => state.isRunning
        ? 'Drive is the primary lane. While active, mode switching is intentionally suppressed.'
        : advancedOpen
            ? 'Drive remains the default lane even while advanced modes are visible.'
            : 'Drive is the default runtime. Open advanced modes only when you intentionally need Auto or Track.',
    RobotMode.auto =>
      'Auto is treated as a deliberate advanced workflow. Model selection stays secondary to the main runtime surface.',
    RobotMode.track => state.trackingPoint == null
        ? 'Track requires one explicit camera target before it can begin.'
        : 'Track is staged through target selection first, then execution.',
  };
}

String _nextStepLabel(RobotCameraState state, bool initialized) {
  if (!initialized) return 'Starting';
  if (!state.connection.usbConnected) return 'Connect Robot';
  if (state.isRunning) {
    return switch (state.mode) {
      RobotMode.drive => 'Stop',
      RobotMode.auto => 'Stop Auto',
      RobotMode.track => 'Stop Tracking',
    };
  }
  return switch (state.mode) {
    RobotMode.drive => 'Start',
    RobotMode.auto => 'Start Auto',
    RobotMode.track =>
      state.trackingPoint == null ? 'Select Target' : 'Start Tracking',
  };
}

String _footerNote(RobotCameraState state, bool advancedOpen) {
  if (state.isRunning) {
    return 'Active runtime takes priority. Stop before switching role or changing advanced modes.';
  }
  if (advancedOpen) {
    return 'Advanced modes are visible by choice, not by default. This keeps the main shell focused on robot operation.';
  }
  return 'Drive stays primary. Advanced capability is available, but it does not dominate the base runtime.';
}

String _autoModelLabel(AutoModel model) {
  return switch (model) {
    AutoModel.modelA => 'Model A',
    AutoModel.modelB => 'Model B',
    AutoModel.modelC => 'Model C',
  };
}

String _trackModelLabel(TrackModel model) {
  return switch (model) {
    TrackModel.modelA => 'Model A',
    TrackModel.modelB => 'Model B',
    TrackModel.modelC => 'Model C',
  };
}

String _computeDeviceLabel(ComputeDevice device) {
  return switch (device) {
    ComputeDevice.cpu => 'CPU',
    ComputeDevice.gpu => 'GPU',
    ComputeDevice.nnapi => 'NNAPI',
  };
}

String _targetTypeLabel(TrackTargetType targetType) {
  return switch (targetType) {
    TrackTargetType.person => 'Person',
    TrackTargetType.dog => 'Dog',
    TrackTargetType.bicycle => 'Bicycle',
    TrackTargetType.cat => 'Cat',
  };
}

_PrimaryActionVisual _primaryActionFor(RobotCameraState state, bool initialized) {
  if (!initialized) {
    return const _PrimaryActionVisual(
      label: 'Starting...',
      icon: Icons.hourglass_top_rounded,
      background: Color(0xFF334155),
      enabled: false,
    );
  }
  if (!state.connection.usbConnected) {
    return const _PrimaryActionVisual(
      label: 'Connect Robot',
      icon: Icons.usb_rounded,
      background: Color(0xFFD97706),
      enabled: true,
    );
  }
  if (state.isRunning) {
    return _PrimaryActionVisual(
      label: switch (state.mode) {
        RobotMode.drive => 'Stop',
        RobotMode.auto => 'Stop Auto',
        RobotMode.track => 'Stop Tracking',
      },
      icon: Icons.stop_rounded,
      background: const Color(0xFFCC433C),
      enabled: true,
    );
  }
  return _PrimaryActionVisual(
    label: switch (state.mode) {
      RobotMode.drive => 'Start',
      RobotMode.auto => 'Start Auto',
      RobotMode.track =>
        state.trackingPoint == null ? 'Select Target' : 'Start Tracking',
    },
    icon: switch (state.mode) {
      RobotMode.drive => Icons.play_arrow_rounded,
      RobotMode.auto => Icons.auto_awesome_rounded,
      RobotMode.track =>
        state.trackingPoint == null ? Icons.ads_click_rounded : Icons.play_arrow_rounded,
    },
    background: state.mode == RobotMode.track && state.trackingPoint == null
        ? const Color(0xFFD97706)
        : const Color(0xFF1FAE66),
    enabled: true,
  );
}
