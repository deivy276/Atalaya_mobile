import 'package:flutter/material.dart';

import 'pro_palette.dart';

@immutable
class AtalayaThemeColors {
  const AtalayaThemeColors({
    required this.isDark,
    required this.background,
    required this.backgroundAlt,
    required this.card,
    required this.cardAlt,
    required this.plot,
    required this.grid,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.shadow,
  });

  final bool isDark;
  final Color background;
  final Color backgroundAlt;
  final Color card;
  final Color cardAlt;
  final Color plot;
  final Color grid;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color shadow;

  factory AtalayaThemeColors.fromContext(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AtalayaVisualPalette>() ??
        (theme.brightness == Brightness.light
            ? AtalayaVisualPalette.light
            : AtalayaVisualPalette.dark);
    final isDark = palette.brightness == Brightness.dark;

    return AtalayaThemeColors(
      isDark: isDark,
      background: palette.background,
      backgroundAlt: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
      card: palette.card,
      cardAlt: isDark ? const Color(0xFF16233B) : const Color(0xFFF1F5F9),
      plot: palette.plotArea,
      grid: palette.grid,
      border: isDark ? const Color(0x4D334155) : const Color(0xFFE2E8F0),
      textPrimary: palette.textPrimary,
      textSecondary: palette.textSecondary,
      textMuted: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
      primary: palette.primary,
      success: palette.safe,
      warning: const Color(0xFFF59E0B),
      danger: const Color(0xFFEF4444),
      shadow: isDark
          ? Colors.black.withValues(alpha: 0.26)
          : const Color(0xFF0F172A).withValues(alpha: 0.08),
    );
  }

  LinearGradient get pageGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[background, backgroundAlt],
      );

  LinearGradient get cardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[card, cardAlt],
      );
}

extension AtalayaThemeContext on BuildContext {
  AtalayaThemeColors get atalayaColors => AtalayaThemeColors.fromContext(this);
}
