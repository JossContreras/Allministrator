import 'package:allministrator/domain/value_objects/structured_document.dart';

enum SelectionContext {
  none,
  textCursor,
  textRange,
  multiParagraphText,
  image,
  table,
  code,
  drawing,
  attachment,
  checklist,
  checklistItem,
  checklistTextSelection,
  quote,
  callout,
  codeBlock,
  embeddedTextSelection,
}

class SelectionFormattingState {
  const SelectionFormattingState({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.mixedActions = const {},
  });
  final bool bold, italic, underline, strikethrough;
  final Set<String> mixedActions;
}

class SelectionController {
  DocumentSelection selection = DocumentSelection.collapsed(
    const DocumentPosition(nodeId: '', offset: 0),
  );
  SelectionContext context = SelectionContext.none;
  bool get isCollapsed => selection.isCollapsed;
  bool get hasSelection => !selection.isCollapsed;

  void setSelection(DocumentSelection value, StructuredDocument document) {
    selection = normalize(value, document);
    final node = document.nodes
        .where((n) => n.id == selection.anchor.nodeId)
        .firstOrNull;
    context = node == null
        ? SelectionContext.none
        : node is ChecklistNode
        ? (selection.isCollapsed
              ? SelectionContext.checklistItem
              : SelectionContext.checklistTextSelection)
        : node is QuoteNode
        ? (selection.isCollapsed
              ? SelectionContext.quote
              : SelectionContext.embeddedTextSelection)
        : node is CalloutNode
        ? (selection.isCollapsed
              ? SelectionContext.callout
              : SelectionContext.embeddedTextSelection)
        : node is CodeBlockNode
        ? (selection.isCollapsed
              ? SelectionContext.codeBlock
              : SelectionContext.embeddedTextSelection)
        : selection.isCollapsed
        ? SelectionContext.textCursor
        : _isMultiParagraph(document)
        ? SelectionContext.multiParagraphText
        : SelectionContext.textRange;
  }

  void collapseTo(DocumentPosition position) {
    selection = DocumentSelection.collapsed(position);
    context = SelectionContext.textCursor;
  }

  void selectAll(StructuredDocument document) {
    final paragraphs = document.nodes.whereType<ParagraphNode>().toList();
    if (paragraphs.isEmpty) return;
    selection = DocumentSelection(
      anchor: DocumentPosition(nodeId: paragraphs.first.id, offset: 0),
      focus: DocumentPosition(
        nodeId: paragraphs.last.id,
        offset: paragraphs.last.text.length,
      ),
    );
    context = paragraphs.length > 1
        ? SelectionContext.multiParagraphText
        : SelectionContext.textRange;
  }

  void clear() {
    selection = DocumentSelection.collapsed(
      const DocumentPosition(nodeId: '', offset: 0),
    );
    context = SelectionContext.none;
  }

  DocumentSelection normalize(
    DocumentSelection value,
    StructuredDocument document,
  ) {
    DocumentPosition safe(DocumentPosition position) {
      final node =
          document.nodes
              .where((item) => item.id == position.nodeId)
              .firstOrNull ??
          document.nodes.whereType<ParagraphNode>().first;
      if (node is! ParagraphNode) {
        return DocumentPosition(
          nodeId: node.id,
          offset: 0,
          affinity: position.affinity,
        );
      }
      return DocumentPosition(
        nodeId: node.id,
        offset: position.offset.clamp(0, node.text.length),
        affinity: position.affinity,
      );
    }

    return DocumentSelection(
      anchor: safe(value.anchor),
      focus: safe(value.focus),
    );
  }

  SelectionFormattingState resolveFormattingState(
    StructuredDocument document,
  ) => SelectionFormattingState(
    bold: document.formatActive(selection, 'bold', true),
    italic: document.formatActive(selection, 'italic', true),
    underline: document.formatActive(selection, 'underline', true),
    strikethrough: document.formatActive(selection, 'strikethrough', true),
  );

  bool _isMultiParagraph(StructuredDocument document) =>
      document.nodes.indexWhere((node) => node.id == selection.anchor.nodeId) !=
      document.nodes.indexWhere((node) => node.id == selection.focus.nodeId);
}
