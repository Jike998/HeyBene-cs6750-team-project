import 'package:flutter/material.dart';

class FusionSurfaceTokens {
  static const chromeFill = Color(0x441A212C);
  static const chromeFillStrong = Color(0x5C1A212C);
  static const chromeBorder = Color(0x66FFFFFF);
  static const chromeBorderSoft = Color(0x44FFFFFF);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xE0FFFFFF);
  static const textTertiary = Color(0x99FFFFFF);
  static const accent = Color(0xFF8FD7FF);
  static const accentSoft = Color(0x4D8FD7FF);
  static const accentGlow = Color(0x338FD7FF);
  static const success = Colors.white;

  static const topGradient = [Color(0x661A212C), Color(0x401A212C)];
  static const panelGradient = [Color(0x5C1A212C), Color(0x441A212C)];
  static const panelInnerGradient = [Color(0x12FFFFFF), Color(0x05FFFFFF)];
  static const modalGradient = [Color(0xB81A212C), Color(0x941A212C)];
  static const controlOuterGradient = [Color(0x661A212C), Color(0x541A212C), Color(0x441A212C)];
  static const controlActiveGradient = [Color(0x7A1A212C), Color(0x5C1A212C)];
  static const controlPlateGradient = [Color(0x338FD7FF), Color(0x146B84A0)];
  static const controlPlateBorder = Color(0x4DFFFFFF);

  static Border tokenBorder([double width = 1]) => Border.all(color: chromeBorder, width: width);
}
