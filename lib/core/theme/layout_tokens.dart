import 'package:flutter/material.dart';

class LayoutTokens {
  const LayoutTokens._();

  // Dark operational palette aligned with ProPalette.darkThemeData().
  // These remain const because several dashboard widgets use them in const styles.
  static const Color bgPrimary = Color(0xFF0B132B);
  static const Color bgSecondary = Color(0xFF0F172A);
  static const Color surfaceCard = Color(0xFF1C2541);
  static const Color surfaceCardSelected = Color(0xFF243453);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentOrange = Color(0xFFF59E0B);
  static const Color accentBlue = Color(0xFF06B6D4);
  static const Color accentRed = Color(0xFFEF4444);
  static const Color dividerSubtle = Color(0x4D334155);

  // Chart tokens for trend and Special Predictor surfaces.
  static const Color plotAreaDark = Color(0xFF0F172A);
  static const Color gridDark = Color(0x4D334155);
  static const Color curvePrimaryDark = Color(0xFF3B82F6);
  static const Color curveSecondaryPurpleDark = Color(0xFF8B5CF6);
  static const Color curveSecondaryOrangeDark = Color(0xFFF59E0B);
  static const Color scatterDark = Color(0x99EF4444);

  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing32 = 32;
}
