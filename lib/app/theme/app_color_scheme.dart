import 'package:flutter/material.dart';
import 'app_visual_style.dart';

abstract final class AppColorScheme {
  static ColorScheme lightFor(AppVisualStyle style) =>
      _build(style, Brightness.light);

  static ColorScheme darkFor(AppVisualStyle style) =>
      _build(style, Brightness.dark);

  static Color previewColor(AppVisualStyle style) => _palette(style).primary;

  static ColorScheme _build(AppVisualStyle style, Brightness brightness) {
    final palette = _palette(style);
    final dark = brightness == Brightness.dark;
    final primary = dark ? palette.darkPrimary : palette.primary;
    return ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      secondary: dark ? palette.darkSecondary : palette.secondary,
      tertiary: dark ? palette.darkTertiary : palette.tertiary,
      surface: dark ? palette.darkSurface : palette.surface,
    );
  }

  static _StylePalette _palette(AppVisualStyle style) => switch (style) {
    AppVisualStyle.classic => const _StylePalette(
      primary: Color(0xFF5555C8),
      secondary: Color(0xFFB85F4B),
      tertiary: Color(0xFF287C6C),
      surface: Color(0xFFFFFBF7),
      darkPrimary: Color(0xFFC6C4FF),
      darkSecondary: Color(0xFFFFB5A4),
      darkTertiary: Color(0xFF83D6C1),
      darkSurface: Color(0xFF121316),
    ),
    AppVisualStyle.cozy => const _StylePalette(
      primary: Color(0xFF8A5B3D),
      secondary: Color(0xFFA94F5B),
      tertiary: Color(0xFF7A7045),
      surface: Color(0xFFFFF7EE),
      darkPrimary: Color(0xFFFFB888),
      darkSecondary: Color(0xFFFFB0B9),
      darkTertiary: Color(0xFFD6C98B),
      darkSurface: Color(0xFF1B1512),
    ),
    AppVisualStyle.playful => const _StylePalette(
      primary: Color(0xFF7354D8),
      secondary: Color(0xFFE04B87),
      tertiary: Color(0xFF008CA2),
      surface: Color(0xFFFFFAFF),
      darkPrimary: Color(0xFFD0BCFF),
      darkSecondary: Color(0xFFFFAFD0),
      darkTertiary: Color(0xFF70D5EA),
      darkSurface: Color(0xFF17131F),
    ),
    AppVisualStyle.nature => const _StylePalette(
      primary: Color(0xFF3F7156),
      secondary: Color(0xFF8B6746),
      tertiary: Color(0xFF54717A),
      surface: Color(0xFFF8FBF3),
      darkPrimary: Color(0xFFA5D5B5),
      darkSecondary: Color(0xFFDDBB97),
      darkTertiary: Color(0xFFA5CCD5),
      darkSurface: Color(0xFF111914),
    ),
    AppVisualStyle.academic => const _StylePalette(
      primary: Color(0xFF344E75),
      secondary: Color(0xFF76546F),
      tertiary: Color(0xFF5B6750),
      surface: Color(0xFFF9FAFC),
      darkPrimary: Color(0xFFADC7F0),
      darkSecondary: Color(0xFFE0B9D6),
      darkTertiary: Color(0xFFC1CEB4),
      darkSurface: Color(0xFF11151B),
    ),
    AppVisualStyle.minimal => const _StylePalette(
      primary: Color(0xFF3F4854),
      secondary: Color(0xFF5C6672),
      tertiary: Color(0xFF596B68),
      surface: Color(0xFFFCFCFD),
      darkPrimary: Color(0xFFC3C9D1),
      darkSecondary: Color(0xFFC4CAD2),
      darkTertiary: Color(0xFFBBCBC7),
      darkSurface: Color(0xFF111315),
    ),
    AppVisualStyle.midnight => const _StylePalette(
      primary: Color(0xFF465BCB),
      secondary: Color(0xFF7654A8),
      tertiary: Color(0xFF247C82),
      surface: Color(0xFFF5F7FF),
      darkPrimary: Color(0xFFAFC2FF),
      darkSecondary: Color(0xFFD4B6FF),
      darkTertiary: Color(0xFF7CD5DD),
      darkSurface: Color(0xFF080B16),
    ),
    AppVisualStyle.creative => const _StylePalette(
      primary: Color(0xFFB83D72),
      secondary: Color(0xFFCB681F),
      tertiary: Color(0xFF3569BC),
      surface: Color(0xFFFFF9F7),
      darkPrimary: Color(0xFFFFAFCE),
      darkSecondary: Color(0xFFFFB77A),
      darkTertiary: Color(0xFFAEC6FF),
      darkSurface: Color(0xFF1A1015),
    ),
  };

  static final light = lightFor(AppVisualStyle.classic);
  static final dark = darkFor(AppVisualStyle.classic);
}

class _StylePalette {
  const _StylePalette({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.surface,
    required this.darkPrimary,
    required this.darkSecondary,
    required this.darkTertiary,
    required this.darkSurface,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color surface;
  final Color darkPrimary;
  final Color darkSecondary;
  final Color darkTertiary;
  final Color darkSurface;
}
