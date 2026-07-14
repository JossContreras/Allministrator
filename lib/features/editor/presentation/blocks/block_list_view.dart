import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/editing/workspace_editor_session.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_registry.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_render_context.dart';
import 'package:flutter/material.dart';

class BlockListView extends StatelessWidget {
  const BlockListView({
    required this.session,
    required this.registry,
    required this.onChanged,
    required this.resolveAttachmentPath,
    required this.onReplaceImage,
    required this.onReplaceAttachment,
    required this.onOpenAttachment,
    this.header,
    super.key,
  });

  final WorkspaceEditorSession session;
  final BlockRegistry registry;
  final BlockChangedCallback onChanged;
  final String? Function(String attachmentId) resolveAttachmentPath;
  final Future<void> Function(ImageBlock block) onReplaceImage;
  final Future<void> Function(AttachmentBlock block) onReplaceAttachment;
  final Future<void> Function(AttachmentBlock block) onOpenAttachment;
  final Widget? header;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: session.presentationRevision,
    builder: (context, _, _) {
      final blocks = session.blocks.where((block) => block.isVisible).toList();
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => session.selectBlock(null),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 112),
          itemCount: blocks.length + (header == null ? 0 : 1),
          itemBuilder: (context, index) {
            if (header != null && index == 0) return header!;
            final block = blocks[index - (header == null ? 0 : 1)];
            final renderContext = BlockRenderContext(
              block: block,
              session: session,
              onChanged: onChanged,
              resolveAttachmentPath: resolveAttachmentPath,
              onReplaceImage: onReplaceImage,
              onReplaceAttachment: onReplaceAttachment,
              onOpenAttachment: onOpenAttachment,
            );
            return KeyedSubtree(
              key: ValueKey(block.id),
              child: registry.renderEditable(renderContext),
            );
          },
        ),
      );
    },
  );
}
