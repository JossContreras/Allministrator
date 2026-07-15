import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentNode to Workspace migration', () {
    test('migrates legacy text into one TextBlock', () {
      final content = DocumentContent.fromJson({
        'schemaVersion': 1,
        'text': 'uno\ndos',
      });

      expect(content.schemaVersion, DocumentContent.currentSchemaVersion);
      expect(content.wasMigrated, isTrue);
      final block = content.workspace.primaryPage.blocks.single as TextBlock;
      expect(block.plainText, 'uno\ndos');
      expect(block.paragraphs, hasLength(2));
    });

    test('migrates multiple node types and preserves order', () {
      final content = _migrateNodes([
        _paragraph('p1', 'antes'),
        {'id': 'divider-1', 'type': 'divider', 'style': 'dashed'},
        _paragraph('p2', 'después'),
        {
          'id': 'code-1',
          'type': 'codeBlock',
          'code': 'void main() {}',
          'languageId': 'dart',
        },
      ]);

      expect(
        content.workspace.primaryPage.orderedBlocks.map((block) => block.type),
        [BlockType.text, BlockType.divider, BlockType.text, BlockType.code],
      );
      expect(
        content.workspace.primaryPage.orderedBlocks.map(
          (block) => block.orderKey,
        ),
        [0, 1, 2, 3],
      );
    });

    test('migrates images preserving attachment references and IDs', () {
      final content = _migrateNodes([
        _paragraph('p1', ''),
        {
          'id': 'image-1',
          'type': 'image',
          'attachmentId': 'attachment-1',
          'altText': 'Diagrama',
          'caption': 'Arquitectura',
        },
      ]);
      final image = content.workspace.primaryPage.blocks
          .whereType<ImageBlock>()
          .single;

      expect(image.id, 'image-1');
      expect(image.attachmentId, 'attachment-1');
      expect(image.altText, 'Diagrama');
      expect(image.caption, 'Arquitectura');
    });

    test('migrates a real table with stable cell IDs', () {
      final content = _migrateNodes([
        {
          'id': 'table-1',
          'type': 'table',
          'columnDefinitions': [
            {'id': 'column-1'},
            {'id': 'column-2'},
          ],
          'rows': [
            {
              'id': 'row-1',
              'cells': [
                {
                  'id': 'cell-1',
                  'content': {'text': 'A'},
                },
                {
                  'id': 'cell-2',
                  'content': {'text': 'B'},
                },
              ],
            },
          ],
        },
      ]);
      final table = content.workspace.primaryPage.blocks.single as TableBlock;

      expect(table.id, 'table-1');
      expect(table.columnIds, ['column-1', 'column-2']);
      expect(table.rows.single.cells.map((cell) => cell.id), [
        'cell-1',
        'cell-2',
      ]);
      expect(table.rows.single.cells.map((cell) => cell.text), ['A', 'B']);
    });

    test('migrates an interactive checklist with stable item IDs', () {
      final content = _migrateNodes([
        {
          'id': 'checklist-1',
          'type': 'checklist',
          'items': [
            {'id': 'item-1', 'text': 'Hecho', 'isChecked': true},
            {'id': 'item-2', 'text': 'Pendiente', 'isChecked': false},
          ],
        },
      ]);
      final checklist =
          content.workspace.primaryPage.blocks.single as ChecklistBlock;

      expect(checklist.id, 'checklist-1');
      expect(checklist.items.map((item) => item.id), ['item-1', 'item-2']);
      expect(checklist.items.first.isChecked, isTrue);
    });

    test('repeated migration is idempotent and does not duplicate blocks', () {
      final first = _migrateNodes([
        _paragraph('p1', 'Texto'),
        {'id': 'divider-1', 'type': 'divider'},
        _paragraph('p2', 'Final'),
      ]);
      final second = DocumentContent.fromJson(first.toJson());

      expect(second.wasMigrated, isFalse);
      expect(
        second.workspace.primaryPage.blocks.map((block) => block.id),
        first.workspace.primaryPage.blocks.map((block) => block.id),
      );
      expect(second.workspace.toJson(), first.workspace.toJson());
    });

    test('preserves paragraph IDs, spans and attributes', () {
      final content = _migrateNodes([
        {
          'id': 'paragraph-1',
          'type': 'paragraph',
          'text': 'Texto',
          'attributes': {'alignment': 'center'},
          'spans': [
            {
              'start': 0,
              'end': 5,
              'attributes': {'bold': true},
            },
          ],
        },
      ]);
      final text = content.workspace.primaryPage.blocks.single as TextBlock;

      expect(text.id, 'paragraph-1');
      expect(text.paragraphs.single.id, 'paragraph-1');
      expect(text.paragraphs.single.attributes.alignment, 'center');
      expect(text.paragraphs.single.spans.single.attributes['bold'], isTrue);
    });

    test('controlled failure preserves the original payload', () {
      final original = <String, Object?>{
        'schemaVersion': 2,
        'nodes': [
          {'id': 42, 'type': 'paragraph', 'text': 'dato recuperable'},
        ],
      };
      final content = DocumentContent.fromJson(original);

      expect(content.migrationError, isNotNull);
      final migration = content.data['migration']! as Map;
      expect(migration['originalPayload'], original);
      expect(content.workspace.primaryPage.blocks, isNotEmpty);
    });
  });
}

DocumentContent _migrateNodes(List<Map<String, Object?>> nodes) =>
    DocumentContent.fromJson({'schemaVersion': 2, 'nodes': nodes});

Map<String, Object?> _paragraph(String id, String text) => {
  'id': id,
  'type': 'paragraph',
  'text': text,
};
