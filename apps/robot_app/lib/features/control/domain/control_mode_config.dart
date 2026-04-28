import 'dart:ui';

import 'control_layout.dart';

enum ControlClusterSide { left, right, center }

class ControlClusterOffset {
  const ControlClusterOffset({
    this.dx = 0,
    this.dy = 0,
  });

  static const zero = ControlClusterOffset();

  final double dx;
  final double dy;

  ControlClusterOffset copyWith({
    double? dx,
    double? dy,
  }) {
    return ControlClusterOffset(
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
    );
  }

  ControlClusterOffset nudge({
    required double dx,
    required double dy,
  }) {
    return ControlClusterOffset(
      dx: (this.dx + dx).clamp(-120.0, 120.0).toDouble(),
      dy: (this.dy + dy).clamp(-90.0, 90.0).toDouble(),
    );
  }

  Offset toOffset() => Offset(dx, dy);
}

class ControlLayoutPreset {
  const ControlLayoutPreset({
    this.leftClusterOffset = ControlClusterOffset.zero,
    this.rightClusterOffset = ControlClusterOffset.zero,
    this.centerClusterOffset = ControlClusterOffset.zero,
  });

  static const standard = ControlLayoutPreset();

  final ControlClusterOffset leftClusterOffset;
  final ControlClusterOffset rightClusterOffset;
  final ControlClusterOffset centerClusterOffset;

  ControlLayoutPreset copyWith({
    ControlClusterOffset? leftClusterOffset,
    ControlClusterOffset? rightClusterOffset,
    ControlClusterOffset? centerClusterOffset,
  }) {
    return ControlLayoutPreset(
      leftClusterOffset: leftClusterOffset ?? this.leftClusterOffset,
      rightClusterOffset: rightClusterOffset ?? this.rightClusterOffset,
      centerClusterOffset: centerClusterOffset ?? this.centerClusterOffset,
    );
  }

  ControlLayoutPreset nudge(
    ControlClusterSide side, {
    required double dx,
    required double dy,
  }) {
    return switch (side) {
      ControlClusterSide.left => copyWith(
        leftClusterOffset: leftClusterOffset.nudge(dx: dx, dy: dy),
      ),
      ControlClusterSide.right => copyWith(
        rightClusterOffset: rightClusterOffset.nudge(dx: dx, dy: dy),
      ),
      ControlClusterSide.center => copyWith(
        centerClusterOffset: centerClusterOffset.nudge(dx: dx, dy: dy),
      ),
    };
  }

  ControlLayoutPreset resetSide(ControlClusterSide side) {
    return switch (side) {
      ControlClusterSide.left => copyWith(
        leftClusterOffset: ControlClusterOffset.zero,
      ),
      ControlClusterSide.right => copyWith(
        rightClusterOffset: ControlClusterOffset.zero,
      ),
      ControlClusterSide.center => copyWith(
        centerClusterOffset: ControlClusterOffset.zero,
      ),
    };
  }
}

class ControllerModeControlConfig {
  const ControllerModeControlConfig({
    required this.activeLayout,
    required this.layoutPresets,
  });

  factory ControllerModeControlConfig.initial({
    ControlLayout activeLayout = ControlLayout.dual,
  }) {
    return ControllerModeControlConfig(
      activeLayout: activeLayout,
      layoutPresets: const {
        ControlLayout.dual: ControlLayoutPreset.standard,
        ControlLayout.arrow: ControlLayoutPreset.standard,
        ControlLayout.oneHandedPortrait: ControlLayoutPreset.standard,
      },
    );
  }

  final ControlLayout activeLayout;
  final Map<ControlLayout, ControlLayoutPreset> layoutPresets;

  ControlLayoutPreset get activePreset {
    return layoutPresets[activeLayout] ?? ControlLayoutPreset.standard;
  }

  ControllerModeControlConfig copyWith({
    ControlLayout? activeLayout,
    Map<ControlLayout, ControlLayoutPreset>? layoutPresets,
  }) {
    return ControllerModeControlConfig(
      activeLayout: activeLayout ?? this.activeLayout,
      layoutPresets: layoutPresets ?? this.layoutPresets,
    );
  }

  ControllerModeControlConfig setLayout(ControlLayout layout) {
    return copyWith(activeLayout: layout);
  }

  ControllerModeControlConfig updatePreset(
    ControlLayout layout,
    ControlLayoutPreset preset,
  ) {
    final nextPresets = Map<ControlLayout, ControlLayoutPreset>.from(
      layoutPresets,
    )..[layout] = preset;

    return copyWith(layoutPresets: nextPresets);
  }

  ControllerModeControlConfig resetPreset(ControlLayout layout) {
    return updatePreset(layout, ControlLayoutPreset.standard);
  }
}
