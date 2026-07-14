import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({required this.selectedPath, super.key});

  final String selectedPath;

  static const _destinations = <({String path, String label, IconData icon})>[
    (
      path: '/documents',
      label: 'Mis documentos',
      icon: Icons.description_outlined,
    ),
    (path: '/recent', label: 'Recientes', icon: Icons.access_time_outlined),
    (path: '/favorites', label: 'Favoritos', icon: Icons.star_border),
    (path: '/folders', label: 'Carpetas', icon: Icons.folder_outlined),
    (path: '/tags', label: 'Etiquetas', icon: Icons.label_outline),
    (
      path: '/templates',
      label: 'Plantillas',
      icon: Icons.dashboard_customize_outlined,
    ),
    (path: '/trash', label: 'Papelera', icon: Icons.delete_outline),
    (path: '/backups', label: 'Respaldos', icon: Icons.backup_outlined),
    (path: '/settings', label: 'Configuración', icon: Icons.settings_outlined),
    (path: '/about', label: 'Acerca de', icon: Icons.info_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _destinations.indexWhere(
      (destination) => destination.path == selectedPath,
    );

    return NavigationDrawer(
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: (index) {
        Navigator.of(context).pop();
        context.go(_destinations[index].path);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 16, 16),
          child: Text(
            'Allministrator',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ..._destinations.map(
          (destination) => NavigationDrawerDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.icon),
            label: Text(destination.label),
          ),
        ),
      ],
    );
  }
}
