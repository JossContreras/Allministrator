import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/interaction/focus_coordinator.dart';
import 'package:allministrator/domain/interaction/interaction_commands.dart';
import 'package:allministrator/domain/interaction/interaction_intents.dart';
import 'package:allministrator/domain/interaction/interaction_models.dart';
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
      case BeginDragIntent() ||
          ResizeIntent() ||
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
