import 'package:allministrator/domain/editing/editor_history.dart';
import 'package:allministrator/domain/editing/formatting_controller.dart';
import 'package:allministrator/domain/editing/selection_controller.dart';
import 'package:allministrator/domain/value_objects/structured_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final document = StructuredDocument(
    nodes: [
      const ParagraphNode(id: 'a', text: 'uno'),
      const ParagraphNode(id: 'b', text: 'dos'),
    ],
  );

  test(
    'SelectionController normalizes reverse and out of range selections',
    () {
      final controller = SelectionController();
      controller.setSelection(
        const DocumentSelection(
          anchor: DocumentPosition(nodeId: 'b', offset: 99),
          focus: DocumentPosition(nodeId: 'a', offset: -5),
        ),
        document,
      );
      expect(controller.context, SelectionContext.multiParagraphText);
      expect(controller.selection.anchor.offset, 3);
      expect(controller.selection.focus.offset, 0);
    },
  );

  test('FormattingController routes formatting through history', () {
    final selection = SelectionController();
    selection.setSelection(
      const DocumentSelection(
        anchor: DocumentPosition(nodeId: 'a', offset: 0),
        focus: DocumentPosition(nodeId: 'a', offset: 3),
      ),
      document,
    );
    final state = EditorState(
      document: document,
      selection: selection.selection,
    );
    final history = EditorHistoryController(initialState: state);
    final formatting = FormattingController(history, selection);
    formatting.toggleBold(state);
    expect(history.canUndo, isTrue);
    expect(
      (history.current.document.nodes.first as ParagraphNode)
          .spans
          .single
          .attributes['bold'],
      true,
    );
    history.undo();
    expect(
      (history.current.document.nodes.first as ParagraphNode).spans,
      isEmpty,
    );
  });
}
