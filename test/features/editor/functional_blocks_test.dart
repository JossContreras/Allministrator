import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/editing/workspace_editor_session.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/features/editor/presentation/blocks/attachment_block_widget.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_render_context.dart';
import 'package:allministrator/features/editor/presentation/blocks/checklist_block_widget.dart';
import 'package:allministrator/features/editor/presentation/blocks/code_block_widget.dart';
import 'package:allministrator/features/editor/presentation/blocks/image_block_widget.dart';
import 'package:allministrator/features/editor/presentation/blocks/table_block_widget.dart';
import 'package:allministrator/features/editor/presentation/interaction/workspace_block_actions.dart';
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
    final interaction = WorkspaceInteractionController();
    await tester.pumpWidget(
      _widgetHarness(
        session,
        interaction,
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
    expect(interaction.context.selectedBlock, isNull);

    interaction.dispatch(SelectBlockIntent(block.id));
    await tester.pump();
    await tester.tap(find.byTooltip('Opciones del bloque'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar elemento'));
    await tester.pumpAndSettle();
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
    final interaction = WorkspaceInteractionController()
      ..dispatch(SelectBlockIntent(block.id));
    await tester.pumpWidget(
      _widgetHarness(
        session,
        interaction,
        (context) => TableBlockWidget(renderContext: context),
      ),
    );
    await tester.pump();

    expect(find.byType(Table), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(4));
    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, 'A1');
    expect(interaction.context.selectedBlock, isNull);
    expect(interaction.context.editingBlock, 'table');
    interaction.dispatch(SelectBlockIntent(block.id));
    await tester.pump();
    await tester.tap(find.byTooltip('Opciones del bloque'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar fila'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Opciones del bloque'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar columna'));
    await tester.pumpAndSettle();

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
    final interaction = WorkspaceInteractionController();
    await tester.pumpWidget(
      _widgetHarness(
        session,
        interaction,
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
    final interaction = WorkspaceInteractionController()
      ..dispatch(SelectBlockIntent(block.id));
    await tester.pumpWidget(
      _widgetHarness(
        session,
        interaction,
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
    final interaction = WorkspaceInteractionController();
    await tester.pumpWidget(
      _widgetHarness(
        session,
        interaction,
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
  WorkspaceInteractionController interaction,
  _Renderer renderer, {
  String? path,
}) {
  final geometryRegistry = BlockGeometryRegistry();
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            session.presentationRevision,
            interaction.blockListenable(session.blocks.single.id),
          ]),
          builder: (context, _) {
            final block = session.blocks.single;
            final renderContext = BlockRenderContext(
              block: block,
              session: session,
              interaction: interaction,
              geometryRegistry: geometryRegistry,
              visualLayer: 0,
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
            return Column(
              children: [
                renderer(renderContext),
                if (interaction.context.selectedBlock == block.id)
                  WorkspaceBlockActions(
                    block: block,
                    session: session,
                    interaction: interaction,
                    onReplaceImage: (_) async {},
                    onEditImageDetails: (_) async {},
                    onReplaceAttachment: (_) async {},
                    onOpenAttachment: (_) async {},
                    onEditAttachmentDetails: (_) async {},
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

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
