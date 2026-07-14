import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/editing/workspace_editor_session.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_registry.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_render_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BlockListView extends StatelessWidget {
  const BlockListView({
    required this.session,
    required this.registry,
    required this.interaction,
    required this.geometryRegistry,
    required this.onChanged,
    required this.resolveAttachmentPath,
    required this.onReplaceImage,
    required this.onReplaceAttachment,
    required this.onOpenAttachment,
    this.inputDispatcher,
    this.header,
    this.controller,
    super.key,
  });

  final WorkspaceEditorSession session;
  final BlockRegistry registry;
  final WorkspaceInteractionController interaction;
  final BlockGeometryRegistry geometryRegistry;
  final BlockChangedCallback onChanged;
  final String? Function(String attachmentId) resolveAttachmentPath;
  final Future<void> Function(ImageBlock block) onReplaceImage;
  final Future<void> Function(AttachmentBlock block) onReplaceAttachment;
  final Future<void> Function(AttachmentBlock block) onOpenAttachment;
  final InputDispatcher? inputDispatcher;
  final Widget? header;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: session.presentationRevision,
    builder: (context, _) {
      final blocks = session.blocks.where((block) => block.isVisible).toList();
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              _dispatchEscape(),
          const SingleActivator(LogicalKeyboardKey.delete): () =>
              _dispatchSelectionDelete('Delete'),
          const SingleActivator(LogicalKeyboardKey.backspace): () =>
              _dispatchSelectionDelete('Backspace'),
        },
        child: ListView.builder(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(60, 14, 20, 112),
          itemCount: blocks.length + (header == null ? 0 : 1) + 1,
          itemBuilder: (context, index) {
            if (header != null && index == 0) return header!;
            final blockIndex = index - (header == null ? 0 : 1);
            if (blockIndex == blocks.length) {
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _dispatchOutsideTap,
                child: const SizedBox(height: 220),
              );
            }
            final block = blocks[blockIndex];
            final renderContext = BlockRenderContext(
              block: block,
              session: session,
              interaction: interaction,
              geometryRegistry: geometryRegistry,
              visualLayer: blockIndex,
              onChanged: onChanged,
              resolveAttachmentPath: resolveAttachmentPath,
              onReplaceImage: onReplaceImage,
              onReplaceAttachment: onReplaceAttachment,
              onOpenAttachment: onOpenAttachment,
              inputDispatcher: inputDispatcher,
            );
            return AnimatedBuilder(
              key: ValueKey(block.id),
              animation: interaction.blockListenable(block.id),
              builder: (context, _) => registry.renderEditable(renderContext),
            );
          },
        ),
      );
    },
  );

  void _dispatchEscape() {
    final dispatcher = inputDispatcher;
    if (dispatcher != null) {
      dispatcher.dispatch(
        NormalizedInputEvent(
          eventId: generateUuid(),
          workspaceId: session.workspace.id,
          pageId: session.page.id,
          type: NormalizedInputEventType.keyDown,
          deviceType: InputDeviceType.keyboard,
          timestamp: DateTime.now().toUtc(),
          key: 'Escape',
        ),
      );
      return;
    }
    interaction.dispatch(
      const CancelInteractionIntent(
        reason: InteractionCancellationReason.escape,
      ),
    );
  }

  void _dispatchOutsideTap() {
    if (interaction.context.activeSession is MarqueeSelectionSession) return;
    final dispatcher = inputDispatcher;
    if (dispatcher != null) {
      dispatcher.dispatch(
        NormalizedInputEvent(
          eventId: generateUuid(),
          workspaceId: session.workspace.id,
          pageId: session.page.id,
          type: NormalizedInputEventType.tap,
          deviceType: InputDeviceType.touch,
          timestamp: DateTime.now().toUtc(),
          hitTarget: const EmptyAreaHitTarget(),
        ),
      );
      return;
    }
    interaction.dispatch(
      const CancelInteractionIntent(
        reason: InteractionCancellationReason.outsideTap,
      ),
    );
  }

  void _dispatchSelectionDelete(String key) {
    final dispatcher = inputDispatcher;
    if (dispatcher == null) return;
    dispatcher.dispatch(
      NormalizedInputEvent(
        eventId: generateUuid(),
        workspaceId: session.workspace.id,
        pageId: session.page.id,
        type: NormalizedInputEventType.keyDown,
        deviceType: InputDeviceType.keyboard,
        timestamp: DateTime.now().toUtc(),
        key: key,
      ),
    );
  }
}
