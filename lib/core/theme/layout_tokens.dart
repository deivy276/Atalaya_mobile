import 'package:flutter/material.dart';

class LayoutTokens {
  const LayoutTokens._();

  // Dark operational palette aligned with ProPalette.darkThemeData().
  // These remain const because many dashboard widgets use them in const styles.
  static const Color bgPrimary = Color(0xFF0F172A);
  static const Color bgSecondary = Color(0xFF0B1120);
  static const Color surfaceCard = Color(0xFF1E293B);
  static const Color surfaceCardSelected = Color(0xFF334155);
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color accentGreen = Color(0xFF22C55E);
  static const Color accentOrange = Color(0xFFF97316);
  static const Color accentBlue = Color(0xFF00E5FF);
  static const Color accentRed = Color(0xFFF43F5E);
  static const Color dividerSubtle = Color(0x4D334155);

  // Chart tokens for Special Predictor and trend surfaces.
  static const Color plotAreaDark = Color(0xFF0B1120);
  static const Color gridDark = Color(0x4D334155);
  static const Color curvePrimaryDark = Color(0xFF00E5FF);
  static const Color curveSecondaryPurpleDark = Color(0xFFA855F7);
  static const Color curveSecondaryOrangeDark = Color(0xFFF97316);
  static const Color scatterDark = Color(0x99F43F5E);

  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing32 = 32;
}
