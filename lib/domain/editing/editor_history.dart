import 'package:allministrator/domain/value_objects/structured_document.dart';
import 'package:flutter/foundation.dart';

class EditorState {
  const EditorState({required this.document, required this.selection});
  final StructuredDocument document;
  final DocumentSelection selection;
}

/// A bounded in-memory snapshot command. Snapshots are intentionally used for
/// Sprint 3 because they preserve IDs, spans and metadata exactly; the limit
/// prevents unbounded memory growth. Deltas can replace this implementation in
/// a future performance-focused sprint without changing the UI contract.
abstract class EditCommand {
  EditCommand({
    required this.selectionBefore,
    required this.selectionAfter,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  final DocumentSelection selectionBefore;
  final DocumentSelection selectionAfter;
  final DateTime timestamp;
  String get kind;
  EditorState execute(EditorState current);
  EditorState undo(EditorState current);
  EditorState redo(EditorState current) => execute(current);
  bool canMergeWith(EditCommand other) => false;
  EditCommand mergeWith(EditCommand other) => this;
}

class SnapshotEditCommand extends EditCommand {
  SnapshotEditCommand({
    required this.before,
    required this.after,
    required this.kind,
    required this.mergeable,
    required super.selectionBefore,
    required super.selectionAfter,
    super.timestamp,
  });
  final EditorState before;
  final EditorState after;
  @override
  final String kind;
  final bool mergeable;
  @override
  EditorState execute(EditorState current) => after;
  @override
  EditorState undo(EditorState current) => before;
  @override
  bool canMergeWith(EditCommand other) =>
      mergeable &&
      other is SnapshotEditCommand &&
      other.mergeable &&
      other.kind == kind &&
      timestamp.difference(other.timestamp).inMilliseconds.abs() <= 900 &&
      selectionAfter.anchor.nodeId == other.selectionBefore.anchor.nodeId;
  @override
  EditCommand mergeWith(EditCommand other) {
    if (other is! SnapshotEditCommand) return this;
    return SnapshotEditCommand(
      before: before,
      after: other.after,
      kind: kind,
      mergeable: mergeable,
      selectionBefore: selectionBefore,
      selectionAfter: other.selectionAfter,
      timestamp: other.timestamp,
    );
  }
}

class InsertTextCommand extends SnapshotEditCommand {
  InsertTextCommand({
    required super.before,
    required super.after,
    required super.selectionBefore,
    required super.selectionAfter,
    super.timestamp,
  }) : super(kind: 'insertText', mergeable: true);
}

class DeleteTextCommand extends SnapshotEditCommand {
  DeleteTextCommand({
    required super.before,
    required super.after,
    required super.selectionBefore,
    required super.selectionAfter,
    super.timestamp,
  }) : super(kind: 'deleteText', mergeable: true);
}

class ReplaceSelectionCommand extends SnapshotEditCommand {
  ReplaceSelectionCommand({
    required super.before,
    required super.after,
    required super.selectionBefore,
    required super.selectionAfter,
    super.timestamp,
  }) : super(kind: 'replaceSelection', mergeable: false);
}

class FormatTextCommand extends SnapshotEditCommand {
  FormatTextCommand({
    required super.before,
    required super.after,
    required super.selectionBefore,
    required super.selectionAfter,
    super.timestamp,
  }) : super(kind: 'formatText', mergeable: false);
}

class InsertNodeCommand extends SnapshotEditCommand {
  InsertNodeCommand({
    required super.before,
    required super.after,
    required super.selectionBefore,
    required super.selectionAfter,
    super.timestamp,
  }) : super(kind: 'insertNode', mergeable: false);
}

class RemoveNodeCommand extends SnapshotEditCommand {
  RemoveNodeCommand({
    required super.before,
    required super.after,
    required super.selectionBefore,
    required super.selectionAfter,
    super.timestamp,
  }) : super(kind: 'removeNode', mergeable: false);
}

class UpdateNodeCommand extends SnapshotEditCommand {
  UpdateNodeCommand({
    required super.before,
    required super.after,
    required super.selectionBefore,
    required super.selectionAfter,
    super.timestamp,
  }) : super(kind: 'updateNode', mergeable: false);
}

class MoveNodeCommand extends SnapshotEditCommand {
  MoveNodeCommand({
    required super.before,
    required super.after,
    required super.selectionBefore,
    required super.selectionAfter,
    super.timestamp,
  }) : super(kind: 'moveNode', mergeable: false);
}

class SplitParagraphCommand extends SnapshotEditCommand {
  SplitParagraphCommand({
    required super.before,
    required super.after,
    required super.selectionBefore,
    required super.selectionAfter,
    super.timestamp,
  }) : super(kind: 'splitParagraph', mergeable: false);
}

class MergeParagraphCommand extends SnapshotEditCommand {
  MergeParagraphCommand({
    required super.before,
    required super.after,
    required super.selectionBefore,
    required super.selectionAfter,
    super.timestamp,
  }) : super(kind: 'mergeParagraph', mergeable: false);
}

class InsertLineBreakCommand extends SnapshotEditCommand {
  InsertLineBreakCommand({
    required super.before,
    required super.after,
    required super.selectionBefore,
    required super.selectionAfter,
    super.timestamp,
  }) : super(kind: 'insertLineBreak', mergeable: false);
}

class PasteTextCommand extends SnapshotEditCommand {
  PasteTextCommand({
    required super.before,
    required super.after,
    required super.selectionBefore,
    required super.selectionAfter,
    super.timestamp,
  }) : super(kind: 'pasteText', mergeable: false);
}

class EditorHistoryController extends ChangeNotifier {
  EditorHistoryController({
    required EditorState initialState,
    this.maxOperations = 200,
  }) : _current = initialState;
  final int maxOperations;
  EditorState _current;
  final List<EditCommand> undoStack = [];
  final List<EditCommand> redoStack = [];
  EditorState get current => _current;
  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  void updateSelection(DocumentSelection selection) {
    _current = EditorState(document: _current.document, selection: selection);
    notifyListeners();
  }

  void executeCommand(EditCommand command) {
    final next = command.execute(_current);
    if (next.document.nodes.isEmpty) return;
    if (undoStack.isNotEmpty && undoStack.last.canMergeWith(command)) {
      undoStack[undoStack.length - 1] = undoStack.last.mergeWith(command);
    } else {
      undoStack.add(command);
    }
    while (undoStack.length > maxOperations) {
      undoStack.removeAt(0);
    }
    _current = next;
    redoStack.clear();
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    final command = undoStack.removeLast();
    _current = command.undo(_current);
    redoStack.add(command);
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    final command = redoStack.removeLast();
    _current = command.redo(_current);
    undoStack.add(command);
    notifyListeners();
  }

  void clear({EditorState? state}) {
    undoStack.clear();
    redoStack.clear();
    if (state != null) _current = state;
    notifyListeners();
  }
}
