import 'package:flutter_test/flutter_test.dart';
import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/value_objects/structured_document.dart';

void main() {
  test('checklist, quote, callout and code round trip', () {
    final document = StructuredDocument(
      nodes: [
        ChecklistNode(
          id: generateUuid(),
          items: [
            ChecklistItem(
              id: generateUuid(),
              text: 'Tarea',
              isChecked: true,
              indentLevel: 2,
            ),
          ],
        ),
        QuoteNode(id: generateUuid(), text: 'Cita', citation: 'Autor'),
        CalloutNode(
          id: generateUuid(),
          title: 'Aviso',
          text: 'Contenido',
          calloutType: CalloutType.warning,
        ),
        CodeBlockNode(
          id: generateUuid(),
          code: 'void main() {\n  print("✓");\n}',
          languageId: 'dart',
          showLineNumbers: true,
        ),
      ],
    );
    final restored = StructuredDocument.fromJson(document.toJson());
    expect(restored.nodes[0], isA<ChecklistNode>());
    expect((restored.nodes[0] as ChecklistNode).items.single.isChecked, isTrue);
    expect((restored.nodes[1] as QuoteNode).citation, 'Autor');
    expect((restored.nodes[2] as CalloutNode).calloutType, CalloutType.warning);
    expect((restored.nodes[3] as CodeBlockNode).code, contains('✓'));
  });
}
