import 'package:flutter/material.dart';

/// ISENS brand colors, matching the Raspberry Pi dashboard's palette.
class IsensColors {
  static const Color navy = Color(0xFF29328F);
  static const Color blue = Color(0xFF1D73B7);
  static const Color cyan = Color(0xFF2BB7C4);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color danger = Color(0xFFC62828);
}

ThemeData buildIsensTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: IsensColors.navy,
    primary: IsensColors.navy,
    secondary: IsensColors.blue,
    tertiary: IsensColors.cyan,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFF4F6FA),
    appBarTheme: const AppBarTheme(
      backgroundColor: IsensColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardTheme(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: IsensColors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD0D5E0)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}
