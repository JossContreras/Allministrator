import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('document content retains a versioned structured payload', () {
    const document = DocumentContent(
      schemaVersion: 1,
      data: {'type': 'document', 'children': []},
    );

    expect(document.schemaVersion, 1);
    expect(document.data['type'], 'document');
  });

  test('document content serializes and restores its schema version', () {
    const original = DocumentContent(
      schemaVersion: 3,
      data: {
        'text': 'hola',
        'marks': ['bold'],
      },
    );

    final restored = DocumentContent.fromJson(original.toJson());

    expect(restored.schemaVersion, 3);
    expect(restored.text, 'hola');
    expect(restored.data['marks'], ['bold']);
  });
}
