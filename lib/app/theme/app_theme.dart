import 'package:flutter/material.dart';
import 'app_color_scheme.dart';
import 'app_radius.dart';

abstract final class AppTheme {
  static ThemeData _build(ColorScheme scheme) => ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: scheme.surfaceContainerLow,
    ),
  );
  static final light = _build(AppColorScheme.light);
  static final dark = _build(AppColorScheme.dark);
}
