import 'package:flutter/material.dart';

abstract final class AppColorScheme {
  static final light = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6750A4),
    brightness: Brightness.light,
  );
  static final dark = ColorScheme.fromSeed(
    seedColor: const Color(0xFFD0BCFF),
    brightness: Brightness.dark,
  );
}
