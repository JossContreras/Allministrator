import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/editing/workspace_editor_session.dart';
import 'package:flutter/material.dart';

class BlockFrame extends StatelessWidget {
  const BlockFrame({
    required this.block,
    required this.session,
    required this.child,
    required this.onTap,
    this.compact = false,
    this.readOnly = false,
    super.key,
  });

  final BaseBlock block;
  final WorkspaceEditorSession session;
  final Widget child;
  final VoidCallback onTap;
  final bool compact;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final selected = session.selectedBlockId == block.id;
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      selected: selected,
      label: 'Bloque ${_label(block.type)}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: EdgeInsets.symmetric(vertical: compact ? 2 : 5),
        padding: EdgeInsets.all(selected ? 8 : 2),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.22)
              : Colors.transparent,
          border: Border.all(
            color: selected ? colorScheme.primary : Colors.transparent,
            width: selected ? 1.4 : 0,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selected && !readOnly) _actions(context),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onTap,
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) => Row(
    children: [
      const Icon(Icons.drag_indicator, size: 18),
      const SizedBox(width: 4),
      Text(_label(block.type), style: Theme.of(context).textTheme.labelSmall),
      const Spacer(),
      if (block.supports(BlockCapability.movable)) ...[
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Mover arriba',
          onPressed: () => session.moveBlock(block.id, -1),
          icon: const Icon(Icons.keyboard_arrow_up, size: 20),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Mover abajo',
          onPressed: () => session.moveBlock(block.id, 1),
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
        ),
      ],
      if (block.supports(BlockCapability.duplicable))
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Duplicar bloque',
          onPressed: () => session.duplicateBlock(block.id),
          icon: const Icon(Icons.content_copy, size: 18),
        ),
      if (block.supports(BlockCapability.lockable))
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: block.isLocked ? 'Desbloquear' : 'Bloquear',
          onPressed: () => session.updateBlock(
            block.copyWithCommon(isLocked: !block.isLocked),
            kind: 'lockBlock',
            refreshPresentation: true,
          ),
          icon: Icon(block.isLocked ? Icons.lock : Icons.lock_open, size: 18),
        ),
      if (block.supports(BlockCapability.deletable))
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Eliminar bloque',
          onPressed: () => session.deleteBlock(block.id),
          icon: const Icon(Icons.delete_outline, size: 19),
        ),
    ],
  );

  String _label(BlockType type) => switch (type) {
    BlockType.text => 'Texto',
    BlockType.image => 'Imagen',
    BlockType.divider => 'Separador',
    BlockType.checklist => 'Checklist',
    BlockType.code => 'Código',
    BlockType.table => 'Tabla',
    BlockType.attachment => 'Archivo',
    BlockType.quote => 'Cita',
    BlockType.callout => 'Callout',
    BlockType.unknown => 'No compatible',
  };
}
