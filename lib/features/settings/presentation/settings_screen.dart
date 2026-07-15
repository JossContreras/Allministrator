import 'package:allministrator/app/app.dart';
import 'package:allministrator/app/theme/app_color_scheme.dart';
import 'package:allministrator/app/theme/app_radius.dart';
import 'package:allministrator/app/theme/app_spacing.dart';
import 'package:allministrator/app/theme/app_theme_controller.dart';
import 'package:allministrator/app/theme/app_visual_style.dart';
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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Haz que el espacio se sienta tuyo',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Las preferencias se aplican inmediatamente y se conservan en este dispositivo.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _SettingSection(
                    icon: Icons.palette_outlined,
                    title: 'Apariencia',
                    description:
                        'Cambia la personalidad visual completa y su iluminación.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estilo visual',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _VisualStylePicker(
                          selected: appThemeController.visualStyle,
                          onSelected: appThemeController.setVisualStyle,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Iluminación',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        RadioGroup<AppThemePreference>(
                          groupValue: appThemeController.preference,
                          onChanged: (value) {
                            if (value != null) {
                              appThemeController.setPreference(value);
                            }
                          },
                          child: const Column(
                            children: [
                              _ThemeOption(
                                value: AppThemePreference.system,
                                icon: Icons.brightness_auto_outlined,
                                title: 'Usar configuración del sistema',
                                subtitle:
                                    'Cambia automáticamente entre claro y oscuro.',
                              ),
                              _ThemeOption(
                                value: AppThemePreference.light,
                                icon: Icons.light_mode_outlined,
                                title: 'Claro',
                                subtitle: 'Superficies claras y luminosas.',
                              ),
                              _ThemeOption(
                                value: AppThemePreference.dark,
                                icon: Icons.dark_mode_outlined,
                                title: 'Oscuro',
                                subtitle: 'Menor brillo con contraste cómodo.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _SettingSection(
                    icon: Icons.edit_note_outlined,
                    title: 'Editor',
                    description:
                        'La escritura, Canvas y dibujo comparten una experiencia consistente.',
                    child: Column(
                      children: [
                        _StatusTile(
                          icon: Icons.cloud_done_outlined,
                          title: 'Guardado automático',
                          value: 'Activo',
                        ),
                        _StatusTile(
                          icon: Icons.undo_outlined,
                          title: 'Historial de edición',
                          value: 'Disponible',
                        ),
                        _StatusTile(
                          icon: Icons.space_dashboard_outlined,
                          title: 'Tipos de espacio',
                          value: 'Documento · Canvas',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SettingSection(
                    icon: Icons.accessibility_new_outlined,
                    title: 'Accesibilidad',
                    description:
                        'La aplicación respeta las preferencias configuradas en tu sistema.',
                    child: Column(
                      children: [
                        _StatusTile(
                          icon: Icons.text_fields_outlined,
                          title: 'Escala de texto',
                          value:
                              '${MediaQuery.textScalerOf(context).scale(1).toStringAsFixed(1)}×',
                        ),
                        _StatusTile(
                          icon: Icons.animation_outlined,
                          title: 'Reducir movimiento',
                          value: MediaQuery.disableAnimationsOf(context)
                              ? 'Activo'
                              : 'Inactivo',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _SettingSection(
                    icon: Icons.shield_outlined,
                    title: 'Datos y privacidad',
                    description:
                        'Tu trabajo permanece disponible aun cuando no tienes conexión.',
                    child: Column(
                      children: [
                        _StatusTile(
                          icon: Icons.phone_android_outlined,
                          title: 'Almacenamiento',
                          value: 'En este dispositivo',
                        ),
                        _StatusTile(
                          icon: Icons.offline_bolt_outlined,
                          title: 'Trabajo sin conexión',
                          value: 'Disponible',
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

class _SettingSection extends StatelessWidget {
  const _SettingSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    ),
  );
}

class _VisualStylePicker extends StatelessWidget {
  const _VisualStylePicker({required this.selected, required this.onSelected});

  final AppVisualStyle selected;
  final ValueChanged<AppVisualStyle> onSelected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(AppRadius.control),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Column(
        children: [
          for (
            var index = 0;
            index < AppVisualStyle.values.length;
            index++
          ) ...[
            _VisualStyleOption(
              style: AppVisualStyle.values[index],
              selected: AppVisualStyle.values[index] == selected,
              onTap: () => onSelected(AppVisualStyle.values[index]),
            ),
            if (index < AppVisualStyle.values.length - 1)
              const Divider(height: 1, indent: 54),
          ],
        ],
      ),
    ),
  );
}

class _VisualStyleOption extends StatelessWidget {
  const _VisualStyleOption({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final AppVisualStyle style;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (style) {
    AppVisualStyle.classic => Icons.auto_awesome_mosaic_outlined,
    AppVisualStyle.cozy => Icons.local_cafe_outlined,
    AppVisualStyle.playful => Icons.sentiment_very_satisfied_outlined,
    AppVisualStyle.nature => Icons.eco_outlined,
    AppVisualStyle.academic => Icons.school_outlined,
    AppVisualStyle.minimal => Icons.horizontal_rule_rounded,
    AppVisualStyle.midnight => Icons.nightlight_outlined,
    AppVisualStyle.creative => Icons.palette_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = AppColorScheme.previewColor(style);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Estilo ${style.label}',
      child: Material(
        color: selected
            ? colors.primaryContainer.withValues(alpha: .42)
            : colors.surfaceContainerLowest,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Icon(_icon, size: 18, color: accent),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: style.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: '  ·  ${style.description}',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (selected)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      size: 20,
                      color: colors.primary,
                    ),
                  )
                else
                  const SizedBox(width: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final AppThemePreference value;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => RadioListTile<AppThemePreference>(
    value: value,
    secondary: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
  );
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    leading: Icon(icon),
    title: Text(title),
    trailing: Text(
      value,
      textAlign: TextAlign.end,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
