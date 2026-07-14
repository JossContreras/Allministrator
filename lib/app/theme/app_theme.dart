import 'package:flutter/material.dart';

/// Punto único para los temas visuales futuros.
abstract final class AppTheme {
  static final ThemeData light = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
  );
}
