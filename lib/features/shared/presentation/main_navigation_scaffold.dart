import 'package:allministrator/features/shared/presentation/navigation_drawer.dart';
import 'package:flutter/material.dart';

/// Shell común de las secciones que pertenecen a la navegación principal.
///
/// La estrategia de navegación está aislada aquí para que posteriormente se
/// pueda elegir NavigationRail o NavigationBar en superficies más grandes sin
/// modificar las pantallas internas.
class MainNavigationScaffold extends StatelessWidget {
  const MainNavigationScaffold({
    required this.title,
    required this.selectedPath,
    required this.child,
    this.actions,
    this.floatingActionButton,
    super.key,
  });

  final String title;
  final String selectedPath;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    drawer: AppNavigationDrawer(selectedPath: selectedPath),
    body: child,
    floatingActionButton: floatingActionButton,
  );
}
