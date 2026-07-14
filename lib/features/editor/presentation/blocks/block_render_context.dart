import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/editing/workspace_editor_session.dart';
import 'package:flutter/widgets.dart';

typedef BlockChangedCallback =
    void Function(
      BaseBlock block, {
      required String kind,
      bool mergeable,
      bool refreshPresentation,
    });

class BlockRenderContext {
  const BlockRenderContext({
    required this.block,
    required this.session,
    required this.onChanged,
    required this.resolveAttachmentPath,
    required this.onReplaceImage,
    required this.onReplaceAttachment,
    required this.onOpenAttachment,
    this.readOnly = false,
  });

  final BaseBlock block;
  final WorkspaceEditorSession session;
  final BlockChangedCallback onChanged;
  final String? Function(String attachmentId) resolveAttachmentPath;
  final Future<void> Function(ImageBlock block) onReplaceImage;
  final Future<void> Function(AttachmentBlock block) onReplaceAttachment;
  final Future<void> Function(AttachmentBlock block) onOpenAttachment;
  final bool readOnly;

  bool get isSelected => session.selectedBlockId == block.id;
  bool get isEditing => session.editingBlockId == block.id;

  BlockRenderContext copyWith({BaseBlock? block, bool? readOnly}) =>
      BlockRenderContext(
        block: block ?? this.block,
        session: session,
        onChanged: onChanged,
        resolveAttachmentPath: resolveAttachmentPath,
        onReplaceImage: onReplaceImage,
        onReplaceAttachment: onReplaceAttachment,
        onOpenAttachment: onOpenAttachment,
        readOnly: readOnly ?? this.readOnly,
      );
}

typedef EditableBlockRenderer = Widget Function(BlockRenderContext context);
typedef ReadOnlyBlockRenderer = Widget Function(BlockRenderContext context);
typedef BlockToolbarProvider = List<BlockCapability> Function(BaseBlock block);
typedef BlockCommandHandler =
    void Function(BlockRenderContext context, String command);
typedef BlockSelectionHandler = void Function(BlockRenderContext context);
typedef BlockValidationHandler = String? Function(BaseBlock block);
typedef BlockInsertionFactory = BaseBlock Function(double orderKey);
