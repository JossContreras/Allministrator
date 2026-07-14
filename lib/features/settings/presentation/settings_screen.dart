import 'package:allministrator/app/app.dart';
import 'package:allministrator/app/theme/app_theme_controller.dart';
import 'package:allministrator/features/shared/presentation/main_navigation_scaffold.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: appThemeController,
    builder: (context, _) => MainNavigationScaffold(
      title: 'Configuración',
      selectedPath: '/settings',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Apariencia', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tema'),
                  const SizedBox(height: 8),
                  RadioGroup<AppThemePreference>(
                    groupValue: appThemeController.preference,
                    onChanged: (value) {
                      if (value != null) {
                        appThemeController.setPreference(value);
                      }
                    },
                    child: const Column(
                      children: [
                        RadioListTile(
                          value: AppThemePreference.system,
                          title: Text('Usar configuración del sistema'),
                        ),
                        RadioListTile(
                          value: AppThemePreference.light,
                          title: Text('Claro'),
                        ),
                        RadioListTile(
                          value: AppThemePreference.dark,
                          title: Text('Oscuro'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
