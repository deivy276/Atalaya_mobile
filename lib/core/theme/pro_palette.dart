import 'package:flutter/material.dart';

@immutable
class AtalayaVisualPalette extends ThemeExtension<AtalayaVisualPalette> {
  const AtalayaVisualPalette({
    required this.brightness,
    required this.background,
    required this.card,
    required this.plotArea,
    required this.grid,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.curvePrimary,
    required this.curveSecondaryA,
    required this.curveSecondaryB,
    required this.scatter,
    required this.safe,
  });

  final Brightness brightness;
  final Color background;
  final Color card;
  final Color plotArea;
  final Color grid;
  final Color textPrimary;
  final Color textSecondary;
  final Color primary;
  final Color curvePrimary;
  final Color curveSecondaryA;
  final Color curveSecondaryB;
  final Color scatter;
  final Color safe;

  static const AtalayaVisualPalette dark = AtalayaVisualPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0B132B),
    card: Color(0xFF1C2541),
    plotArea: Color(0xFF0F172A),
    grid: Color(0x4D334155),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    primary: Color(0xFF06B6D4),
    curvePrimary: Color(0xFF3B82F6),
    curveSecondaryA: Color(0xFF8B5CF6),
    curveSecondaryB: Color(0xFFF59E0B),
    scatter: Color(0x99EF4444),
    safe: Color(0xFF10B981),
  );

  static const AtalayaVisualPalette light = AtalayaVisualPalette(
    brightness: Brightness.light,
    background: Color(0xFFF8FAFC),
    card: Color(0xFFFFFFFF),
    plotArea: Color(0xFFF1F5F9),
    grid: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    primary: Color(0xFF0284C7),
    curvePrimary: Color(0xFF3B82F6),
    curveSecondaryA: Color(0xFF8B5CF6),
    curveSecondaryB: Color(0xFFF59E0B),
    scatter: Color(0x99EF4444),
    safe: Color(0xFF10B981),
  );

  @override
  AtalayaVisualPalette copyWith({
    Brightness? brightness,
    Color? background,
    Color? card,
    Color? plotArea,
    Color? grid,
    Color? textPrimary,
    Color? textSecondary,
    Color? primary,
    Color? curvePrimary,
    Color? curveSecondaryA,
    Color? curveSecondaryB,
    Color? scatter,
    Color? safe,
  }) {
    return AtalayaVisualPalette(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      card: card ?? this.card,
      plotArea: plotArea ?? this.plotArea,
      grid: grid ?? this.grid,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      primary: primary ?? this.primary,
      curvePrimary: curvePrimary ?? this.curvePrimary,
      curveSecondaryA: curveSecondaryA ?? this.curveSecondaryA,
      curveSecondaryB: curveSecondaryB ?? this.curveSecondaryB,
      scatter: scatter ?? this.scatter,
      safe: safe ?? this.safe,
    );
  }

  @override
  AtalayaVisualPalette lerp(ThemeExtension<AtalayaVisualPalette>? other, double t) {
    if (other is! AtalayaVisualPalette) return this;

    return AtalayaVisualPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: Color.lerp(background, other.background, t) ?? background,
      card: Color.lerp(card, other.card, t) ?? card,
      plotArea: Color.lerp(plotArea, other.plotArea, t) ?? plotArea,
      grid: Color.lerp(grid, other.grid, t) ?? grid,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      curvePrimary: Color.lerp(curvePrimary, other.curvePrimary, t) ?? curvePrimary,
      curveSecondaryA: Color.lerp(curveSecondaryA, other.curveSecondaryA, t) ?? curveSecondaryA,
      curveSecondaryB: Color.lerp(curveSecondaryB, other.curveSecondaryB, t) ?? curveSecondaryB,
      scatter: Color.lerp(scatter, other.scatter, t) ?? scatter,
      safe: Color.lerp(safe, other.safe, t) ?? safe,
    );
  }
}

class ProPalette {
  const ProPalette._();

  // Backwards-compatible aliases used by legacy widgets.
  static const Color bg = Color(0xFF0B132B);
  static const Color panel = Color(0xFF0F172A);
  static const Color card = Color(0xFF1C2541);
  static const Color stroke = Color(0x4D334155);
  static const Color text = Color(0xFFF8FAFC);
  static const Color muted = Color(0xFF94A3B8);
  static const Color accent = Color(0xFF06B6D4);
  static const Color ok = Color(0xFF10B981);
  static const Color warn = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color chipBg = Color(0xFF0F172A);
  static const Color overlay = Color(0xAA000000);

  // Data colors.
  static const Color curveBlue = Color(0xFF3B82F6);
  static const Color curvePurple = Color(0xFF8B5CF6);
  static const Color curveAmber = Color(0xFFF59E0B);
  static const Color scatterReal = Color(0xFFEF4444);

  static ThemeData themeData() => darkThemeData();

  static ThemeData darkThemeData() => _baseTheme(AtalayaVisualPalette.dark);

  static ThemeData lightThemeData() => _baseTheme(AtalayaVisualPalette.light);

  static ThemeData _baseTheme(AtalayaVisualPalette colors) {
    final isDark = colors.brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: colors.brightness,
      surface: colors.card,
      primary: colors.primary,
      secondary: colors.curveSecondaryA,
      tertiary: colors.curveSecondaryB,
      error: const Color(0xFFEF4444),
      onSurface: colors.textPrimary,
      onPrimary: isDark ? const Color(0xFF020617) : Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      cardColor: colors.card,
      dividerColor: colors.grid,
      extensions: <ThemeExtension<dynamic>>[colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.card,
        modalBackgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(color: colors.textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? colors.card : const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(color: Color(0xFFF8FAFC)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.plotArea,
        selectedColor: colors.primary.withValues(alpha: isDark ? 0.22 : 0.16),
        disabledColor: colors.grid.withValues(alpha: 0.22),
        side: BorderSide(color: colors.grid),
        labelStyle: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700),
        secondaryLabelStyle: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800),
        iconTheme: IconThemeData(color: colors.textSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected) ? colors.textPrimary : colors.textSecondary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? colors.primary.withValues(alpha: isDark ? 0.18 : 0.12)
                : colors.plotArea;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            return BorderSide(
              color: states.contains(WidgetState.selected) ? colors.primary : colors.grid,
              width: states.contains(WidgetState.selected) ? 1.2 : 1,
            );
          }),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textSecondary,
          hoverColor: colors.primary.withValues(alpha: 0.12),
          focusColor: colors.primary.withValues(alpha: 0.12),
          highlightColor: colors.primary.withValues(alpha: 0.12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? colors.plotArea : colors.card,
        labelStyle: TextStyle(color: colors.textSecondary),
        hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.78)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.grid),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.grid),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 1.3),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: isDark ? const Color(0xFF020617) : Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800),
        displayMedium: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800),
        displaySmall: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800),
        headlineLarge: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800),
        headlineMedium: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800),
        headlineSmall: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
        titleSmall: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: colors.textPrimary),
        bodyMedium: TextStyle(color: colors.textPrimary),
        bodySmall: TextStyle(color: colors.textSecondary),
        labelLarge: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
        labelMedium: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

extension AtalayaThemeContext on BuildContext {
  AtalayaVisualPalette get atalayaColors =>
      Theme.of(this).extension<AtalayaVisualPalette>() ?? AtalayaVisualPalette.dark;
}
