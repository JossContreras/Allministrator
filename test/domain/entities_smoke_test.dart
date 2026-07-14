import 'package:allministrator/domain/entities/entities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('block model keeps document payloads separated', () {
    final block = Block(
      id: '00000000-0000-0000-0000-000000000001',
      noteId: '00000000-0000-0000-0000-000000000002',
      type: BlockType.paragraph,
      position: 0,
      content: const {'text': 'Texto'},
      properties: const {},
      style: const {},
      metadata: const {},
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      version: 1,
    );

    expect(block.content['text'], 'Texto');
    expect(block.properties, isEmpty);
  });
}
