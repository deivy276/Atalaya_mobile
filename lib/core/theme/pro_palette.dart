import 'package:flutter/material.dart';

class ProPalette {
  const ProPalette._();

  static const Color bg = Color(0xFF0B1220);
  static const Color panel = Color(0xFF0F1B33);
  static const Color card = Color(0xFF111827);
  static const Color stroke = Color(0xFF22304A);
  static const Color text = Color(0xFFE5E7EB);
  static const Color muted = Color(0xFF94A3B8);
  static const Color accent = Color(0xFF34D399);
  static const Color ok = Color(0xFF22C55E);
  static const Color warn = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color chipBg = Color(0xFF0B1220);
  static const Color overlay = Color(0xAA000000);

  static ThemeData themeData() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: card,
      primary: accent,
      secondary: warn,
      error: danger,
      onSurface: text,
      onPrimary: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: TextStyle(color: text),
        behavior: SnackBarBehavior.floating,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
      ),
      dividerColor: stroke,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent),
        ),
        labelStyle: const TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: text),
        bodyMedium: TextStyle(color: text),
        bodySmall: TextStyle(color: muted),
        titleLarge: TextStyle(color: text, fontWeight: FontWeight.w800),
      ),
    );
  }

  static ThemeData lightThemeData() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: Colors.white,
      primary: const Color(0xFF0F766E),
      secondary: warn,
      error: danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF4F7FB),
      canvasColor: const Color(0xFFF4F7FB),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF4F7FB),
        foregroundColor: Color(0xFF0B1220),
        elevation: 0,
        centerTitle: false,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF0F172A),
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
