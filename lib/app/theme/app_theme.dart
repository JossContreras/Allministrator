import 'package:flutter/material.dart';
import 'app_color_scheme.dart';
import 'app_elevation.dart';
import 'app_radius.dart';
import 'app_visual_style.dart';

abstract final class AppTheme {
  static ThemeData _build(ColorScheme scheme, AppVisualStyle style) {
    final profile = _ThemeProfile.forStyle(style);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
    );
    final textTheme = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: profile.headingWeight,
        letterSpacing: profile.displayLetterSpacing,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: profile.headingWeight,
        letterSpacing: profile.headingLetterSpacing,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: profile.titleWeight,
        letterSpacing: profile.headingLetterSpacing,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: profile.titleWeight,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: profile.bodyHeight),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        height: profile.bodyHeight - .05,
      ),
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(profile.controlRadius),
    );
    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scheme.surface.withValues(alpha: .96),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: profile.cardElevation,
        shadowColor: scheme.shadow.withValues(alpha: .12),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        color: Color.alphaBlend(
          scheme.primary.withValues(alpha: profile.surfaceTint),
          scheme.surfaceContainerLowest,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(profile.cardRadius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .42)),
        ),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(profile.controlRadius),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(profile.controlRadius),
        ),
        labelType: NavigationRailLabelType.none,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: controlShape,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: controlShape,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: controlShape,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: AppElevation.raised,
        highlightElevation: AppElevation.menu,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(profile.controlRadius),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .65)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(profile.pillRadius),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(profile.controlRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: AppElevation.menu,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(profile.dialogRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: AppElevation.menu,
        showDragHandle: true,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(profile.dialogRadius),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: AppElevation.menu,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(profile.controlRadius),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(profile.controlRadius),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .55),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(profile.controlRadius),
        ),
        iconColor: scheme.onSurfaceVariant,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
    );
  }

  static ThemeData lightFor(AppVisualStyle style) =>
      _build(AppColorScheme.lightFor(style), style);

  static ThemeData darkFor(AppVisualStyle style) =>
      _build(AppColorScheme.darkFor(style), style);

  static final light = lightFor(AppVisualStyle.classic);
  static final dark = darkFor(AppVisualStyle.classic);
}

class _ThemeProfile {
  const _ThemeProfile({
    required this.cardRadius,
    required this.controlRadius,
    required this.pillRadius,
    required this.dialogRadius,
    required this.cardElevation,
    required this.surfaceTint,
    required this.headingWeight,
    required this.titleWeight,
    required this.bodyHeight,
    required this.displayLetterSpacing,
    required this.headingLetterSpacing,
  });

  factory _ThemeProfile.forStyle(AppVisualStyle style) => switch (style) {
    AppVisualStyle.classic => const _ThemeProfile(
      cardRadius: AppRadius.card,
      controlRadius: AppRadius.control,
      pillRadius: AppRadius.pill,
      dialogRadius: AppRadius.large,
      cardElevation: AppElevation.card,
      surfaceTint: 0,
      headingWeight: FontWeight.w800,
      titleWeight: FontWeight.w700,
      bodyHeight: 1.45,
      displayLetterSpacing: -1.2,
      headingLetterSpacing: -.4,
    ),
    AppVisualStyle.cozy => const _ThemeProfile(
      cardRadius: 24,
      controlRadius: 18,
      pillRadius: 28,
      dialogRadius: 28,
      cardElevation: 1,
      surfaceTint: .025,
      headingWeight: FontWeight.w700,
      titleWeight: FontWeight.w700,
      bodyHeight: 1.55,
      displayLetterSpacing: -.7,
      headingLetterSpacing: -.2,
    ),
    AppVisualStyle.playful => const _ThemeProfile(
      cardRadius: 28,
      controlRadius: 20,
      pillRadius: 32,
      dialogRadius: 30,
      cardElevation: 2,
      surfaceTint: .035,
      headingWeight: FontWeight.w800,
      titleWeight: FontWeight.w800,
      bodyHeight: 1.45,
      displayLetterSpacing: -.9,
      headingLetterSpacing: -.3,
    ),
    AppVisualStyle.nature => const _ThemeProfile(
      cardRadius: 20,
      controlRadius: 14,
      pillRadius: 24,
      dialogRadius: 24,
      cardElevation: 0,
      surfaceTint: .02,
      headingWeight: FontWeight.w700,
      titleWeight: FontWeight.w700,
      bodyHeight: 1.5,
      displayLetterSpacing: -.8,
      headingLetterSpacing: -.2,
    ),
    AppVisualStyle.academic => const _ThemeProfile(
      cardRadius: 10,
      controlRadius: 8,
      pillRadius: 10,
      dialogRadius: 12,
      cardElevation: 0,
      surfaceTint: .01,
      headingWeight: FontWeight.w700,
      titleWeight: FontWeight.w600,
      bodyHeight: 1.55,
      displayLetterSpacing: -.45,
      headingLetterSpacing: 0,
    ),
    AppVisualStyle.minimal => const _ThemeProfile(
      cardRadius: 8,
      controlRadius: 8,
      pillRadius: 8,
      dialogRadius: 12,
      cardElevation: 0,
      surfaceTint: 0,
      headingWeight: FontWeight.w700,
      titleWeight: FontWeight.w600,
      bodyHeight: 1.5,
      displayLetterSpacing: -.6,
      headingLetterSpacing: 0,
    ),
    AppVisualStyle.midnight => const _ThemeProfile(
      cardRadius: 18,
      controlRadius: 14,
      pillRadius: 24,
      dialogRadius: 22,
      cardElevation: 1,
      surfaceTint: .035,
      headingWeight: FontWeight.w700,
      titleWeight: FontWeight.w700,
      bodyHeight: 1.48,
      displayLetterSpacing: -.8,
      headingLetterSpacing: -.2,
    ),
    AppVisualStyle.creative => const _ThemeProfile(
      cardRadius: 22,
      controlRadius: 16,
      pillRadius: 26,
      dialogRadius: 26,
      cardElevation: 2,
      surfaceTint: .03,
      headingWeight: FontWeight.w800,
      titleWeight: FontWeight.w700,
      bodyHeight: 1.47,
      displayLetterSpacing: -1,
      headingLetterSpacing: -.35,
    ),
  };

  final double cardRadius;
  final double controlRadius;
  final double pillRadius;
  final double dialogRadius;
  final double cardElevation;
  final double surfaceTint;
  final FontWeight headingWeight;
  final FontWeight titleWeight;
  final double bodyHeight;
  final double displayLetterSpacing;
  final double headingLetterSpacing;
}
