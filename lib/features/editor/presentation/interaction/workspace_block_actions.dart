import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/editing/workspace_editor_session.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:flutter/material.dart';

class WorkspaceBlockActions extends StatelessWidget {
  const WorkspaceBlockActions({
    required this.block,
    required this.session,
    required this.interaction,
    required this.onReplaceImage,
    required this.onEditImageDetails,
    required this.onReplaceAttachment,
    required this.onOpenAttachment,
    required this.onEditAttachmentDetails,
    this.onAlignSelection = _ignoreAlignment,
    this.onDistributeSelection = _ignoreAction,
    super.key,
  });

  final BaseBlock block;
  final WorkspaceEditorSession session;
  final WorkspaceInteractionController interaction;
  final Future<void> Function(ImageBlock block) onReplaceImage;
  final Future<void> Function(ImageBlock block) onEditImageDetails;
  final Future<void> Function(AttachmentBlock block) onReplaceAttachment;
  final Future<void> Function(AttachmentBlock block) onOpenAttachment;
  final Future<void> Function(AttachmentBlock block) onEditAttachmentDetails;
  final ValueChanged<BlockAlignmentAxis> onAlignSelection;
  final VoidCallback onDistributeSelection;

  @override
  Widget build(BuildContext context) {
    final selectionCount = switch (interaction.context.currentSelection) {
      MultiBlockSelection(:final group) => group.count,
      BlockSelection() => 1,
      _ => 0,
    };
    return Material(
      elevation: 3,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectionCount >= 2) ...[
              _button(
                tooltip: 'Alinear a la izquierda',
                icon: Icons.align_horizontal_left,
                onPressed: () => onAlignSelection(BlockAlignmentAxis.left),
              ),
              _button(
                tooltip: 'Centrar horizontalmente',
                icon: Icons.align_horizontal_center,
                onPressed: () =>
                    onAlignSelection(BlockAlignmentAxis.horizontalCenter),
              ),
              _button(
                tooltip: 'Alinear a la derecha',
                icon: Icons.align_horizontal_right,
                onPressed: () => onAlignSelection(BlockAlignmentAxis.right),
              ),
              if (selectionCount >= 3)
                _button(
                  tooltip: 'Distribuir verticalmente',
                  icon: Icons.space_bar,
                  onPressed: onDistributeSelection,
                ),
            ],
            if (block.supports(BlockCapability.movable)) ...[
              _button(
                tooltip: 'Mover arriba',
                icon: Icons.keyboard_arrow_up,
                onPressed: () => session.moveBlock(block.id, -1),
              ),
              _button(
                tooltip: 'Mover abajo',
                icon: Icons.keyboard_arrow_down,
                onPressed: () => session.moveBlock(block.id, 1),
              ),
            ],
            if (block is TextBlock && session.canMergeTextWithNext(block.id))
              _button(
                tooltip: 'Fusionar con el siguiente texto',
                icon: Icons.merge_type,
                onPressed: () => session.mergeTextWithNext(block.id),
              ),
            if (_optionsFor(block).isNotEmpty)
              PopupMenuButton<String>(
                tooltip: 'Opciones del bloque',
                icon: const Icon(Icons.tune),
                onOpened: () => interaction.dispatch(
                  OpenContextMenuIntent(blockId: block.id),
                ),
                onCanceled: _finishMenu,
                onSelected: (value) {
                  _handleOption(value);
                  _finishMenu();
                },
                itemBuilder: (_) => _optionsFor(block),
              ),
            if (block.supports(BlockCapability.duplicable))
              _button(
                tooltip: 'Duplicar bloque',
                icon: Icons.content_copy_outlined,
                onPressed: () {
                  final duplicateId = session.duplicateBlock(block.id);
                  if (duplicateId != null) {
                    interaction.dispatch(SelectBlockIntent(duplicateId));
                  }
                },
              ),
            if (block.supports(BlockCapability.lockable))
              _button(
                tooltip: block.isLocked ? 'Desbloquear' : 'Bloquear',
                icon: block.isLocked ? Icons.lock : Icons.lock_open,
                onPressed: () => _update(
                  block.copyWithCommon(isLocked: !block.isLocked),
                  'lockBlock',
                ),
              ),
            if (block.supports(BlockCapability.deletable))
              _button(
                tooltip: 'Eliminar bloque',
                icon: Icons.delete_outline,
                onPressed: () {
                  interaction.dispatch(
                    const CancelInteractionIntent(
                      reason: InteractionCancellationReason.blockDeleted,
                    ),
                  );
                  session.deleteBlock(block.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _button({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    onPressed: onPressed,
    icon: Icon(icon),
  );

  List<PopupMenuEntry<String>> _optionsFor(BaseBlock value) => switch (value) {
    ImageBlock() => const [
      PopupMenuItem(
        value: 'image-align-left',
        child: Text('Alinear izquierda'),
      ),
      PopupMenuItem(value: 'image-align-center', child: Text('Centrar')),
      PopupMenuItem(value: 'image-align-right', child: Text('Alinear derecha')),
      PopupMenuDivider(),
      PopupMenuItem(value: 'image-size-small', child: Text('Tamaño pequeño')),
      PopupMenuItem(value: 'image-size-medium', child: Text('Tamaño mediano')),
      PopupMenuItem(value: 'image-size-large', child: Text('Tamaño grande')),
      PopupMenuItem(value: 'image-details', child: Text('Alt text y caption')),
      PopupMenuItem(value: 'image-replace', child: Text('Reemplazar imagen')),
    ],
    DividerBlock() => const [
      PopupMenuItem(value: 'divider-solid', child: Text('Línea sólida')),
      PopupMenuItem(value: 'divider-dashed', child: Text('Línea discontinua')),
      PopupMenuItem(value: 'divider-1', child: Text('Grosor 1 px')),
      PopupMenuItem(value: 'divider-2', child: Text('Grosor 2 px')),
      PopupMenuItem(value: 'divider-3', child: Text('Grosor 3 px')),
    ],
    ChecklistBlock() => const [
      PopupMenuItem(value: 'checklist-add', child: Text('Agregar elemento')),
    ],
    TableBlock() => const [
      PopupMenuItem(value: 'table-add-row', child: Text('Agregar fila')),
      PopupMenuItem(
        value: 'table-remove-row',
        child: Text('Eliminar última fila'),
      ),
      PopupMenuItem(value: 'table-add-column', child: Text('Agregar columna')),
      PopupMenuItem(
        value: 'table-remove-column',
        child: Text('Eliminar última columna'),
      ),
    ],
    CalloutBlock() => [
      for (final type in BlockCalloutType.values)
        PopupMenuItem(
          value: 'callout-${type.name}',
          child: Text(_calloutLabel(type)),
        ),
    ],
    AttachmentBlock() => const [
      PopupMenuItem(value: 'attachment-open', child: Text('Abrir archivo')),
      PopupMenuItem(
        value: 'attachment-details',
        child: Text('Nombre y descripción'),
      ),
      PopupMenuItem(
        value: 'attachment-replace',
        child: Text('Reemplazar archivo'),
      ),
    ],
    CodeBlock() => const [
      PopupMenuItem(
        value: 'code-lines',
        child: Text('Alternar números de línea'),
      ),
      PopupMenuItem(
        value: 'code-wrap',
        child: Text('Alternar ajuste de líneas'),
      ),
    ],
    _ => const [],
  };

  void _handleOption(String option) {
    final value = block;
    if (value is ImageBlock) {
      if (option == 'image-details') {
        onEditImageDetails(value);
        return;
      }
      if (option == 'image-replace') {
        onReplaceImage(value);
        return;
      }
      final alignment = switch (option) {
        'image-align-left' => BlockAlignment.left,
        'image-align-center' => BlockAlignment.center,
        'image-align-right' => BlockAlignment.right,
        _ => null,
      };
      final size = switch (option) {
        'image-size-small' => ImageDisplaySize.small,
        'image-size-medium' => ImageDisplaySize.medium,
        'image-size-large' => ImageDisplaySize.large,
        _ => null,
      };
      if (alignment != null) {
        _update(value.copyWith(alignment: alignment), 'updateImageAlignment');
      } else if (size != null) {
        _update(value.copyWith(displaySize: size), 'updateImageSize');
      }
      return;
    }
    if (value is DividerBlock) {
      final style = switch (option) {
        'divider-solid' => DividerStyle.solid,
        'divider-dashed' => DividerStyle.dashed,
        _ => null,
      };
      final thickness = switch (option) {
        'divider-1' => 1.0,
        'divider-2' => 2.0,
        'divider-3' => 3.0,
        _ => null,
      };
      if (style != null) {
        _update(value.copyWith(style: style), 'updateDivider');
      } else if (thickness != null) {
        _update(value.copyWith(thickness: thickness), 'updateDivider');
      }
      return;
    }
    if (value is ChecklistBlock && option == 'checklist-add') {
      _update(
        value.copyWith(
          items: [
            ...value.items,
            BlockChecklistItem(id: generateUuid(), text: ''),
          ],
        ),
        'addChecklistItem',
      );
      return;
    }
    if (value is TableBlock) {
      _updateTable(value, option);
      return;
    }
    if (value is CalloutBlock && option.startsWith('callout-')) {
      final name = option.substring('callout-'.length);
      final type = BlockCalloutType.values.firstWhere(
        (candidate) => candidate.name == name,
      );
      _update(value.copyWith(calloutType: type), 'updateCalloutType');
      return;
    }
    if (value is AttachmentBlock && option == 'attachment-replace') {
      onReplaceAttachment(value);
      return;
    }
    if (value is AttachmentBlock && option == 'attachment-open') {
      onOpenAttachment(value);
      return;
    }
    if (value is AttachmentBlock && option == 'attachment-details') {
      onEditAttachmentDetails(value);
      return;
    }
    if (value is CodeBlock) {
      if (option == 'code-lines') {
        _update(
          value.copyWith(showLineNumbers: !value.showLineNumbers),
          'updateCodeOptions',
        );
      }
      if (option == 'code-wrap') {
        _update(
          value.copyWith(wrapLines: !value.wrapLines),
          'updateCodeOptions',
        );
      }
    }
  }

  void _updateTable(TableBlock table, String option) {
    if (option == 'table-add-row' && table.rows.length < 8) {
      _update(
        table.copyWith(
          rows: [
            ...table.rows,
            BlockTableRow(
              id: generateUuid(),
              cells: List.generate(
                table.columnCount,
                (_) => BlockTableCell(id: generateUuid()),
              ),
            ),
          ],
        ),
        'addTableRow',
      );
    } else if (option == 'table-remove-row' && table.rows.length > 1) {
      _update(
        table.copyWith(rows: [...table.rows]..removeLast()),
        'removeTableRow',
      );
    } else if (option == 'table-add-column' && table.columnCount < 8) {
      _update(
        table.copyWith(
          columnIds: [...table.columnIds, generateUuid()],
          rows: [
            for (final row in table.rows)
              row.copyWith(
                cells: [
                  ...row.cells,
                  BlockTableCell(id: generateUuid()),
                ],
              ),
          ],
        ),
        'addTableColumn',
      );
    } else if (option == 'table-remove-column' && table.columnCount > 1) {
      _update(
        table.copyWith(
          columnIds: [...table.columnIds]..removeLast(),
          rows: [
            for (final row in table.rows)
              row.copyWith(cells: [...row.cells]..removeLast()),
          ],
        ),
        'removeTableColumn',
      );
    }
  }

  void _update(BaseBlock next, String kind) {
    session.updateBlock(next, kind: kind, refreshPresentation: true);
  }

  void _finishMenu() {
    interaction.dispatch(
      const CancelInteractionIntent(
        reason: InteractionCancellationReason.dialogClosed,
        keepBlockSelected: true,
      ),
    );
  }

  String _calloutLabel(BlockCalloutType type) => switch (type) {
    BlockCalloutType.info => 'Información',
    BlockCalloutType.tip => 'Consejo',
    BlockCalloutType.warning => 'Advertencia',
    BlockCalloutType.success => 'Éxito',
    BlockCalloutType.error => 'Error',
    BlockCalloutType.note => 'Nota',
  };
}

void _ignoreAlignment(BlockAlignmentAxis _) {}

void _ignoreAction() {}
