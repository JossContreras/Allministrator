import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:allministrator/domain/entities/canvas_layout.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/editor/presentation/document_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('autosave does not recreate the text controller or move cursor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemoryDocumentRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentEditorScreen(
          repository: repository,
          documentId: repository.document.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final blockField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == 'Escribe aquí…',
    );
    expect(blockField, findsOneWidget);
    final before = tester.widget<TextField>(blockField).controller!;

    await tester.tap(blockField);
    await tester.enterText(blockField, 'abc á 😊');
    before.selection = const TextSelection.collapsed(offset: 2);
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    final after = tester.widget<TextField>(blockField).controller!;
    expect(after, same(before));
    expect(after.selection.baseOffset, 2);
    expect(repository.updateCount, greaterThanOrEqualTo(1));
    expect(repository.document.content.text, 'abc á 😊');
  });

  testWidgets('mobile Canvas header exposes history without conversion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemoryDocumentRepository(canvas: true);
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentEditorScreen(
          repository: repository,
          documentId: repository.document.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<AppBar>(find.byType(AppBar)).title, isNull);
    expect(find.byTooltip('Deshacer'), findsOneWidget);
    expect(find.byTooltip('Rehacer'), findsOneWidget);
    expect(find.byTooltip('Restablecer vista · 100%'), findsOneWidget);
    expect(find.byTooltip('Insertar bloque'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    expect(find.text('Guardado'), findsNothing);
    expect(find.textContaining('Convertir'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long press on empty Canvas inserts at the requested area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemoryDocumentRepository(canvas: true);
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentEditorScreen(
          repository: repository,
          documentId: repository.document.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPressAt(const Offset(350, 650));
    await tester.pumpAndSettle();

    expect(find.text('Insertar en Canvas'), findsOneWidget);
    expect(
      find.text('El bloque aparecerá donde mantuviste presionado.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Texto').last);
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    final page = repository.document.content.workspace.primaryPage;
    expect(page.blocks, hasLength(2));
    final inserted = page.blocks.last;
    final placement = page.canvasLayout!.placementFor(inserted.id);
    expect(placement, isNotNull);
    expect(placement!.x, greaterThan(250));
    expect(placement.y, greaterThan(450));
    expect(tester.takeException(), isNull);
  });

  testWidgets('document category chip opens picker and persists selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemoryDocumentRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentEditorScreen(
          repository: repository,
          documentId: repository.document.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cambiar categoría'));
    await tester.pumpAndSettle();
    expect(find.text('Elegir categoría'), findsOneWidget);
    await tester.tap(find.text('Trabajo'));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    expect(repository.document.categoryId, 'trabajo');
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening ink tools removes overlapping selection buttons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemoryDocumentRepository(canvas: true);
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentEditorScreen(
          repository: repository,
          documentId: repository.document.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Activar selección por área'), findsOneWidget);
    await tester.tap(find.byTooltip('Anotar o dibujar').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ink-toolbar')), findsOneWidget);
    expect(find.byTooltip('Activar selección por área'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Backspace edits focused text instead of targeting the block', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemoryDocumentRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentEditorScreen(
          repository: repository,
          documentId: repository.document.id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == 'Escribe aquí…',
    );
    await tester.tap(field);
    await tester.enterText(field, 'texto');
    final controller = tester.widget<TextField>(field).controller!;
    controller.selection = const TextSelection.collapsed(offset: 5);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(controller.text, 'text');
    expect(
      repository.document.content.workspace.primaryPage.blocks,
      hasLength(1),
    );
  });

  testWidgets(
    'Canvas ink gesture persists one vector stroke through autosave',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _MemoryDocumentRepository(canvas: true);
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentEditorScreen(
            repository: repository,
            documentId: repository.document.id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Anotar o dibujar').first);
      await tester.pump();
      expect(find.byKey(const ValueKey('ink-toolbar')), findsOneWidget);

      final gesture = await tester.startGesture(const Offset(260, 300));
      await gesture.moveTo(const Offset(285, 325));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(const Offset(315, 340));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 750));
      await tester.pumpAndSettle();

      final ink = repository.document.content.workspace.primaryPage.inkLayer;
      expect(ink.strokes, hasLength(1));
      expect(ink.strokes.single.points.length, greaterThanOrEqualTo(2));
      expect(repository.updateCount, greaterThanOrEqualTo(1));
    },
  );
}

class _MemoryDocumentRepository implements DocumentRepository {
  _MemoryDocumentRepository({bool canvas = false}) {
    final now = DateTime.utc(2026);
    var content = DocumentContent.forNewWorkspace(
      workspaceId: '00000000-0000-0000-0000-000000000001',
      now: now,
    );
    if (canvas) {
      final workspace = content.workspace;
      final page = workspace.primaryPage;
      content = content.withWorkspace(
        workspace.copyWith(
          pages: [
            page.copyWith(
              layoutType: WorkspaceLayoutType.canvas,
              canvasLayout: CanvasLayoutState.forBlocks(page.blocks),
            ),
          ],
        ),
      );
    }
    document = Document(
      id: '00000000-0000-0000-0000-000000000001',
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
  int updateCount = 0;

  @override
  Future<Document?> getDocumentById(String id) async =>
      id == document.id ? document : null;

  @override
  Future<Document> updateDocument(Document value) async {
    updateCount++;
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
  Future<Document> toggleFavorite(String id) => updateDocument(
    Document(
      id: document.id,
      title: document.title,
      content: document.content,
      categoryId: document.categoryId,
      isFavorite: !document.isFavorite,
      isPinned: document.isPinned,
      createdAt: document.createdAt,
      updatedAt: document.updatedAt,
      deletedAt: document.deletedAt,
      version: document.version,
    ),
  );

  @override
  Future<Document> togglePinned(String id) => updateDocument(
    Document(
      id: document.id,
      title: document.title,
      content: document.content,
      categoryId: document.categoryId,
      isFavorite: document.isFavorite,
      isPinned: !document.isPinned,
      createdAt: document.createdAt,
      updatedAt: document.updatedAt,
      deletedAt: document.deletedAt,
      version: document.version,
    ),
  );

  @override
  Stream<List<Document>> watchActiveDocuments() => Stream.value([document]);

  @override
  Stream<List<Document>> watchDeletedDocuments() => const Stream.empty();
}
