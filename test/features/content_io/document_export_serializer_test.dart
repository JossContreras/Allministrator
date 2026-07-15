import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/features/content_io/data/document_export_service.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes editable blocks to portable Markdown', () {
    final now = DateTime.utc(2026);
    final base = DocumentContent.forNewWorkspace(workspaceId: 'doc', now: now);
    final page = base.workspace.primaryPage.copyWith(
      blocks: [
        TextBlock(
          id: 'text',
          orderKey: 0,
          paragraphs: const [BlockParagraph(id: 'p', text: 'Contenido')],
        ),
        CodeBlock(
          id: 'code',
          orderKey: 1,
          code: 'print(1)',
          languageId: 'python',
        ),
      ],
    );
    final document = Document(
      id: 'doc',
      title: 'Prueba',
      content: base.withWorkspace(base.workspace.copyWith(pages: [page])),
      isFavorite: false,
      isPinned: false,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      version: 1,
    );

    final value = const DocumentExportSerializer().markdownText(document);
    expect(value, contains('# Prueba'));
    expect(value, contains('Contenido'));
    expect(value, contains('```python'));
    expect(value, contains('print(1)'));
  });
}
