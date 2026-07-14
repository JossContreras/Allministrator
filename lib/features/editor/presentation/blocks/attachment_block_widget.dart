import 'dart:io';

import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_frame.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_render_context.dart';
import 'package:flutter/material.dart';

class AttachmentBlockWidget extends StatelessWidget {
  const AttachmentBlockWidget({required this.renderContext, super.key});

  final BlockRenderContext renderContext;

  AttachmentBlock get block => renderContext.block as AttachmentBlock;

  @override
  Widget build(BuildContext context) {
    final path = renderContext.resolveAttachmentPath(block.attachmentId);
    final missing = path == null || !File(path).existsSync();
    return BlockFrame(
      block: block,
      session: renderContext.session,
      readOnly: renderContext.readOnly,
      onTap: () => renderContext.session.selectBlock(block.id),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: ListTile(
          leading: Icon(
            missing ? Icons.insert_drive_file_outlined : _icon(block.extension),
            color: missing ? Theme.of(context).colorScheme.error : null,
          ),
          title: Text(
            block.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              if (missing) 'Archivo faltante',
              block.mimeType,
              if (block.sizeBytes > 0) _size(block.sizeBytes),
              if (block.description?.trim().isNotEmpty == true)
                block.description!,
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: missing ? null : () => renderContext.onOpenAttachment(block),
          trailing: renderContext.readOnly
              ? null
              : PopupMenuButton<String>(
                  tooltip: 'Acciones del archivo',
                  onSelected: (value) {
                    if (value == 'open') {
                      renderContext.onOpenAttachment(block);
                    }
                    if (value == 'rename') {
                      _rename(context);
                    }
                    if (value == 'replace') {
                      renderContext.onReplaceAttachment(block);
                    }
                    if (value == 'delete') {
                      renderContext.session.deleteBlock(block.id);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'open',
                      enabled: !missing,
                      child: const ListTile(
                        leading: Icon(Icons.open_in_new),
                        title: Text('Abrir'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: ListTile(
                        leading: Icon(Icons.drive_file_rename_outline),
                        title: Text('Renombrar'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'replace',
                      child: ListTile(
                        leading: Icon(Icons.find_replace),
                        title: Text('Reemplazar'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Eliminar'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final name = TextEditingController(text: block.displayName);
    final description = TextEditingController(text: block.description);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar archivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nombre visible'),
            ),
            TextField(
              controller: description,
              decoration: const InputDecoration(
                labelText: 'Descripción opcional',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (accepted == true && name.text.trim().isNotEmpty) {
      renderContext.onChanged(
        block.copyWith(
          displayName: name.text.trim(),
          description: description.text.trim(),
          clearDescription: description.text.trim().isEmpty,
        ),
        kind: 'updateAttachmentMetadata',
        refreshPresentation: true,
      );
    }
    name.dispose();
    description.dispose();
  }

  IconData _icon(String extension) => switch (extension.toLowerCase()) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'png' || 'jpg' || 'jpeg' || 'webp' => Icons.image_outlined,
    'zip' || 'rar' => Icons.folder_zip_outlined,
    'doc' || 'docx' => Icons.description_outlined,
    'xls' || 'xlsx' || 'csv' => Icons.table_chart_outlined,
    'ppt' || 'pptx' => Icons.slideshow_outlined,
    _ => Icons.insert_drive_file_outlined,
  };

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
