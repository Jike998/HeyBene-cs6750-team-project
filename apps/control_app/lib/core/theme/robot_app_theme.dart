import 'package:flutter/material.dart';

class RobotAppTheme {
  static ThemeData dark() {
    const background = Color(0xFF020617);
    const surface = Color(0xFF111827);
    const accent = Color(0xFF60A5FA);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: Color(0xFF22D3EE),
        surface: surface,
      ),
      useMaterial3: true,
    );
  }
}
