import 'package:flutter/material.dart';

abstract final class StudioColors {
  static const workspace = Color(0xFF191A1C);
  static const panel = Color(0xFF232428);
  static const surface = Color(0xFF2B2D31);
  static const surfaceHigh = Color(0xFF34363B);
  static const divider = Color(0xFF3D3F45);
  static const focus = Color(0xFFB7C8FF);
  static const hover = Color(0x14FFFFFF);
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
  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 12.0;
}

abstract final class StudioDurations {
  static const fast = Duration(milliseconds: 120);
  static const medium = Duration(milliseconds: 180);
}

abstract final class StudioMetrics {
  static const moduleBarHeight = 48.0;
  static const statusBarHeight = 26.0;
  static const compactToolbarHeight = 44.0;
  static const compactControlHeight = 30.0;
  static const compactRowHeight = 30.0;
  static const filmstripHeight = 108.0;
  static const filmstripCollapsedHeight = 30.0;
  static const filmstripItemWidth = 112.0;
}

abstract final class StudioTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: StudioColors.accent,
      brightness: Brightness.dark,
      surface: StudioColors.panel,
    );

    final compactButtonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(StudioRadius.md),
    );

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: StudioColors.workspace,
      dividerColor: StudioColors.divider,
      focusColor: StudioColors.focus.withValues(alpha: 0.18),
      hoverColor: StudioColors.hover,
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
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.md),
          shape: compactButtonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.md),
          side: const BorderSide(color: StudioColors.divider),
          shape: compactButtonShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(32),
          padding: const EdgeInsets.all(StudioSpacing.xs),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: StudioColors.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StudioRadius.sm),
          borderSide: const BorderSide(color: StudioColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StudioRadius.sm),
          borderSide: const BorderSide(color: StudioColors.focus),
        ),
      ),
      sliderTheme: const SliderThemeData(trackHeight: 2),
      tooltipTheme: const TooltipThemeData(
        waitDuration: StudioDurations.medium,
      ),
    );
  }
}
