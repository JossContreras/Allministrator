import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/interaction/workspace_hit_target.dart';
import 'package:allministrator/domain/interaction/selection_group.dart';

enum InteractionMode {
  idle,
  blockSelected,
  textEditing,
  contextMenu,
  dragging,
  resizing,
  rotating,
  drawing,
  panViewport,
  zoomViewport,
  multiSelection,
}

enum WorkspaceTool {
  selection,
  text,
  hand,
  pen,
  highlighter,
  eraser,
  shape,
  connector,
}

enum InteractionSessionType {
  textEditing,
  selection,
  contextMenu,
  drag,
  resize,
  rotate,
  pan,
  zoom,
  ink,
  multiSelection,
}

enum InteractionOverlayType { none, contextMenu, toolbar }

enum InteractionCancellationReason {
  explicit,
  escape,
  systemBack,
  outsideTap,
  pageChanged,
  focusLost,
  blockDeleted,
  dialogClosed,
}

sealed class WorkspaceSelection {
  const WorkspaceSelection();
}

class NoSelection extends WorkspaceSelection {
  const NoSelection();
}

class BlockSelection extends WorkspaceSelection {
  const BlockSelection(this.blockId);

  final Uuid blockId;
}

class TextSelectionState extends WorkspaceSelection {
  const TextSelectionState({
    required this.blockId,
    required this.baseOffset,
    required this.extentOffset,
  });

  final Uuid blockId;
  final int baseOffset;
  final int extentOffset;

  bool get isCollapsed => baseOffset == extentOffset;
}

class MultiBlockSelection extends WorkspaceSelection {
  const MultiBlockSelection(this.group);

  factory MultiBlockSelection.fromIds(
    Iterable<Uuid> ids, {
    Uuid? primaryBlockId,
    Uuid? anchorBlockId,
    bool isTemporary = false,
  }) => MultiBlockSelection(
    SelectionGroup(
      blockIds: ids.toList(),
      primaryBlockId: primaryBlockId,
      anchorBlockId: anchorBlockId,
      isTemporary: isTemporary,
    ).normalized(),
  );

  final SelectionGroup group;
  List<Uuid> get blockIds => group.blockIds;
}

class CompositeSelection extends WorkspaceSelection {
  const CompositeSelection({required this.blockId, this.childId});

  final Uuid blockId;
  final Uuid? childId;
}

class CanvasSelection extends WorkspaceSelection {
  const CanvasSelection({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}

class LassoSelection extends WorkspaceSelection {
  const LassoSelection(this.points);

  final List<InteractionPoint> points;
}

class InteractionPoint {
  const InteractionPoint(this.x, this.y);

  final double x;
  final double y;
}

class InteractionPointer {
  const InteractionPointer({
    required this.pointerId,
    required this.position,
    this.isDown = false,
    this.targetKind = WorkspaceHitTargetKind.emptyArea,
    this.blockId,
  });

  final int pointerId;
  final InteractionPoint position;
  final bool isDown;
  final WorkspaceHitTargetKind targetKind;
  final Uuid? blockId;
}

class InteractionSession {
  const InteractionSession({
    required this.id,
    required this.type,
    required this.startedAt,
    this.blockId,
    this.initialSelection,
    this.hasPendingChanges = false,
  });

  final Uuid id;
  final InteractionSessionType type;
  final DateTime startedAt;
  final Uuid? blockId;
  final WorkspaceSelection? initialSelection;
  final bool hasPendingChanges;
}

class InteractionOverlayState {
  const InteractionOverlayState({
    this.type = InteractionOverlayType.none,
    this.blockId,
    this.anchor,
  });

  final InteractionOverlayType type;
  final Uuid? blockId;
  final InteractionPoint? anchor;

  bool get isVisible => type != InteractionOverlayType.none;
}

class InteractionViewportState {
  const InteractionViewportState({
    this.offset = const InteractionPoint(0, 0),
    this.zoom = 1,
  });

  final InteractionPoint offset;
  final double zoom;
}

class InteractionContext {
  const InteractionContext({
    this.selectedBlock,
    this.focusedBlock,
    this.editingBlock,
    this.activeSession,
    this.activeTool = WorkspaceTool.selection,
    this.interactionMode = InteractionMode.idle,
    this.currentSelection = const NoSelection(),
    this.currentPointer,
    this.overlayState = const InteractionOverlayState(),
    this.viewportState = const InteractionViewportState(),
  });

  final Uuid? selectedBlock;
  final Uuid? focusedBlock;
  final Uuid? editingBlock;
  final InteractionSession? activeSession;
  final WorkspaceTool activeTool;
  final InteractionMode interactionMode;
  final WorkspaceSelection currentSelection;
  final InteractionPointer? currentPointer;
  final InteractionOverlayState overlayState;
  final InteractionViewportState viewportState;

  InteractionContext copyWith({
    Object? selectedBlock = _unset,
    Object? focusedBlock = _unset,
    Object? editingBlock = _unset,
    Object? activeSession = _unset,
    WorkspaceTool? activeTool,
    InteractionMode? interactionMode,
    WorkspaceSelection? currentSelection,
    Object? currentPointer = _unset,
    InteractionOverlayState? overlayState,
    InteractionViewportState? viewportState,
  }) => InteractionContext(
    selectedBlock: identical(selectedBlock, _unset)
        ? this.selectedBlock
        : selectedBlock as Uuid?,
    focusedBlock: identical(focusedBlock, _unset)
        ? this.focusedBlock
        : focusedBlock as Uuid?,
    editingBlock: identical(editingBlock, _unset)
        ? this.editingBlock
        : editingBlock as Uuid?,
    activeSession: identical(activeSession, _unset)
        ? this.activeSession
        : activeSession as InteractionSession?,
    activeTool: activeTool ?? this.activeTool,
    interactionMode: interactionMode ?? this.interactionMode,
    currentSelection: currentSelection ?? this.currentSelection,
    currentPointer: identical(currentPointer, _unset)
        ? this.currentPointer
        : currentPointer as InteractionPointer?,
    overlayState: overlayState ?? this.overlayState,
    viewportState: viewportState ?? this.viewportState,
  );
}

const Object _unset = Object();
