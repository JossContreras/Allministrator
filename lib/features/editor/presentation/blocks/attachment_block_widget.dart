import 'dart:io';

import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
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
      geometryRegistry: renderContext.geometryRegistry,
      workspaceId: renderContext.session.workspace.id,
      pageId: renderContext.session.page.id,
      visualLayer: renderContext.visualLayer,
      child: renderContext.region(
        id: 'attachment',
        target: AttachmentActionHitTarget(block.id, actionId: 'open'),
        priority: 20,
        child: Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: ListTile(
            leading: Icon(
              missing
                  ? Icons.insert_drive_file_outlined
                  : _icon(block.extension),
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
          ),
        ),
      ),
    );
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
