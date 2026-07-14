import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/editing/workspace_editor_session.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/domain/value_objects/structured_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inserts a block at the exact cursor and preserves both text sides', () {
    final session = _session(
      TextBlock(
        id: 'text-1',
        orderKey: 0,
        paragraphs: const [
          BlockParagraph(
            id: 'paragraph-1',
            text: 'Hola mundo',
            spans: [
              TextSpanMark(start: 0, end: 4, attributes: {'bold': true}),
            ],
          ),
        ],
      ),
    );
    session.insertBlock(
      DividerBlock(id: 'divider-1', orderKey: 1),
      activeBlockId: 'text-1',
      textSelection: const BlockTextSelection(baseOffset: 4, extentOffset: 4),
    );

    expect(session.blocks, hasLength(3));
    expect((session.blocks[0] as TextBlock).plainText, 'Hola');
    expect(session.blocks[1], isA<DividerBlock>());
    expect((session.blocks[2] as TextBlock).plainText, ' mundo');
    expect(
      (session.blocks[0] as TextBlock).paragraphs.single.spans.single.end,
      4,
    );
    expect(session.blocks.map((block) => block.orderKey), [0, 1, 2]);
  });

  test('move, duplicate, delete, undo and redo operate on blocks', () {
    final session = _session(
      TextBlock(
        id: 'text-1',
        orderKey: 0,
        paragraphs: const [BlockParagraph(id: 'p1', text: 'Texto')],
      ),
      extraBlocks: [DividerBlock(id: 'divider-1', orderKey: 1)],
    );

    session.moveBlock('divider-1', -1);
    expect(session.blocks.first.id, 'divider-1');

    session.duplicateBlock('divider-1');
    expect(session.blocks, hasLength(3));
    expect(session.blocks[1].id, isNot('divider-1'));

    final duplicateId = session.blocks[1].id;
    session.deleteBlock(duplicateId);
    expect(session.blocks, hasLength(2));
    session.undo();
    expect(session.blocks, hasLength(3));
    session.redo();
    expect(session.blocks, hasLength(2));
  });

  test('block codec preserves all functional block types', () {
    final blocks = <BaseBlock>[
      TextBlock(
        id: 'text',
        orderKey: 0,
        paragraphs: const [BlockParagraph(id: 'p', text: 'á 😊')],
      ),
      ImageBlock(id: 'image', orderKey: 1, attachmentId: 'asset'),
      DividerBlock(id: 'divider', orderKey: 2),
      ChecklistBlock(
        id: 'checklist',
        orderKey: 3,
        items: const [BlockChecklistItem(id: 'item', text: 'Uno')],
      ),
      CodeBlock(id: 'code', orderKey: 4, code: '  a\n b'),
      TableBlock(
        id: 'table',
        orderKey: 5,
        columnIds: const ['column'],
        rows: const [
          BlockTableRow(
            id: 'row',
            cells: [BlockTableCell(id: 'cell', text: 'valor')],
          ),
        ],
      ),
      AttachmentBlock(
        id: 'file',
        orderKey: 6,
        attachmentId: 'attachment',
        displayName: 'informe.pdf',
        mimeType: 'application/pdf',
        extension: 'pdf',
        sizeBytes: 10,
      ),
      QuoteBlock(id: 'quote', orderKey: 7, text: 'Cita'),
      CalloutBlock(id: 'callout', orderKey: 8, text: 'Aviso'),
    ];

    for (final block in blocks) {
      final restored = BlockCodec.fromJson(block.toJson());
      expect(restored.type, block.type);
      expect(restored.id, block.id);
      expect(restored.toJson(), block.toJson());
    }
  });

  test(
    'text edits preserve and shift rich spans without changing cursor data',
    () {
      final block = TextBlock(
        id: 'text',
        orderKey: 0,
        paragraphs: const [
          BlockParagraph(
            id: 'paragraph',
            text: 'Hola',
            spans: [
              TextSpanMark(start: 0, end: 4, attributes: {'bold': true}),
            ],
          ),
        ],
        selection: const BlockTextSelection(baseOffset: 2, extentOffset: 2),
      );

      final updated = block.withPlainText('HoXla');

      expect(updated.paragraphs.single.id, 'paragraph');
      expect(updated.paragraphs.single.spans.single.start, 0);
      expect(updated.paragraphs.single.spans.single.end, 5);
      expect(updated.paragraphs.single.spans.single.attributes['bold'], isTrue);
    },
  );

  test('deleting a separator merges adjacent text and undo restores it', () {
    final first = TextBlock(
      id: 'first',
      orderKey: 0,
      paragraphs: const [BlockParagraph(id: 'p1', text: 'Uno')],
    );
    final session = _session(
      first,
      extraBlocks: [
        DividerBlock(id: 'divider', orderKey: 1),
        TextBlock(
          id: 'second',
          orderKey: 2,
          paragraphs: const [BlockParagraph(id: 'p2', text: 'Dos')],
        ),
      ],
    );

    session.deleteBlock('divider');
    expect(session.blocks, hasLength(1));
    expect((session.blocks.single as TextBlock).plainText, 'Uno\nDos');
    session.undo();
    expect(session.blocks, hasLength(3));
    expect(session.blocks[1], isA<DividerBlock>());
  });

  test('handles 50 blocks with stable normalized order', () {
    final blocks = List<BaseBlock>.generate(
      50,
      (index) => TextBlock(
        id: 'text-$index',
        orderKey: index.toDouble(),
        paragraphs: [
          BlockParagraph(id: 'paragraph-$index', text: 'Bloque $index á 😊'),
        ],
      ),
    );
    final session = _session(
      blocks.first,
      extraBlocks: blocks.skip(1).toList(),
    );

    session.moveBlock('text-49', -1);

    expect(session.blocks, hasLength(50));
    expect(
      session.blocks.map((block) => block.orderKey),
      List<double>.generate(50, (index) => index.toDouble()),
    );
  });

  test('multiple move and delete are atomic and undoable', () {
    final session = _session(
      TextBlock(
        id: 'a',
        orderKey: 0,
        paragraphs: const [BlockParagraph(id: 'pa', text: 'A')],
      ),
      extraBlocks: [
        DividerBlock(id: 'b', orderKey: 1),
        DividerBlock(id: 'c', orderKey: 2),
        DividerBlock(id: 'd', orderKey: 3),
      ],
    );
    session.moveBlocksTo(['b', 'd'], targetBlockId: 'c', insertAfter: true);
    expect(session.blocks.map((block) => block.id), ['a', 'c', 'b', 'd']);
    session.undo();
    expect(session.blocks.map((block) => block.id), ['a', 'b', 'c', 'd']);
    session.redo();
    session.deleteBlocks(['b', 'd']);
    expect(session.blocks.map((block) => block.id), ['a', 'c']);
    session.undo();
    expect(session.blocks.map((block) => block.id), ['a', 'c', 'b', 'd']);
  });

  test('resize, align and distribute are atomic and undoable', () {
    final session = _session(
      ImageBlock(id: 'a', orderKey: 0, attachmentId: 'a'),
      extraBlocks: [
        ImageBlock(id: 'b', orderKey: 1, attachmentId: 'b'),
        ImageBlock(id: 'c', orderKey: 2, attachmentId: 'c'),
      ],
    );
    session.resizeBlock('a', const SpatialRect.fromLTWH(0, 0, 240, 160));
    expect(session.blockById('a')!.geometry.width, 240);
    session.undo();
    expect(session.blockById('a')!.geometry.width, isNull);
    session.redo();
    expect(session.blockById('a')!.geometry.height, 160);

    const bounds = {
      'a': SpatialRect.fromLTWH(0, 0, 100, 40),
      'b': SpatialRect.fromLTWH(100, 80, 100, 40),
      'c': SpatialRect.fromLTWH(200, 220, 100, 40),
    };
    session.alignBlocks(const ['a', 'b', 'c'], bounds, BlockAlignmentAxis.left);
    expect(session.blockById('b')!.geometry.x, -100);
    expect(
      (session.blockById('b')! as ImageBlock).alignment,
      BlockAlignment.left,
    );
    session.undo();
    expect(session.blockById('b')!.geometry.x, 0);

    session.distributeBlocksVertically(const ['a', 'b', 'c'], bounds);
    expect(session.blockById('b')!.geometry.y, 30);
    session.undo();
    expect(session.blockById('b')!.geometry.y, 0);
  });
}

WorkspaceEditorSession _session(
  BaseBlock first, {
  List<BaseBlock> extraBlocks = const [],
}) {
  final now = DateTime.utc(2026);
  return WorkspaceEditorSession(
    workspace: Workspace(
      id: 'workspace',
      title: 'Documento',
      description: null,
      workspaceType: WorkspaceType.document,
      pages: [
        WorkspacePage(
          id: 'page',
          workspaceId: 'workspace',
          title: null,
          layoutType: WorkspaceLayoutType.document,
          blocks: [first, ...extraBlocks],
          createdAt: now,
          updatedAt: now,
          deletedAt: null,
          version: 1,
          metadata: const {},
        ),
      ],
      themeId: null,
      templateId: null,
      isFavorite: false,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      version: 1,
      metadata: const {},
    ),
    onChanged: (_) {},
  );
}
