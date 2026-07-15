import 'package:allministrator/domain/ink/ink_models.dart';
import 'package:allministrator/app/theme/app_radius.dart';
import 'package:allministrator/domain/interaction/interaction_models.dart';
import 'package:flutter/material.dart';

class InkToolbar extends StatelessWidget {
  const InkToolbar({
    required this.activeTool,
    required this.style,
    required this.hasSelection,
    required this.canUndo,
    required this.canRedo,
    required this.onTool,
    required this.onColor,
    required this.onWidth,
    required this.onOpacity,
    required this.onUndo,
    required this.onRedo,
    required this.onDuplicate,
    required this.onDelete,
    required this.onMove,
    required this.onClose,
    super.key,
  });

  final WorkspaceTool activeTool;
  final InkBrushStyle style;
  final bool hasSelection;
  final bool canUndo;
  final bool canRedo;
  final ValueChanged<WorkspaceTool> onTool;
  final ValueChanged<int> onColor;
  final ValueChanged<double> onWidth;
  final ValueChanged<double> onOpacity;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final ValueChanged<Offset> onMove;
  final VoidCallback onClose;

  static const _colors = <int>[
    0xFF1F2937,
    0xFF2563EB,
    0xFFDC2626,
    0xFF059669,
    0xFF7C3AED,
    0xFFFFD54F,
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      key: const ValueKey('ink-toolbar'),
      elevation: 6,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tool(context, WorkspaceTool.pen, Icons.draw_outlined, 'Pluma'),
            _tool(
              context,
              WorkspaceTool.highlighter,
              Icons.border_color_outlined,
              'Resaltador',
            ),
            _tool(
              context,
              WorkspaceTool.eraser,
              Icons.auto_fix_normal_outlined,
              'Borrador de tinta',
            ),
            _tool(
              context,
              WorkspaceTool.inkLasso,
              Icons.gesture_outlined,
              'Lazo de tinta',
            ),
            PopupMenuButton<WorkspaceTool>(
              tooltip: 'Formas',
              icon: Icon(
                activeTool.isInkShape
                    ? _shapeIcon(activeTool)
                    : Icons.category_outlined,
                color: activeTool.isInkShape
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              onSelected: onTool,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: WorkspaceTool.line,
                  child: ListTile(
                    leading: Icon(Icons.horizontal_rule),
                    title: Text('Línea'),
                  ),
                ),
                PopupMenuItem(
                  value: WorkspaceTool.arrow,
                  child: ListTile(
                    leading: Icon(Icons.arrow_right_alt),
                    title: Text('Flecha'),
                  ),
                ),
                PopupMenuItem(
                  value: WorkspaceTool.rectangle,
                  child: ListTile(
                    leading: Icon(Icons.rectangle_outlined),
                    title: Text('Rectángulo'),
                  ),
                ),
                PopupMenuItem(
                  value: WorkspaceTool.ellipse,
                  child: ListTile(
                    leading: Icon(Icons.circle_outlined),
                    title: Text('Elipse'),
                  ),
                ),
              ],
            ),
            const VerticalDivider(width: 12),
            PopupMenuButton<int>(
              tooltip: 'Color de tinta',
              onSelected: onColor,
              icon: Icon(Icons.circle, color: Color(style.color)),
              itemBuilder: (_) => [
                for (final color in _colors)
                  PopupMenuItem(
                    value: color,
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: Color(color)),
                        const SizedBox(width: 12),
                        Text(
                          color == style.color ? 'Color activo' : 'Usar color',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            PopupMenuButton<double>(
              tooltip: 'Grosor ${style.baseWidth.toStringAsFixed(0)}',
              onSelected: onWidth,
              icon: const Icon(Icons.line_weight),
              itemBuilder: (_) => [
                for (final width in [2.0, 3.0, 6.0, 12.0, 20.0])
                  PopupMenuItem(
                    value: width,
                    child: SizedBox(
                      width: 120,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Divider(thickness: width.clamp(1, 10)),
                          ),
                          const SizedBox(width: 12),
                          Text('${width.toInt()} px'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            PopupMenuButton<double>(
              tooltip: 'Opacidad ${(style.opacity * 100).round()}%',
              onSelected: onOpacity,
              icon: const Icon(Icons.opacity_outlined),
              itemBuilder: (_) => [
                for (final opacity in [.25, .5, .75, 1.0])
                  PopupMenuItem(
                    value: opacity,
                    child: Text('${(opacity * 100).round()}%'),
                  ),
              ],
            ),
            const VerticalDivider(width: 12),
            IconButton(
              tooltip: 'Deshacer',
              onPressed: canUndo ? onUndo : null,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'Rehacer',
              onPressed: canRedo ? onRedo : null,
              icon: const Icon(Icons.redo),
            ),
            if (hasSelection) ...[
              const VerticalDivider(width: 12),
              IconButton(
                tooltip: 'Mover tinta a la izquierda',
                onPressed: () => onMove(const Offset(-12, 0)),
                icon: const Icon(Icons.arrow_left),
              ),
              IconButton(
                tooltip: 'Mover tinta hacia arriba',
                onPressed: () => onMove(const Offset(0, -12)),
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Mover tinta hacia abajo',
                onPressed: () => onMove(const Offset(0, 12)),
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                tooltip: 'Mover tinta a la derecha',
                onPressed: () => onMove(const Offset(12, 0)),
                icon: const Icon(Icons.arrow_right),
              ),
              IconButton(
                tooltip: 'Duplicar tinta seleccionada',
                onPressed: onDuplicate,
                icon: const Icon(Icons.copy_outlined),
              ),
              IconButton(
                tooltip: 'Eliminar tinta seleccionada',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
            const VerticalDivider(width: 12),
            IconButton(
              tooltip: 'Salir de tinta',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _tool(
    BuildContext context,
    WorkspaceTool tool,
    IconData icon,
    String label,
  ) {
    final selected = activeTool == tool;
    return IconButton(
      tooltip: label,
      isSelected: selected,
      onPressed: () => onTool(tool),
      icon: Icon(icon),
      selectedIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
    );
  }

  static IconData _shapeIcon(WorkspaceTool tool) => switch (tool) {
    WorkspaceTool.line => Icons.horizontal_rule,
    WorkspaceTool.arrow => Icons.arrow_right_alt,
    WorkspaceTool.rectangle => Icons.rectangle_outlined,
    WorkspaceTool.ellipse => Icons.circle_outlined,
    _ => Icons.category_outlined,
  };
}
