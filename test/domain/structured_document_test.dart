import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:allministrator/domain/value_objects/structured_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migrates legacy text and preserves empty lines', () {
    final content = DocumentContent.fromJson({
      'schemaVersion': 1,
      'text': 'uno\n\ndos\n',
    });
    expect(content.schemaVersion, DocumentContent.currentSchemaVersion);
    expect(content.structured.nodes.length, 4);
    expect(content.text, 'uno\n\ndos\n');
  });

  test('structured document round trips paragraph metadata and marks', () {
    final original = StructuredDocument(
      nodes: [
        ParagraphNode(
          id: 'p1',
          text: 'Hola 😊',
          spans: const [
            TextSpanMark(start: 0, end: 4, attributes: {'bold': true}),
          ],
        ),
      ],
    );
    final restored = StructuredDocument.fromJson(original.toJson());
    expect(restored.toJson(), original.normalized().toJson());
  });

  test('engine inserts multiline text and creates stable paragraphs', () {
    final document = StructuredDocument(
      nodes: [ParagraphNode(id: 'p1', text: 'ab')],
    );
    final engine = DocumentEditingEngine(
      document,
      selection: const DocumentSelection(
        anchor: DocumentPosition(nodeId: 'p1', offset: 1),
        focus: DocumentPosition(nodeId: 'p1', offset: 1),
      ),
    );
    final result = engine.insertText('X\nY\nZ');
    expect(result.document.plainText, 'aX\nY\nZb');
    expect(result.document.nodes.length, 3);
    expect(result.document.nodes.map((node) => node.id).toSet().length, 3);
  });

  test('engine merges adjacent paragraphs on deletion', () {
    final document = StructuredDocument(
      nodes: [
        ParagraphNode(id: 'a', text: 'uno'),
        ParagraphNode(id: 'b', text: 'dos'),
      ],
    );
    final engine = DocumentEditingEngine(document);
    final result = engine.deleteRange(
      const DocumentSelection(
        anchor: DocumentPosition(nodeId: 'a', offset: 2),
        focus: DocumentPosition(nodeId: 'b', offset: 1),
      ),
    );
    expect(result.document.plainText, 'unos');
    expect(result.document.nodes.single.id, 'a');
  });
}
