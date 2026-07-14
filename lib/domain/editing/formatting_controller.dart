import 'package:allministrator/domain/editing/editor_history.dart';
import 'package:allministrator/domain/editing/selection_controller.dart';
import 'package:allministrator/domain/value_objects/structured_document.dart';

enum ParagraphAlignment { left, center, right, justify }

class FormattingController {
  FormattingController(this.history, this.selectionController);
  final EditorHistoryController history;
  final SelectionController selectionController;

  EditorState _applyInline(String attribute, Object? value) {
    final before = history.current;
    final engine = DocumentEditingEngine(
      before.document,
      selection: selectionController.selection,
    );
    final result = engine.applyInlineAttributes(attribute, value);
    final after = EditorState(
      document: result.document,
      selection: result.selection,
    );
    history.executeCommand(
      FormatTextCommand(
        before: before,
        after: after,
        selectionBefore: before.selection,
        selectionAfter: after.selection,
      ),
    );
    return history.current;
  }

  EditorState toggleBold(EditorState state) => _applyInline(
    'bold',
    !state.document.formatActive(state.selection, 'bold', true),
  );
  EditorState toggleItalic(EditorState state) => _applyInline(
    'italic',
    !state.document.formatActive(state.selection, 'italic', true),
  );
  EditorState toggleUnderline(EditorState state) => _applyInline(
    'underline',
    !state.document.formatActive(state.selection, 'underline', true),
  );
  EditorState toggleStrikethrough(EditorState state) => _applyInline(
    'strikethrough',
    !state.document.formatActive(state.selection, 'strikethrough', true),
  );
  EditorState setTextColor(EditorState state, int? color) =>
      _applyInline('color', color);
  EditorState setHighlightColor(EditorState state, int? color) =>
      _applyInline('highlight', color);
  EditorState setFontSize(EditorState state, double? size) =>
      _applyInline('fontSize', size);

  EditorState setParagraphAlignment(
    EditorState state,
    ParagraphAlignment alignment,
  ) {
    final before = history.current;
    final engine = DocumentEditingEngine(
      before.document,
      selection: selectionController.selection,
    );
    final result = engine.applyParagraphAttributes('alignment', alignment.name);
    final after = EditorState(
      document: result.document,
      selection: result.selection,
    );
    history.executeCommand(
      FormatTextCommand(
        before: before,
        after: after,
        selectionBefore: before.selection,
        selectionAfter: after.selection,
      ),
    );
    return history.current;
  }

  SelectionFormattingState getFormattingState(EditorState state) =>
      selectionController.resolveFormattingState(state.document);
}
