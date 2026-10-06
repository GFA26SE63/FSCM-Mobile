import 'package:flutter/material.dart';

abstract final class FscmColors {
  static const primary = Color(0xFF14655B);
  static const primaryDark = Color(0xFF0F4F48);
  static const canvas = Color(0xFFF3F4F1);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1B1F1D);
  static const muted = Color(0xFF5B625E);
  static const border = Color(0xFFDADFDB);
  static const warning = Color(0xFFF5A524);
  static const danger = Color(0xFFB42318);
  static const info = Color(0xFF1D4ED8);
  static const purple = Color(0xFF6D28D9);
}

abstract final class FscmTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: FscmColors.primary,
      brightness: Brightness.light,
      surface: FscmColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: FscmColors.canvas,
      fontFamily: 'sans-serif',
      appBarTheme: const AppBarTheme(
        backgroundColor: FscmColors.surface,
        foregroundColor: FscmColors.text,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: FscmColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: const CardThemeData(
        color: FscmColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: FscmColors.border),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: FscmColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: FscmColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: FscmColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: FscmColors.primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FscmColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FscmColors.primary,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: FscmColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      dividerColor: FscmColors.border,
    );
  }
}
