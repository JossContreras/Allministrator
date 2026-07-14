import 'package:allministrator/features/shared/presentation/main_navigation_scaffold.dart';
import 'package:flutter/material.dart';

/// Pantalla compartida para secciones que aún no tienen contenido real.
class PlaceholderSectionScreen extends StatelessWidget {
  const PlaceholderSectionScreen({
    required this.title,
    required this.path,
    super.key,
  });

  final String title;
  final String path;

  @override
  Widget build(BuildContext context) => MainNavigationScaffold(
    title: title,
    selectedPath: path,
    child: Center(
      child: Text(
        'Contenido pendiente',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
  );
}
