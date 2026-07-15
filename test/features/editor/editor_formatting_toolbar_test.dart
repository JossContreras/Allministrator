import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/entities/canvas_layout.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/editor/presentation/document_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final canvas in [false, true]) {
    testWidgets(
      'selected text formatting works in ${canvas ? 'Canvas' : 'document'}',
      (tester) async {
        tester.view.physicalSize = const Size(500, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);

        final repository = _MemoryDocumentRepository(canvas: canvas);
        await tester.pumpWidget(
          MaterialApp(
            home: DocumentEditorScreen(
              repository: repository,
              documentId: repository.document.id,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final field = _textBlockField();
        expect(field, findsOneWidget);
        await tester.tap(field);
        await tester.pump();
        await tester.tap(field);
        await tester.pump();

        final controller = tester.widget<TextField>(field).controller!;
        controller.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 7,
        );
        await tester.pumpAndSettle();

        final toolbar = find.byKey(const ValueKey('text-formatting-toolbar'));
        expect(toolbar, findsOneWidget);
        expect(
          find.byKey(const ValueKey('editor-floating-tools')),
          findsNothing,
        );
        expect(find.byTooltip('Insertar bloque'), findsNothing);

        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(toolbar).bottom,
          lessThanOrEqualTo(800 - 260 + 0.01),
        );

        await tester.tap(find.byTooltip('Negrita'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Subrayado'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Color de texto'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aplicar').first);
        await tester.pump(const Duration(milliseconds: 750));
        await tester.pumpAndSettle();

        final block = repository.document.content.workspace.primaryPage.blocks
            .whereType<TextBlock>()
            .single;
        final attributes = block.paragraphs.single.spans.single.attributes;
        expect(attributes['bold'], isTrue);
        expect(attributes['underline'], isTrue);
        expect(attributes['color'], 0xFF202124);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Finder _textBlockField() => find.byWidgetPredicate(
  (widget) =>
      widget is TextField && widget.decoration?.hintText == 'Escribe aquí…',
);

class _MemoryDocumentRepository implements DocumentRepository {
  _MemoryDocumentRepository({required bool canvas}) {
    final now = DateTime.utc(2026);
    var content = DocumentContent.forNewWorkspace(
      workspaceId: '00000000-0000-0000-0000-000000000001',
      now: now,
    );
    final workspace = content.workspace;
    final page = workspace.primaryPage;
    final block = (page.blocks.single as TextBlock).withPlainText('formato');
    final updatedPage = page.copyWith(
      blocks: [block],
      layoutType: canvas
          ? WorkspaceLayoutType.canvas
          : WorkspaceLayoutType.document,
      canvasLayout: canvas ? CanvasLayoutState.forBlocks([block]) : null,
    );
    content = content.withWorkspace(
      workspace.copyWith(
        workspaceType: canvas ? WorkspaceType.canvas : WorkspaceType.document,
        pages: [updatedPage],
      ),
    );
    document = Document(
      id: workspace.id,
      title: 'Prueba',
      content: content,
      isFavorite: false,
      isPinned: false,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      version: 1,
    );
  }

  late Document document;

  @override
  Future<Document?> getDocumentById(String id) async =>
      id == document.id ? document : null;

  @override
  Future<Document> updateDocument(Document value) async {
    document = value.copyWith(
      version: document.version + 1,
      updatedAt: DateTime.now().toUtc(),
    );
    return document;
  }

  @override
  Future<Document> updateContent(String id, DocumentContent content) =>
      updateDocument(document.copyWith(content: content));

  @override
  Future<Document> updateTitle(String id, String title) =>
      updateDocument(document.copyWith(title: title));

  @override
  Future<Document> createDocument() async => document;

  @override
  Future<void> deletePermanently(String id) async {}

  @override
  Future<Document> moveToTrash(String id) =>
      updateDocument(document.copyWith(deletedAt: DateTime.now().toUtc()));

  @override
  Future<Document> restoreDocument(String id) =>
      updateDocument(document.copyWith(clearDeletedAt: true));

  @override
  Future<Document> toggleFavorite(String id) =>
      updateDocument(document.copyWith(isFavorite: !document.isFavorite));

  @override
  Future<Document> togglePinned(String id) =>
      updateDocument(document.copyWith(isPinned: !document.isPinned));

  @override
  Stream<List<Document>> watchActiveDocuments() => Stream.value([document]);

  @override
  Stream<List<Document>> watchDeletedDocuments() => const Stream.empty();
}
