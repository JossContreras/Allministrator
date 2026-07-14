import 'package:allministrator/app/constants/app_constants.dart';
import 'package:allministrator/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Punto de composición de la aplicación.
///
/// No declara una pantalla inicial: la navegación se incorporará cuando se
/// implemente el primer flujo de presentación.
class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: AppConstants.applicationName,
        theme: AppTheme.light,
      );
}
