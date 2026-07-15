import 'package:allministrator/app/constants/app_constants.dart';
import 'package:allministrator/app/theme/app_icons.dart';
import 'package:allministrator/app/theme/app_radius.dart';
import 'package:allministrator/app/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppNavigationDestination {
  const AppNavigationDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.group,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String group;
}

const appNavigationDestinations = <AppNavigationDestination>[
  AppNavigationDestination(
    path: '/home',
    label: 'Inicio',
    icon: AppIcons.home,
    selectedIcon: AppIcons.homeSelected,
    group: 'Tu espacio',
  ),
  AppNavigationDestination(
    path: '/documents',
    label: 'Mis documentos',
    icon: AppIcons.documents,
    selectedIcon: AppIcons.documentsSelected,
    group: 'Tu espacio',
  ),
  AppNavigationDestination(
    path: '/canvas',
    label: 'Canvas',
    icon: AppIcons.canvas,
    selectedIcon: AppIcons.canvasSelected,
    group: 'Tu espacio',
  ),
  AppNavigationDestination(
    path: '/library',
    label: 'Biblioteca',
    icon: Icons.folder_copy_outlined,
    selectedIcon: Icons.folder_copy_rounded,
    group: 'Tu espacio',
  ),
  AppNavigationDestination(
    path: '/recent',
    label: 'Recientes',
    icon: AppIcons.recent,
    selectedIcon: AppIcons.recentSelected,
    group: 'Tu espacio',
  ),
  AppNavigationDestination(
    path: '/favorites',
    label: 'Favoritos',
    icon: AppIcons.favorite,
    selectedIcon: AppIcons.favoriteSelected,
    group: 'Tu espacio',
  ),
  AppNavigationDestination(
    path: '/tags',
    label: 'Categorías',
    icon: AppIcons.category,
    selectedIcon: AppIcons.categorySelected,
    group: 'Organiza',
  ),
  AppNavigationDestination(
    path: '/templates',
    label: 'Plantillas',
    icon: AppIcons.templates,
    selectedIcon: AppIcons.templatesSelected,
    group: 'Organiza',
  ),
  AppNavigationDestination(
    path: '/trash',
    label: 'Papelera',
    icon: AppIcons.trash,
    selectedIcon: AppIcons.trashSelected,
    group: 'Organiza',
  ),
  AppNavigationDestination(
    path: '/settings',
    label: 'Configuración',
    icon: AppIcons.settings,
    selectedIcon: AppIcons.settingsSelected,
    group: 'Aplicación',
  ),
  AppNavigationDestination(
    path: '/about',
    label: 'Acerca de',
    icon: AppIcons.about,
    selectedIcon: AppIcons.aboutSelected,
    group: 'Aplicación',
  ),
];

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({
    required this.selectedPath,
    this.closeOnSelect = true,
    super.key,
  });

  final String selectedPath;
  final bool closeOnSelect;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = appNavigationDestinations.indexWhere(
      (destination) => destination.path == selectedPath,
    );
    String? currentGroup;
    final children = <Widget>[
      const _BrandHeader(),
      const SizedBox(height: AppSpacing.sm),
    ];
    for (final destination in appNavigationDestinations) {
      if (currentGroup != destination.group) {
        if (currentGroup != null) {
          children.add(
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Divider(),
            ),
          );
        }
        currentGroup = destination.group;
        children.add(_SectionLabel(destination.group));
      }
      children.add(
        NavigationDrawerDestination(
          icon: Icon(destination.icon),
          selectedIcon: Icon(destination.selectedIcon),
          label: Text(destination.label),
        ),
      );
    }

    return NavigationDrawer(
      selectedIndex: selectedIndex < 0 ? null : selectedIndex,
      onDestinationSelected: (index) {
        if (closeOnSelect) Navigator.of(context).pop();
        context.go(appNavigationDestinations[index].path);
      },
      children: children,
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primary, colors.tertiary],
              ),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: colors.onPrimary),
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.applicationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Tu espacio creativo',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 12, 16, 6),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: .8,
      ),
    ),
  );
}
