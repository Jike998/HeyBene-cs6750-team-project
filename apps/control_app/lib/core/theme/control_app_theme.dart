import 'package:flutter/material.dart';

class ControlAppTheme {
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF05070D),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF3DDC84),
        secondary: Color(0xFF8BC6FF),
        surface: Color(0xFF171B24),
      ),
      useMaterial3: true,
    );
  }
}
