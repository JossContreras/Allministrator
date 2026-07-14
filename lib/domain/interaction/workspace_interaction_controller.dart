import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/interaction/focus_coordinator.dart';
import 'package:allministrator/domain/interaction/interaction_commands.dart';
import 'package:allministrator/domain/interaction/drag_session.dart';
import 'package:allministrator/domain/interaction/interaction_intents.dart';
import 'package:allministrator/domain/interaction/interaction_models.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';
import 'package:allministrator/domain/interaction/marquee_selection_session.dart';
import 'package:allministrator/domain/interaction/selection_group.dart';
import 'package:flutter/foundation.dart';

typedef UnhandledInteractionIntent = void Function(InteractionIntent intent);

class WorkspaceInteractionController extends ChangeNotifier {
  WorkspaceInteractionController({this.onUnhandledIntent}) {
    focusCoordinator = FocusCoordinator(
      onFocusedBlockChanged: _handleFocusedBlockChanged,
    );
  }

  final UnhandledInteractionIntent? onUnhandledIntent;
  late FocusCoordinator focusCoordinator;
  final ValueNotifier<int> blockStateRevision = ValueNotifier(0);
  final Map<String, ValueNotifier<int>> _blockRevisions = {};
  InteractionContext _context = const InteractionContext();
  bool _changingFocus = false;

  InteractionContext get context => _context;

  ValueListenable<int> blockListenable(String blockId) =>
      _blockRevisions.putIfAbsent(blockId, () => ValueNotifier<int>(0));

  void dispatch(InteractionIntent intent) {
    switch (intent) {
      case SelectBlockIntent():
        _selectBlock(intent.blockId);
      case AddBlockToSelectionIntent():
        _setGroup(_selectionGroup.add(intent.blockId));
      case RemoveBlockFromSelectionIntent():
        _setGroup(_selectionGroup.remove(intent.blockId));
      case ToggleBlockSelectionIntent():
        _setGroup(
          _selectionGroup.contains(intent.blockId)
              ? _selectionGroup.remove(intent.blockId)
              : _selectionGroup.add(intent.blockId),
        );
      case SelectRangeIntent():
        _selectRange(intent);
      case BeginMarqueeSelectionIntent():
        _beginMarquee(intent);
      case UpdateMarqueeSelectionIntent():
        _updateMarquee(intent);
      case CommitMarqueeSelectionIntent():
        _commitMarquee();
      case CancelMarqueeSelectionIntent():
        _cancelMarquee();
      case ClearSelectionIntent():
        _cancel(intent.reason, keepBlockSelected: false);
      case StartEditingIntent():
        _startEditing(intent);
      case FinishEditingIntent():
        _finishEditing(keepBlockSelected: intent.keepBlockSelected);
      case CancelInteractionIntent():
        _cancel(intent.reason, keepBlockSelected: intent.keepBlockSelected);
      case OpenContextMenuIntent():
        _openContextMenu(intent);
      case UpdateTextSelectionIntent():
        _updateTextSelection(intent.selection);
      case UpdatePointerIntent():
        _setContext(_context.copyWith(currentPointer: intent.pointer));
      case ClearPointerIntent():
        _setContext(_context.copyWith(currentPointer: null));
      case BeginDragIntent():
        _beginDrag(intent);
      case UpdateDragIntent():
        _updateDrag(intent);
      case CommitDragIntent():
        _commitDrag(intent);
      case DeleteSelectionIntent() || CopySelectionIntent():
        onUnhandledIntent?.call(intent);
      case ResizeIntent() ||
          RotateIntent() ||
          StartHandwritingIntent() ||
          PanViewportIntent() ||
          ZoomViewportIntent():
        onUnhandledIntent?.call(intent);
      case InternalBlockActionIntent() ||
          OpenAttachmentIntent() ||
          CopyCodeIntent():
        onUnhandledIntent?.call(intent);
    }
  }

  SelectionGroup get _selectionGroup => switch (_context.currentSelection) {
    MultiBlockSelection(:final group) => group,
    BlockSelection(:final blockId) => SelectionGroup(
      blockIds: [blockId],
      primaryBlockId: blockId,
      anchorBlockId: blockId,
    ),
    _ => const SelectionGroup(),
  };

  void _setGroup(SelectionGroup group) {
    final normalized = group.normalized();
    _clearFocusWithoutCallback();
    _setContext(
      _context.copyWith(
        selectedBlock: normalized.primaryBlockId,
        focusedBlock: null,
        editingBlock: null,
        activeSession: null,
        interactionMode: normalized.isEmpty
            ? InteractionMode.idle
            : normalized.isMultiple
            ? InteractionMode.multiSelection
            : InteractionMode.blockSelected,
        currentSelection: normalized.isEmpty
            ? const NoSelection()
            : normalized.isSingle
            ? BlockSelection(normalized.primaryBlockId!)
            : MultiBlockSelection(normalized),
        overlayState: const InteractionOverlayState(),
      ),
    );
  }

  void _selectRange(SelectRangeIntent intent) {
    final group = _selectionGroup;
    final anchor = group.anchorBlockId ?? group.primaryBlockId ?? intent.blockId;
    final first = intent.visualOrder.indexOf(anchor);
    final last = intent.visualOrder.indexOf(intent.blockId);
    if (first < 0 || last < 0) {
      _setGroup(SelectionGroup(blockIds: [intent.blockId], primaryBlockId: intent.blockId, anchorBlockId: intent.blockId));
      return;
    }
    final from = first < last ? first : last;
    final to = first > last ? first : last;
    _setGroup(
      SelectionGroup(
        blockIds: intent.visualOrder.sublist(from, to + 1),
        primaryBlockId: intent.blockId,
        anchorBlockId: anchor,
      ),
    );
  }

  void _beginMarquee(BeginMarqueeSelectionIntent intent) {
    final pointer = _context.currentPointer;
    if (pointer == null ||
        _context.activeSession != null ||
        _context.activeTool != WorkspaceTool.selection) {
      return;
    }
    final initial = _selectionGroup;
    _setContext(
      _context.copyWith(
        activeSession: MarqueeSelectionSession(
          id: generateUuid(),
          startedAt: DateTime.now().toUtc(),
          pointerId: pointer.pointerId,
          startPosition: SpatialPoint(intent.position.x, intent.position.y),
          initialGroup: initial,
        ),
        interactionMode: InteractionMode.multiSelection,
        currentSelection: MultiBlockSelection(initial.copyWith(isTemporary: true)),
      ),
    );
  }

  void _updateMarquee(UpdateMarqueeSelectionIntent intent) {
    final session = _context.activeSession;
    if (session is! MarqueeSelectionSession) return;
    final group = SelectionGroup(
      blockIds: intent.candidateIds,
      primaryBlockId: intent.candidateIds.isEmpty ? null : intent.candidateIds.last,
      anchorBlockId: session.initialGroup.anchorBlockId,
      isTemporary: true,
    ).normalized();
    _setContext(
      _context.copyWith(
        selectedBlock: group.primaryBlockId,
        activeSession: session.copyWith(
          currentPosition: SpatialPoint(intent.position.x, intent.position.y),
          candidateIds: group.blockIds,
        ),
        currentSelection: MultiBlockSelection(group),
      ),
    );
  }

  void _commitMarquee() {
    final session = _context.activeSession;
    if (session is! MarqueeSelectionSession) return;
    final temporary = _selectionGroup;
    _setGroup(temporary.copyWith(isTemporary: false));
  }

  void _cancelMarquee() {
    final session = _context.activeSession;
    if (session is! MarqueeSelectionSession) return;
    _setGroup(session.initialGroup);
  }

  void _beginDrag(BeginDragIntent intent) {
    final pointer = _context.currentPointer;
    if (_context.activeTool != WorkspaceTool.selection ||
        _context.activeSession != null ||
        pointer == null) {
      onUnhandledIntent?.call(intent);
      return;
    }
    final position = SpatialPoint(pointer.position.x, pointer.position.y);
    final group = _selectionGroup;
    final dragIds = group.contains(intent.blockId)
        ? group.blockIds
        : <String>[intent.blockId];
    _clearFocusWithoutCallback();
    _setContext(
      _context.copyWith(
        selectedBlock: intent.blockId,
        focusedBlock: null,
        editingBlock: null,
        activeSession: DragSession(
          id: generateUuid(),
          startedAt: DateTime.now().toUtc(),
          blockId: intent.blockId,
          pointerId: pointer.pointerId,
          startPosition: position,
          blockIds: dragIds,
          primaryBlockId: intent.blockId,
        ),
        interactionMode: InteractionMode.dragging,
        currentSelection: BlockSelection(intent.blockId),
        overlayState: const InteractionOverlayState(),
      ),
    );
  }

  void _updateDrag(UpdateDragIntent intent) {
    final session = _context.activeSession;
    if (session is! DragSession || session.state != DragSessionState.active) {
      return;
    }
    _setContext(
      _context.copyWith(
        activeSession: session.copyWith(
          currentPosition: SpatialPoint(intent.position.x, intent.position.y),
          dropTarget: intent.dropTarget,
        ),
      ),
    );
  }

  void _commitDrag(CommitDragIntent intent) {
    final session = _context.activeSession;
    if (session is! DragSession || !intent.dropTarget.isValid) return;
    _setContext(
      _context.copyWith(
        activeSession: null,
        interactionMode: InteractionMode.blockSelected,
        currentSelection: session.blockIds.length > 1
            ? MultiBlockSelection.fromIds(
                session.blockIds,
                primaryBlockId: session.primaryBlockId ?? session.blockId,
                anchorBlockId: session.primaryBlockId ?? session.blockId,
              )
            : BlockSelection(session.blockId!),
      ),
    );
  }

  void _selectBlock(String blockId) {
    _clearFocusWithoutCallback();
    _setContext(
      _context.copyWith(
        selectedBlock: blockId,
        focusedBlock: null,
        editingBlock: null,
        activeSession: null,
        interactionMode: InteractionMode.blockSelected,
        currentSelection: BlockSelection(blockId),
        overlayState: const InteractionOverlayState(),
      ),
    );
  }

  void _startEditing(StartEditingIntent intent) {
    final selectedBlock = intent.selectBlock ? intent.blockId : null;
    final selection =
        intent.selection ??
        (intent.selectBlock
            ? BlockSelection(intent.blockId)
            : const NoSelection());
    _setContext(
      _context.copyWith(
        selectedBlock: selectedBlock,
        focusedBlock: intent.blockId,
        editingBlock: intent.blockId,
        activeSession: InteractionSession(
          id: generateUuid(),
          type: InteractionSessionType.textEditing,
          startedAt: DateTime.now().toUtc(),
          blockId: intent.blockId,
          initialSelection: intent.selection,
        ),
        activeTool: WorkspaceTool.text,
        interactionMode: InteractionMode.textEditing,
        currentSelection: selection,
        overlayState: const InteractionOverlayState(),
      ),
    );
    _changingFocus = true;
    focusCoordinator.requestFocus(
      intent.blockId,
      targetId: intent.focusTargetId,
    );
    _changingFocus = false;
  }

  void _finishEditing({required bool keepBlockSelected}) {
    final selected = keepBlockSelected ? _context.selectedBlock : null;
    final retainedSelection =
        keepBlockSelected && _context.currentSelection is TextSelectionState
        ? _context.currentSelection
        : selected == null
        ? const NoSelection()
        : BlockSelection(selected);
    _clearFocusWithoutCallback();
    _setContext(
      _context.copyWith(
        selectedBlock: selected,
        focusedBlock: null,
        editingBlock: null,
        activeSession: null,
        activeTool: WorkspaceTool.selection,
        interactionMode: selected == null
            ? InteractionMode.idle
            : InteractionMode.blockSelected,
        currentSelection: retainedSelection,
        overlayState: const InteractionOverlayState(),
      ),
    );
  }

  void _cancel(
    InteractionCancellationReason reason, {
    required bool keepBlockSelected,
  }) {
    _finishEditing(keepBlockSelected: keepBlockSelected);
  }

  void _openContextMenu(OpenContextMenuIntent intent) {
    _clearFocusWithoutCallback();
    _setContext(
      _context.copyWith(
        selectedBlock: intent.blockId,
        focusedBlock: null,
        editingBlock: null,
        activeSession: InteractionSession(
          id: generateUuid(),
          type: InteractionSessionType.contextMenu,
          startedAt: DateTime.now().toUtc(),
          blockId: intent.blockId,
        ),
        interactionMode: InteractionMode.contextMenu,
        currentSelection: BlockSelection(intent.blockId),
        overlayState: InteractionOverlayState(
          type: InteractionOverlayType.contextMenu,
          blockId: intent.blockId,
          anchor: intent.anchor,
        ),
      ),
    );
  }

  void _updateTextSelection(TextSelectionState selection) {
    if (_context.editingBlock != selection.blockId) return;
    _setContext(
      _context.copyWith(
        selectedBlock: selection.blockId,
        focusedBlock: selection.blockId,
        currentSelection: selection,
      ),
    );
  }

  void _handleFocusedBlockChanged(String? blockId) {
    if (_changingFocus || blockId == _context.focusedBlock) return;
    if (blockId == null) {
      dispatch(
        const CancelInteractionIntent(
          reason: InteractionCancellationReason.focusLost,
          keepBlockSelected: true,
        ),
      );
      return;
    }
    if (_context.editingBlock != blockId) return;
    _setContext(_context.copyWith(focusedBlock: blockId));
  }

  void _clearFocusWithoutCallback() {
    _changingFocus = true;
    focusCoordinator.clearFocus();
    _changingFocus = false;
  }

  void _setContext(InteractionContext next) {
    final previous = _context;
    _context = next;
    if (previous.selectedBlock != next.selectedBlock ||
        previous.focusedBlock != next.focusedBlock ||
        previous.editingBlock != next.editingBlock ||
        previous.interactionMode != next.interactionMode ||
        previous.overlayState.type != next.overlayState.type) {
      blockStateRevision.value++;
      final affectedBlocks = <String>{
        if (previous.selectedBlock != null) previous.selectedBlock!,
        if (previous.focusedBlock != null) previous.focusedBlock!,
        if (previous.editingBlock != null) previous.editingBlock!,
        if (next.selectedBlock != null) next.selectedBlock!,
        if (next.focusedBlock != null) next.focusedBlock!,
        if (next.editingBlock != null) next.editingBlock!,
      };
      for (final blockId in affectedBlocks) {
        final revision = _blockRevisions[blockId];
        if (revision != null) revision.value++;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    focusCoordinator.dispose();
    blockStateRevision.dispose();
    for (final revision in _blockRevisions.values) {
      revision.dispose();
    }
    _blockRevisions.clear();
    super.dispose();
  }
}
