import 'package:flutter/material.dart';

@immutable
class AtalayaVisualPalette extends ThemeExtension<AtalayaVisualPalette> {
  const AtalayaVisualPalette({
    required this.background,
    required this.card,
    required this.plotArea,
    required this.grid,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.curveSecondaryA,
    required this.curveSecondaryB,
    required this.scatter,
  });

  final Color background;
  final Color card;
  final Color plotArea;
  final Color grid;
  final Color textPrimary;
  final Color textSecondary;
  final Color primary;
  final Color curveSecondaryA;
  final Color curveSecondaryB;
  final Color scatter;

  static const AtalayaVisualPalette dark = AtalayaVisualPalette(
    background: Color(0xFF0F172A),
    card: Color(0xFF1E293B),
    plotArea: Color(0xFF0B1120),
    grid: Color(0x4D334155),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    primary: Color(0xFF00E5FF),
    curveSecondaryA: Color(0xFFA855F7),
    curveSecondaryB: Color(0xFFF97316),
    scatter: Color(0x99F43F5E),
  );

  static const AtalayaVisualPalette light = AtalayaVisualPalette(
    background: Color(0xFFF8FAFC),
    card: Color(0xFFFFFFFF),
    plotArea: Color(0xFFF1F5F9),
    grid: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    primary: Color(0xFF0891B2),
    curveSecondaryA: Color(0xFF7E22CE),
    curveSecondaryB: Color(0xFFC2410C),
    scatter: Color(0x99E11D48),
  );

  @override
  AtalayaVisualPalette copyWith({
    Color? background,
    Color? card,
    Color? plotArea,
    Color? grid,
    Color? textPrimary,
    Color? textSecondary,
    Color? primary,
    Color? curveSecondaryA,
    Color? curveSecondaryB,
    Color? scatter,
  }) {
    return AtalayaVisualPalette(
      background: background ?? this.background,
      card: card ?? this.card,
      plotArea: plotArea ?? this.plotArea,
      grid: grid ?? this.grid,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      primary: primary ?? this.primary,
      curveSecondaryA: curveSecondaryA ?? this.curveSecondaryA,
      curveSecondaryB: curveSecondaryB ?? this.curveSecondaryB,
      scatter: scatter ?? this.scatter,
    );
  }

  @override
  AtalayaVisualPalette lerp(ThemeExtension<AtalayaVisualPalette>? other, double t) {
    if (other is! AtalayaVisualPalette) {
      return this;
    }

    return AtalayaVisualPalette(
      background: Color.lerp(background, other.background, t) ?? background,
      card: Color.lerp(card, other.card, t) ?? card,
      plotArea: Color.lerp(plotArea, other.plotArea, t) ?? plotArea,
      grid: Color.lerp(grid, other.grid, t) ?? grid,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      curveSecondaryA: Color.lerp(curveSecondaryA, other.curveSecondaryA, t) ?? curveSecondaryA,
      curveSecondaryB: Color.lerp(curveSecondaryB, other.curveSecondaryB, t) ?? curveSecondaryB,
      scatter: Color.lerp(scatter, other.scatter, t) ?? scatter,
    );
  }
}

class ProPalette {
  const ProPalette._();

  // Dark palette: midnight blues and muted grays for field operations.
  static const Color bg = Color(0xFF0F172A);
  static const Color panel = Color(0xFF0B1120);
  static const Color card = Color(0xFF1E293B);
  static const Color stroke = Color(0x4D334155);
  static const Color text = Color(0xFFF1F5F9);
  static const Color muted = Color(0xFF94A3B8);
  static const Color accent = Color(0xFF00E5FF);
  static const Color ok = Color(0xFF22C55E);
  static const Color warn = Color(0xFFF97316);
  static const Color danger = Color(0xFFF43F5E);
  static const Color chipBg = Color(0xFF0B1120);
  static const Color overlay = Color(0xAA000000);

  // Light palette: cool neutrals with engineering contrast.
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightPlot = Color(0xFFF1F5F9);
  static const Color lightGrid = Color(0xFFE2E8F0);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightMuted = Color(0xFF64748B);
  static const Color lightAccent = Color(0xFF0891B2);
  static const Color lightWarn = Color(0xFFC2410C);
  static const Color lightDanger = Color(0xFFE11D48);

  static ThemeData themeData() => darkThemeData();

  static ThemeData darkThemeData() {
    const colors = AtalayaVisualPalette.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: Brightness.dark,
      surface: colors.card,
      primary: colors.primary,
      secondary: colors.curveSecondaryB,
      error: const Color(0xFFF43F5E),
      onSurface: colors.textPrimary,
      onPrimary: const Color(0xFF020617),
    );

    return _baseTheme(
      brightness: Brightness.dark,
      colors: colors,
      scheme: scheme,
      scaffoldBackgroundColor: colors.background,
      cardColor: colors.card,
      inputFillColor: colors.plotArea,
      appBarForeground: colors.textPrimary,
      buttonForeground: const Color(0xFF020617),
    );
  }

  static ThemeData lightThemeData() {
    const colors = AtalayaVisualPalette.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: Brightness.light,
      surface: colors.card,
      primary: colors.primary,
      secondary: colors.curveSecondaryB,
      error: const Color(0xFFE11D48),
      onSurface: colors.textPrimary,
      onPrimary: Colors.white,
    );

    return _baseTheme(
      brightness: Brightness.light,
      colors: colors,
      scheme: scheme,
      scaffoldBackgroundColor: colors.background,
      cardColor: colors.card,
      inputFillColor: colors.plotArea,
      appBarForeground: colors.textPrimary,
      buttonForeground: Colors.white,
    );
  }

  static ThemeData _baseTheme({
    required Brightness brightness,
    required AtalayaVisualPalette colors,
    required ColorScheme scheme,
    required Color scaffoldBackgroundColor,
    required Color cardColor,
    required Color inputFillColor,
    required Color appBarForeground,
    required Color buttonForeground,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      canvasColor: scaffoldBackgroundColor,
      cardColor: cardColor,
      dividerColor: colors.grid,
      extensions: const <ThemeExtension<dynamic>>[
        AtalayaVisualPalette.dark,
        AtalayaVisualPalette.light,
      ].whereType<AtalayaVisualPalette>().where((palette) => palette.background == colors.background).toList(),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackgroundColor,
        foregroundColor: appBarForeground,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? cardColor : const Color(0xFF0F172A),
        contentTextStyle: TextStyle(color: isDark ? colors.textPrimary : Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: inputFillColor,
        selectedColor: colors.primary.withValues(alpha: isDark ? 0.20 : 0.16),
        labelStyle: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700),
        secondaryLabelStyle: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800),
        side: BorderSide(color: colors.grid),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
        fillColor: inputFillColor,
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
          borderSide: BorderSide(color: colors.primary, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: buttonForeground,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected) ? colors.textPrimary : colors.textSecondary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? colors.primary.withValues(alpha: isDark ? 0.18 : 0.12)
                : inputFillColor;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            return BorderSide(
              color: states.contains(WidgetState.selected) ? colors.primary : colors.grid,
            );
          }),
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
        labelMedium: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700),
        labelSmall: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700),
      ),
    );
  }
}
