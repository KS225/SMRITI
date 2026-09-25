import 'package:flutter/material.dart';

class SmritiTheme {
  SmritiTheme._();

  static const Color background = Color(0xFFF9F7F2);
  static const Color primary = Color(0xFF59694D);
  static const Color primaryDark = Color(0xFF34402D);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color softGreen = Color(0xFFE9F0E4);
  static const Color softRed = Color(0xFFFFE8E4);
  static const Color emergency = Color(0xFFB34A42);
  static const Color textPrimary = Color(0xFF33352F);
  static const Color textSecondary = Color(0xFF73736C);
  static const Color border = Color(0xFFE5E2D9);

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,

      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ),

      fontFamily: 'sans-serif',

      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: primaryDark,
        elevation: 0,
        centerTitle: true,
      ),

      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: primaryDark,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          color: textSecondary,
        ),
      ),
    );
  }
}