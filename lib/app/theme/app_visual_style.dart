enum AppVisualStyle {
  classic,
  cozy,
  playful,
  nature,
  academic,
  minimal,
  midnight,
  creative,
}

extension AppVisualStyleDescription on AppVisualStyle {
  String get label => switch (this) {
    AppVisualStyle.classic => 'Classic',
    AppVisualStyle.cozy => 'Cozy',
    AppVisualStyle.playful => 'Playful',
    AppVisualStyle.nature => 'Nature',
    AppVisualStyle.academic => 'Academic',
    AppVisualStyle.minimal => 'Minimal',
    AppVisualStyle.midnight => 'Midnight',
    AppVisualStyle.creative => 'Creative',
  };

  String get description => switch (this) {
    AppVisualStyle.classic => 'Equilibrado, familiar y versátil.',
    AppVisualStyle.cozy => 'Cálido, suave y cómodo para escribir.',
    AppVisualStyle.playful => 'Vivo, redondeado y expresivo.',
    AppVisualStyle.nature => 'Sereno, orgánico y concentrado.',
    AppVisualStyle.academic => 'Sobrio, estructurado y preciso.',
    AppVisualStyle.minimal => 'Limpio, directo y sin distracciones.',
    AppVisualStyle.midnight => 'Profundo, oscuro y de alto contraste.',
    AppVisualStyle.creative => 'Enérgico, contrastante e inspirador.',
  };
}
