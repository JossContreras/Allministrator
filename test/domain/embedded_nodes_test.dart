import 'package:allministrator/domain/value_objects/structured_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('image and divider nodes round trip with typed properties', () {
    final document = StructuredDocument(
      nodes: [
        const ParagraphNode(id: 'p1', text: 'antes'),
        const ImageNode(
          id: 'i1',
          attachmentId: 'a1',
          altText: 'foto',
          caption: 'Pie',
          alignment: NodeAlignment.right,
          displayWidth: .75,
        ),
        const DividerNode(
          id: 'd1',
          style: 'dashed',
          thickness: 2,
          widthFactor: .8,
        ),
        const ParagraphNode(id: 'p2', text: 'después'),
      ],
    );
    final restored = StructuredDocument.fromJson(document.toJson());
    expect(restored.nodes[1], isA<ImageNode>());
    expect((restored.nodes[1] as ImageNode).attachmentId, 'a1');
    expect(restored.nodes[2], isA<DividerNode>());
    expect((restored.nodes[2] as DividerNode).style, 'dashed');
    expect(restored.plainText, 'antes\ndespués');
  });

  test('unknown nodes are tolerated without blocking the document', () {
    final document = StructuredDocument.fromJson({
      'schemaVersion': 2,
      'nodes': [
        {'id': 'x', 'type': 'futureNode', 'value': 1},
        {'id': 'p', 'type': 'paragraph', 'text': 'ok'},
      ],
    });
    expect(document.nodes.first, isA<UnknownNode>());
    expect(document.plainText, 'ok');
  });

  test(
    'engine inserts and removes embedded nodes preserving paragraph IDs',
    () {
      final base = StructuredDocument(
        nodes: [const ParagraphNode(id: 'p', text: 'hola')],
      );
      final engine = DocumentEditingEngine(
        base,
        selection: const DocumentSelection(
          anchor: DocumentPosition(nodeId: 'p', offset: 2),
          focus: DocumentPosition(nodeId: 'p', offset: 2),
        ),
      );
      final inserted = engine.insertDivider(const DividerNode(id: 'd'));
      expect(inserted.document.nodes.whereType<DividerNode>().single.id, 'd');
      expect(inserted.document.nodes.whereType<ParagraphNode>().first.id, 'p');
      final removed = engine.removeNode('d');
      expect(removed.document.nodes.whereType<DividerNode>(), isEmpty);
    },
  );
}
