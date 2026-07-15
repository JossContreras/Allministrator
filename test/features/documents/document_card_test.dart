import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/entities/canvas_layout.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/features/documents/presentation/document_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('grid card exposes preview, metadata and direct actions', (
    tester,
  ) async {
    final actions = <DocumentCardAction>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 232,
              child: DocumentCard(document: _document(), onAction: actions.add),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plan del proyecto'), findsOneWidget);
    expect(find.textContaining('Contenido relevante'), findsOneWidget);
    expect(find.text('Proyectos'), findsOneWidget);
    expect(find.textContaining('14/07'), findsOneWidget);
    expect(find.byTooltip('Abrir documento'), findsOneWidget);
    expect(find.byTooltip('Marcar como favorito'), findsOneWidget);
    expect(find.byTooltip('Fijar'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Abrir documento'));
    await tester.tap(find.byTooltip('Marcar como favorito'));
    await tester.tap(find.byTooltip('Fijar'));
    expect(actions, [
      DocumentCardAction.open,
      DocumentCardAction.favorite,
      DocumentCardAction.pin,
    ]);
  });

  testWidgets('compact grid card does not overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 170,
              height: 212,
              child: DocumentCard(document: _document(), onAction: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('featured document and Canvas preview adapt to mobile width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 304,
            child: DocumentCard(
              document: _document(),
              style: DocumentCardStyle.featured,
              onAction: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Documento destacado'), findsNothing);
    expect(find.text('Destacado'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 262,
            child: DocumentCard(
              document: _document(canvas: true),
              style: DocumentCardStyle.canvasPreview,
              onAction: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1 bloque'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

Document _document({bool canvas = false}) {
  final createdAt = DateTime(2026, 7, 1, 9, 35);
  final updatedAt = DateTime(2026, 7, 14, 9, 35);
  final workspace = Workspace(
    id: 'workspace',
    title: 'Plan del proyecto',
    description: null,
    workspaceType: WorkspaceType.document,
    pages: [
      WorkspacePage(
        id: 'page',
        workspaceId: 'workspace',
        title: null,
        layoutType: WorkspaceLayoutType.document,
        blocks: [
          TextBlock(
            id: 'text',
            orderKey: 0,
            paragraphs: const [
              BlockParagraph(
                id: 'paragraph',
                text: 'Contenido relevante del documento para la vista previa.',
              ),
            ],
          ),
        ],
        createdAt: createdAt,
        updatedAt: createdAt,
        deletedAt: null,
        version: 1,
        metadata: const {},
      ),
    ],
    themeId: null,
    templateId: null,
    isFavorite: false,
    isArchived: false,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: null,
    version: 1,
    metadata: const {},
  );
  final configured = canvas
      ? workspace.copyWith(
          workspaceType: WorkspaceType.canvas,
          pages: [
            workspace.primaryPage.copyWith(
              layoutType: WorkspaceLayoutType.canvas,
              canvasLayout: CanvasLayoutState.forBlocks(
                workspace.primaryPage.blocks,
              ),
            ),
          ],
        )
      : workspace;
  return Document(
    id: 'document',
    title: 'Plan del proyecto',
    content: DocumentContent.fromWorkspace(configured),
    categoryId: 'proyectos',
    isFavorite: false,
    isPinned: false,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: null,
    version: 1,
  );
}
