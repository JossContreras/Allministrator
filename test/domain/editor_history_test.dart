import 'package:allministrator/domain/editing/editor_history.dart';
import 'package:allministrator/domain/value_objects/structured_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  EditorState state(String text) {
    final document = StructuredDocument(
      nodes: [ParagraphNode(id: 'p1', text: text)],
    );
    return EditorState(
      document: document,
      selection: DocumentSelection.collapsed(
        DocumentPosition(nodeId: 'p1', offset: text.length),
      ),
    );
  }

  test('undo and redo restore document and cursor', () {
    final history = EditorHistoryController(
      initialState: state(''),
      maxOperations: 10,
    );
    final before = history.current;
    final after = state('hola');
    history.executeCommand(
      InsertTextCommand(
        before: before,
        after: after,
        selectionBefore: before.selection,
        selectionAfter: after.selection,
      ),
    );
    expect(history.canUndo, isTrue);
    history.undo();
    expect(history.current.document.plainText, '');
    expect(history.current.selection.anchor.offset, 0);
    history.redo();
    expect(history.current.document.plainText, 'hola');
    expect(history.current.selection.anchor.offset, 4);
  });

  test('new edit clears redo and history respects limit', () {
    final history = EditorHistoryController(
      initialState: state(''),
      maxOperations: 2,
    );
    var current = history.current;
    for (final text in ['a', 'ab', 'abc']) {
      final next = state(text);
      history.executeCommand(
        ReplaceSelectionCommand(
          before: current,
          after: next,
          selectionBefore: current.selection,
          selectionAfter: next.selection,
        ),
      );
      current = next;
    }
    expect(history.undoStack, hasLength(2));
    history.undo();
    final next = state('new');
    history.executeCommand(
      ReplaceSelectionCommand(
        before: history.current,
        after: next,
        selectionBefore: history.current.selection,
        selectionAfter: next.selection,
      ),
    );
    expect(history.canRedo, isFalse);
  });

  test('consecutive insert commands merge within the typing window', () {
    final history = EditorHistoryController(initialState: state(''));
    final first = state('a');
    history.executeCommand(
      InsertTextCommand(
        before: history.current,
        after: first,
        selectionBefore: history.current.selection,
        selectionAfter: first.selection,
      ),
    );
    final second = state('ab');
    history.executeCommand(
      InsertTextCommand(
        before: first,
        after: second,
        selectionBefore: first.selection,
        selectionAfter: second.selection,
      ),
    );
    expect(history.undoStack, hasLength(1));
    history.undo();
    expect(history.current.document.plainText, '');
  });
}
