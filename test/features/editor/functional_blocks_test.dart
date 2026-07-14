import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/editing/workspace_editor_session.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/features/editor/presentation/blocks/attachment_block_widget.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_render_context.dart';
import 'package:allministrator/features/editor/presentation/blocks/checklist_block_widget.dart';
import 'package:allministrator/features/editor/presentation/blocks/code_block_widget.dart';
import 'package:allministrator/features/editor/presentation/blocks/image_block_widget.dart';
import 'package:allministrator/features/editor/presentation/blocks/table_block_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('checklist edits, toggles and adds stable items', (tester) async {
    final block = ChecklistBlock(
      id: 'checklist',
      orderKey: 0,
      items: const [BlockChecklistItem(id: 'item-1', text: '')],
    );
    final session = _session(block);
    session.selectBlock(block.id);
    await tester.pumpWidget(
      _widgetHarness(
        session,
        (context) => ChecklistBlockWidget(renderContext: context),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'Tarea real');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    var current = session.blocks.single as ChecklistBlock;
    expect(current.items.single.text, 'Tarea real');
    expect(current.items.single.isChecked, isTrue);

    await tester.tap(find.text('Agregar elemento'));
    await tester.pump();
    current = session.blocks.single as ChecklistBlock;
    expect(current.items, hasLength(2));
    expect(current.items.map((item) => item.id).toSet(), hasLength(2));
  });

  testWidgets('table is visual, editable and changes rows and columns', (
    tester,
  ) async {
    final block = TableBlock(
      id: 'table',
      orderKey: 0,
      columnIds: const ['column-1', 'column-2'],
      rows: const [
        BlockTableRow(
          id: 'row-1',
          cells: [
            BlockTableCell(id: 'cell-1'),
            BlockTableCell(id: 'cell-2'),
          ],
        ),
        BlockTableRow(
          id: 'row-2',
          cells: [
            BlockTableCell(id: 'cell-3'),
            BlockTableCell(id: 'cell-4'),
          ],
        ),
      ],
    );
    final session = _session(block);
    session.selectBlock(block.id);
    await tester.pumpWidget(
      _widgetHarness(
        session,
        (context) => TableBlockWidget(renderContext: context),
      ),
    );
    await tester.pump();

    expect(find.byType(Table), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(4));
    await tester.enterText(find.byType(TextFormField).first, 'A1');
    await tester.tap(find.text('Fila'));
    await tester.pump();
    await tester.tap(find.text('Columna'));
    await tester.pump();

    final current = session.blocks.single as TableBlock;
    expect(current.rows.first.cells.first.text, 'A1');
    expect(current.rows, hasLength(3));
    expect(current.columnCount, 3);
    expect(current.rows.every((row) => row.cells.length == 3), isTrue);
  });

  testWidgets('attachment card never exposes its private path', (tester) async {
    final block = AttachmentBlock(
      id: 'file',
      orderKey: 0,
      attachmentId: 'attachment',
      displayName: 'reporte.pdf',
      mimeType: 'application/pdf',
      extension: 'pdf',
      sizeBytes: 2048,
    );
    final session = _session(block);
    await tester.pumpWidget(
      _widgetHarness(
        session,
        (context) => AttachmentBlockWidget(renderContext: context),
        path: r'C:\private\attachments\attachment.pdf',
      ),
    );

    expect(find.text('reporte.pdf'), findsOneWidget);
    expect(find.textContaining(r'C:\private'), findsNothing);
    expect(find.textContaining('application/pdf'), findsOneWidget);
  });

  testWidgets('code block preserves multiline whitespace and exposes copy', (
    tester,
  ) async {
    final block = CodeBlock(id: 'code', orderKey: 0, languageId: 'dart');
    final session = _session(block);
    session.selectBlock(block.id);
    await tester.pumpWidget(
      _widgetHarness(
        session,
        (context) => CodeBlockWidget(renderContext: context),
      ),
    );

    final field = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Escribe código…',
    );
    await tester.enterText(field, '  void main() {\n    print("á");\n  }');
    await tester.pump();

    final current = session.blocks.single as CodeBlock;
    expect(current.code, '  void main() {\n    print("á");\n  }');
    expect(current.languageId, 'dart');
    expect(find.byTooltip('Copiar código'), findsOneWidget);
  });

  testWidgets('image block reports a missing permanent attachment cleanly', (
    tester,
  ) async {
    final block = ImageBlock(
      id: 'image',
      orderKey: 0,
      attachmentId: 'missing-image',
      altText: 'Plano',
    );
    final session = _session(block);
    await tester.pumpWidget(
      _widgetHarness(
        session,
        (context) => ImageBlockWidget(renderContext: context),
      ),
    );

    expect(find.text('Imagen no disponible'), findsOneWidget);
    expect(find.textContaining('missing-image'), findsNothing);
  });
}

typedef _Renderer = Widget Function(BlockRenderContext context);

Widget _widgetHarness(
  WorkspaceEditorSession session,
  _Renderer renderer, {
  String? path,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: ValueListenableBuilder<int>(
        valueListenable: session.presentationRevision,
        builder: (context, _, _) {
          final block = session.blocks.single;
          final renderContext = BlockRenderContext(
            block: block,
            session: session,
            onChanged:
                (
                  block, {
                  required kind,
                  mergeable = false,
                  refreshPresentation = false,
                }) => session.updateBlock(
                  block,
                  kind: kind,
                  mergeable: mergeable,
                  refreshPresentation: refreshPresentation,
                ),
            resolveAttachmentPath: (_) => path,
            onReplaceImage: (_) async {},
            onReplaceAttachment: (_) async {},
            onOpenAttachment: (_) async {},
          );
          return renderer(renderContext);
        },
      ),
    ),
  ),
);

WorkspaceEditorSession _session(BaseBlock block) {
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
          blocks: [block],
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
