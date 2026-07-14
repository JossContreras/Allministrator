import 'dart:io';

import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_frame.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_render_context.dart';
import 'package:flutter/material.dart';

class ImageBlockWidget extends StatelessWidget {
  const ImageBlockWidget({required this.renderContext, super.key});

  final BlockRenderContext renderContext;

  ImageBlock get block => renderContext.block as ImageBlock;

  @override
  Widget build(BuildContext context) {
    final path = renderContext.resolveAttachmentPath(block.attachmentId);
    final maxWidth = switch (block.displaySize) {
      ImageDisplaySize.small => 240.0,
      ImageDisplaySize.medium => 420.0,
      ImageDisplaySize.large => 720.0,
      ImageDisplaySize.original => double.infinity,
    };
    final alignment = switch (block.alignment) {
      BlockAlignment.left => Alignment.centerLeft,
      BlockAlignment.center => Alignment.center,
      BlockAlignment.right => Alignment.centerRight,
    };
    return BlockFrame(
      block: block,
      session: renderContext.session,
      readOnly: renderContext.readOnly,
      onTap: () => renderContext.session.selectBlock(block.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 560),
              child: _content(context, path),
            ),
          ),
          if (block.caption?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                block.caption!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          if (renderContext.isSelected && !renderContext.readOnly)
            _ImageOptions(renderContext: renderContext),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, String? path) {
    if (path == null || !File(path).existsSync()) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined),
            SizedBox(height: 6),
            Text('Imagen no disponible'),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(path),
        fit: BoxFit.contain,
        cacheWidth: 1600,
        semanticLabel: block.altText,
        frameBuilder: (context, child, frame, synchronous) {
          if (synchronous || frame != null) return child;
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (_, _, _) => Container(
          height: 150,
          color: Theme.of(context).colorScheme.errorContainer,
          alignment: Alignment.center,
          child: const Text('No se pudo mostrar la imagen'),
        ),
      ),
    );
  }
}

class _ImageOptions extends StatelessWidget {
  const _ImageOptions({required this.renderContext});

  final BlockRenderContext renderContext;

  ImageBlock get block => renderContext.block as ImageBlock;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    runSpacing: 4,
    alignment: WrapAlignment.center,
    children: [
      SegmentedButton<BlockAlignment>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: BlockAlignment.left,
            icon: Icon(Icons.format_align_left),
          ),
          ButtonSegment(
            value: BlockAlignment.center,
            icon: Icon(Icons.format_align_center),
          ),
          ButtonSegment(
            value: BlockAlignment.right,
            icon: Icon(Icons.format_align_right),
          ),
        ],
        selected: {block.alignment},
        onSelectionChanged: (selection) => renderContext.onChanged(
          block.copyWith(alignment: selection.first),
          kind: 'updateImageAlignment',
          refreshPresentation: true,
        ),
      ),
      DropdownButton<ImageDisplaySize>(
        value: block.displaySize,
        items: const [
          DropdownMenuItem(
            value: ImageDisplaySize.small,
            child: Text('Pequeña'),
          ),
          DropdownMenuItem(
            value: ImageDisplaySize.medium,
            child: Text('Mediana'),
          ),
          DropdownMenuItem(
            value: ImageDisplaySize.large,
            child: Text('Grande'),
          ),
          DropdownMenuItem(
            value: ImageDisplaySize.original,
            child: Text('Original'),
          ),
        ],
        onChanged: (value) {
          if (value == null) return;
          renderContext.onChanged(
            block.copyWith(displaySize: value),
            kind: 'updateImageSize',
            refreshPresentation: true,
          );
        },
      ),
      TextButton.icon(
        onPressed: () => _editDescription(context),
        icon: const Icon(Icons.edit_note),
        label: const Text('Texto alternativo'),
      ),
      TextButton.icon(
        onPressed: () => renderContext.onReplaceImage(block),
        icon: const Icon(Icons.find_replace),
        label: const Text('Reemplazar'),
      ),
    ],
  );

  Future<void> _editDescription(BuildContext context) async {
    final alt = TextEditingController(text: block.altText);
    final caption = TextEditingController(text: block.caption);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalles de imagen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: alt,
              decoration: const InputDecoration(labelText: 'Texto alternativo'),
            ),
            TextField(
              controller: caption,
              decoration: const InputDecoration(labelText: 'Caption'),
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
    if (accepted == true) {
      renderContext.onChanged(
        block.copyWith(
          altText: alt.text.trim(),
          caption: caption.text.trim(),
          clearAltText: alt.text.trim().isEmpty,
          clearCaption: caption.text.trim().isEmpty,
        ),
        kind: 'updateImageMetadata',
        refreshPresentation: true,
      );
    }
    alt.dispose();
    caption.dispose();
  }
}
