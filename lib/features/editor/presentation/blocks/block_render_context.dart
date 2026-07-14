import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/editing/workspace_editor_session.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/features/editor/presentation/interaction/geometry_reporting.dart';
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
    required this.interaction,
    required this.geometryRegistry,
    required this.visualLayer,
    required this.onChanged,
    required this.resolveAttachmentPath,
    required this.onReplaceImage,
    required this.onReplaceAttachment,
    required this.onOpenAttachment,
    this.inputDispatcher,
    this.readOnly = false,
  });

  final BaseBlock block;
  final WorkspaceEditorSession session;
  final WorkspaceInteractionController interaction;
  final BlockGeometryRegistry geometryRegistry;
  final int visualLayer;
  final BlockChangedCallback onChanged;
  final String? Function(String attachmentId) resolveAttachmentPath;
  final Future<void> Function(ImageBlock block) onReplaceImage;
  final Future<void> Function(AttachmentBlock block) onReplaceAttachment;
  final Future<void> Function(AttachmentBlock block) onOpenAttachment;
  final InputDispatcher? inputDispatcher;
  final bool readOnly;

  bool get isSelected => interaction.context.selectedBlock == block.id;
  bool get isFocused => interaction.context.focusedBlock == block.id;
  bool get isEditing => interaction.context.editingBlock == block.id;

  Widget region({
    required String id,
    required WorkspaceHitTarget target,
    required Widget child,
    int priority = 0,
  }) => InteractionRegionReporter(
    registry: geometryRegistry,
    blockId: block.id,
    regionId: id,
    target: target,
    priority: priority,
    child: child,
  );

  BlockRenderContext copyWith({BaseBlock? block, bool? readOnly}) =>
      BlockRenderContext(
        block: block ?? this.block,
        session: session,
        interaction: interaction,
        geometryRegistry: geometryRegistry,
        visualLayer: visualLayer,
        onChanged: onChanged,
        resolveAttachmentPath: resolveAttachmentPath,
        onReplaceImage: onReplaceImage,
        onReplaceAttachment: onReplaceAttachment,
        onOpenAttachment: onOpenAttachment,
        inputDispatcher: inputDispatcher,
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
