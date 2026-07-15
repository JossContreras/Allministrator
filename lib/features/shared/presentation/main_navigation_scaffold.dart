import 'package:allministrator/features/shared/presentation/navigation_drawer.dart';
import 'package:allministrator/app/theme/app_spacing.dart';
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final showPersistentNavigation = constraints.maxWidth >= 980;
      final appBar = AppBar(
        titleSpacing: showPersistentNavigation ? AppSpacing.lg : null,
        title: Text(title),
        actions: actions,
      );
      if (!showPersistentNavigation) {
        return Scaffold(
          appBar: appBar,
          drawer: AppNavigationDrawer(selectedPath: selectedPath),
          body: child,
          floatingActionButton: floatingActionButton,
        );
      }
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 292,
              child: AppNavigationDrawer(
                selectedPath: selectedPath,
                closeOnSelect: false,
              ),
            ),
            VerticalDivider(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(
              child: Scaffold(
                appBar: appBar,
                body: child,
                floatingActionButton: floatingActionButton,
              ),
            ),
          ],
        ),
      );
    },
  );
}
