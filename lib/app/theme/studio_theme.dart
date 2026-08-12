import 'package:flutter/material.dart';

abstract final class StudioColors {
  static const workspace = Color(0xFF191A1C);
  static const panel = Color(0xFF232428);
  static const surface = Color(0xFF2B2D31);
  static const surfaceHigh = Color(0xFF34363B);
  static const divider = Color(0xFF3D3F45);
  static const textPrimary = Color(0xFFF2F2F3);
  static const textSecondary = Color(0xFFB2B4BA);
  static const textDisabled = Color(0xFF71737A);
  static const accent = Color(0xFF9DB7FF);
  static const error = Color(0xFFFF8A80);
  static const success = Color(0xFF8BD49C);
}

abstract final class StudioSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

abstract final class StudioRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 18.0;
}

abstract final class StudioMetrics {
  static const moduleBarHeight = 52.0;
  static const statusBarHeight = 28.0;
  static const leftPanelWide = 260.0;
  static const leftPanelMedium = 224.0;
  static const rightPanelWide = 320.0;
  static const rightPanelMedium = 288.0;
  static const compactToolbarHeight = 48.0;
}

abstract final class StudioBreakpoints {
  static const compact = 800.0;
  static const desktop = 1100.0;
  static const wide = 1440.0;
}

abstract final class StudioTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: StudioColors.accent,
      brightness: Brightness.dark,
      surface: StudioColors.panel,
    );

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: StudioColors.workspace,
      dividerColor: StudioColors.divider,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      textTheme: const TextTheme(
        titleMedium: TextStyle(
          color: StudioColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(color: StudioColors.textPrimary, fontSize: 13),
        bodySmall: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
        labelMedium: TextStyle(
          color: StudioColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudioRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudioRadius.md),
          ),
        ),
      ),
      sliderTheme: const SliderThemeData(trackHeight: 2),
    );
  }
}
