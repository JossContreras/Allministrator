import 'package:allministrator/domain/value_objects/structured_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const selection = DocumentSelection(
    anchor: DocumentPosition(nodeId: 'p1', offset: 1),
    focus: DocumentPosition(nodeId: 'p1', offset: 4),
  );

  test('formats only the selected range and merges equivalent spans', () {
    const document = StructuredDocument(
      nodes: [ParagraphNode(id: 'p1', text: 'abcdef')],
    );
    final bold = document.applyFormat(selection, 'bold', true);
    expect(bold.nodes.single, isA<ParagraphNode>());
    final paragraph = bold.nodes.single as ParagraphNode;
    expect(paragraph.spans.single.toJson(), {
      'start': 1,
      'end': 4,
      'attributes': {'bold': true},
    });
    final extended = bold.applyFormat(
      const DocumentSelection(
        anchor: DocumentPosition(nodeId: 'p1', offset: 4),
        focus: DocumentPosition(nodeId: 'p1', offset: 6),
      ),
      'bold',
      true,
    );
    expect((extended.nodes.single as ParagraphNode).spans.single.end, 6);
  });

  test('toggles styles and serializes colors and font size', () {
    const document = StructuredDocument(
      nodes: [ParagraphNode(id: 'p1', text: 'hola')],
    );
    final fullSelection = const DocumentSelection(
      anchor: DocumentPosition(nodeId: 'p1', offset: 0),
      focus: DocumentPosition(nodeId: 'p1', offset: 4),
    );
    final styled = document
        .applyFormat(fullSelection, 'color', 0xFF1967D2)
        .applyFormat(fullSelection, 'fontSize', 24.0);
    final restored = StructuredDocument.fromJson(styled.toJson());
    final attributes =
        (restored.nodes.single as ParagraphNode).spans.single.attributes;
    expect(attributes['color'], 0xFF1967D2);
    expect(attributes['fontSize'], 24.0);
  });

  test('paragraph alignment is stored in ParagraphAttributes', () {
    const document = StructuredDocument(
      nodes: [ParagraphNode(id: 'p1', text: 'hola')],
    );
    final centered = document.setParagraphAttribute(
      const DocumentSelection(
        anchor: DocumentPosition(nodeId: 'p1', offset: 0),
        focus: DocumentPosition(nodeId: 'p1', offset: 4),
      ),
      'alignment',
      'center',
    );
    expect(
      (centered.nodes.single as ParagraphNode).attributes.alignment,
      'center',
    );
  });
}
