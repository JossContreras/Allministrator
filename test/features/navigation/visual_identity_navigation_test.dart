import 'package:allministrator/app/theme/app_theme.dart';
import 'package:allministrator/app/theme/app_color_scheme.dart';
import 'package:allministrator/app/theme/app_visual_style.dart';
import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/entities/canvas_layout.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/documents/domain/services/starter_document_service.dart';
import 'package:allministrator/features/documents/presentation/documents_screen.dart';
import 'package:allministrator/features/home/presentation/home_screen.dart';
import 'package:allministrator/features/shared/presentation/navigation_drawer.dart';
import 'package:allministrator/features/templates/presentation/templates_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('navigation exposes real sections and hides unsupported ones', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SizedBox(
            width: 320,
            child: AppNavigationDrawer(
              selectedPath: '/home',
              closeOnSelect: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Mis documentos'), findsOneWidget);
    expect(find.text('Canvas'), findsOneWidget);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Recientes'), findsOneWidget);
    expect(find.text('Categorías'), findsOneWidget);
    expect(find.text('Plantillas'), findsOneWidget);
    expect(find.text('Carpetas'), findsNothing);
    expect(find.text('Respaldos'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home presents actual work and functional creation choices', (
    tester,
  ) async {
    final repository = _MemoryRepository([
      _document(
        id: 'document-1',
        title: 'Plan de lanzamiento',
        text: 'Objetivos, responsables y próximos pasos.',
        favorite: true,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('¿Qué quieres crear hoy?'), findsOneWidget);
    expect(find.text('Plan de lanzamiento'), findsWidgets);
    expect(find.text('Documento'), findsWidgets);
    expect(find.text('Canvas'), findsOneWidget);
    expect(find.text('Nota rápida'), findsOneWidget);
    expect(find.text('Plantilla'), findsOneWidget);
    expect(find.text('Favoritos'), findsWidgets);
    expect(find.byType(Hero), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('documents search filters title, content and category', (
    tester,
  ) async {
    final repository = _MemoryRepository([
      _document(
        id: 'document-1',
        title: 'Arquitectura móvil',
        text: 'Decisiones del Workspace Engine.',
        categoryId: 'proyectos',
      ),
      _document(
        id: 'document-2',
        title: 'Lista de lectura',
        text: 'Libros pendientes.',
        categoryId: 'personal',
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DocumentsBrowserScreen(
          repository: repository,
          title: 'Mis documentos',
          selectedPath: '/documents',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'workspace');
    await tester.pumpAndSettle();

    expect(find.text('Arquitectura móvil'), findsOneWidget);
    expect(find.text('Lista de lectura'), findsNothing);
    expect(find.text('1 documento'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unified library filters documents and Canvas independently', (
    tester,
  ) async {
    final repository = _MemoryRepository([
      _document(
        id: 'document-1',
        title: 'Documento de estrategia',
        text: 'Objetivos y decisiones.',
      ),
      _document(
        id: 'canvas-1',
        title: 'Canvas de ideas',
        text: 'Mapa de posibilidades.',
        canvas: true,
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DocumentsBrowserScreen(
          repository: repository,
          title: 'Todos los archivos',
          selectedPath: '/library',
          filter: DocumentsBrowserFilter.all,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 archivos'), findsOneWidget);
    await tester.tap(find.byTooltip('Ordenar y filtrar'));
    await tester.pumpAndSettle();
    expect(find.text('Tipo de archivo'), findsOneWidget);
    expect(find.text('Tamaño del contenido'), findsOneWidget);
    expect(find.text('Última edición'), findsWidgets);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Canvas'));
    final apply = find.text('Aplicar');
    await tester.ensureVisible(apply);
    await tester.pumpAndSettle();
    await tester.tap(apply);
    await tester.pumpAndSettle();

    expect(find.text('Documento de estrategia'), findsNothing);
    expect(find.text('Canvas de ideas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trash preserves distinct Document and Canvas presentations', (
    tester,
  ) async {
    final repository = _MemoryRepository([
      _document(
        id: 'deleted-document',
        title: 'Documento eliminado',
        text: 'Contenido recuperable.',
        deleted: true,
      ),
      _document(
        id: 'deleted-canvas',
        title: 'Canvas eliminado',
        text: 'Mapa espacial recuperable.',
        canvas: true,
        deleted: true,
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DocumentsBrowserScreen(
          repository: repository,
          title: 'Papelera',
          selectedPath: '/trash',
          filter: DocumentsBrowserFilter.trash,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 archivos'), findsOneWidget);
    expect(find.text('Documentos eliminados'), findsOneWidget);
    expect(find.text('Canvas eliminados'), findsOneWidget);
    expect(find.text('Documento eliminado'), findsOneWidget);
    expect(find.text('Canvas eliminado'), findsOneWidget);
    expect(find.byTooltip('Restaurar Canvas'), findsOneWidget);
    expect(find.byTooltip('Abrir Canvas'), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('starter service creates real Canvas and template content', () async {
    final repository = _MemoryRepository([]);
    final service = StarterDocumentService(repository);

    final document = await service.create(
      title: 'Mapa de ideas',
      body: 'Pregunta central\n\nPosibilidades',
      categoryId: 'ideas',
      layoutType: WorkspaceLayoutType.canvas,
    );

    expect(document.title, 'Mapa de ideas');
    expect(document.categoryId, 'ideas');
    expect(document.content.text, contains('Posibilidades'));
    expect(
      document.content.workspace.primaryPage.layoutType,
      WorkspaceLayoutType.canvas,
    );
    expect(document.content.workspace.workspaceType, WorkspaceType.canvas);
    expect(document.isCanvas, isTrue);
    expect(document.content.workspace.primaryPage.canvasLayout, isNotNull);

    final regular = await service.create(title: 'Documento lineal');
    final documents = DocumentsController(
      repository,
      DocumentsBrowserFilter.active,
    );
    final canvases = DocumentsController(
      repository,
      DocumentsBrowserFilter.canvas,
    );
    await Future<void>.delayed(Duration.zero);
    expect(documents.documents.map((item) => item.id), [regular.id]);
    expect(canvases.documents.map((item) => item.id), [document.id]);
    documents.dispose();
    canvases.dispose();
  });

  testWidgets('template creates a structured composition of real blocks', (
    tester,
  ) async {
    final repository = _MemoryRepository([]);
    final router = GoRouter(
      initialLocation: '/templates',
      routes: [
        GoRoute(
          path: '/templates',
          builder: (_, _) => TemplatesScreen(repository: repository),
        ),
        GoRoute(
          path: '/editor/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Editor ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final useTemplate = find.text('Usar plantilla').first;
    await tester.ensureVisible(useTemplate);
    await tester.pumpAndSettle();
    await tester.tap(useTemplate);
    await tester.pumpAndSettle();

    final blocks =
        repository._documents.single.content.workspace.primaryPage.blocks;
    expect(blocks.length, greaterThanOrEqualTo(5));
    expect(
      blocks.whereType<TextBlock>().any(
        (block) =>
            block.paragraphs.any((paragraph) => paragraph.spans.isNotEmpty),
      ),
      isTrue,
    );
    expect(blocks.whereType<ChecklistBlock>(), isNotEmpty);
    expect(blocks.whereType<TableBlock>(), isNotEmpty);
    expect(blocks.whereType<CalloutBlock>(), isNotEmpty);
  });

  testWidgets('Canvas template creates a spatially distributed workspace', (
    tester,
  ) async {
    final repository = _MemoryRepository([]);
    final router = GoRouter(
      initialLocation: '/templates',
      routes: [
        GoRoute(
          path: '/templates',
          builder: (_, _) => TemplatesScreen(repository: repository),
        ),
        GoRoute(
          path: '/editor/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Editor ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Mapa visual de proyecto');
    await tester.pumpAndSettle();
    final useTemplate = find.text('Usar plantilla');
    await tester.ensureVisible(useTemplate);
    await tester.pumpAndSettle();
    await tester.tap(useTemplate);
    await tester.pumpAndSettle();

    final created = repository._documents.single;
    final page = created.content.workspace.primaryPage;
    expect(created.isCanvas, isTrue);
    expect(page.layoutType, WorkspaceLayoutType.canvas);
    expect(page.blocks.length, greaterThanOrEqualTo(7));
    expect(page.canvasLayout, isNotNull);
    expect(
      page.canvasLayout!.placements
          .map((placement) => placement.x)
          .toSet()
          .length,
      greaterThanOrEqualTo(3),
    );
  });

  test('all VIG visual styles produce distinct complete themes', () {
    final primaryColors = <Color>{};
    final cardRadii = <double>{};
    for (final style in AppVisualStyle.values) {
      final scheme = AppColorScheme.lightFor(style);
      final theme = AppTheme.lightFor(style);
      primaryColors.add(scheme.primary);
      final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
      cardRadii.add((shape.borderRadius as BorderRadius).topLeft.x);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(AppTheme.darkFor(style).colorScheme.brightness, Brightness.dark);
    }
    expect(primaryColors, hasLength(AppVisualStyle.values.length));
    expect(cardRadii.length, greaterThanOrEqualTo(5));
  });
}

Document _document({
  required String id,
  required String title,
  required String text,
  String? categoryId,
  bool favorite = false,
  bool canvas = false,
  bool deleted = false,
}) {
  final now = DateTime.utc(2026, 7, 14, 10);
  var content = DocumentContent.forNewWorkspace(
    workspaceId: id,
    title: title,
    now: now,
  ).withText(text);
  if (canvas) {
    final workspace = content.workspace;
    final page = workspace.primaryPage;
    content = content.withWorkspace(
      workspace.copyWith(
        workspaceType: WorkspaceType.canvas,
        pages: [
          page.copyWith(
            layoutType: WorkspaceLayoutType.canvas,
            canvasLayout: CanvasLayoutState.forBlocks(page.blocks),
          ),
        ],
      ),
    );
  }
  return Document(
    id: id,
    title: title,
    content: content,
    categoryId: categoryId,
    isFavorite: favorite,
    isPinned: false,
    createdAt: now,
    updatedAt: now,
    deletedAt: deleted ? now : null,
    version: 1,
  );
}

class _MemoryRepository implements DocumentRepository {
  _MemoryRepository(List<Document> documents) : _documents = [...documents];

  final List<Document> _documents;

  @override
  Stream<List<Document>> watchActiveDocuments() =>
      Stream.value(_documents.where((item) => item.deletedAt == null).toList());

  @override
  Stream<List<Document>> watchDeletedDocuments() =>
      Stream.value(_documents.where((item) => item.deletedAt != null).toList());

  @override
  Future<Document?> getDocumentById(String id) async {
    for (final document in _documents) {
      if (document.id == id) return document;
    }
    return null;
  }

  @override
  Future<Document> createDocument() async {
    final index = _documents.length + 1;
    final document = _document(id: 'created-$index', title: '', text: '');
    _documents.add(document);
    return document;
  }

  @override
  Future<Document> updateDocument(Document document) async {
    final index = _documents.indexWhere((item) => item.id == document.id);
    final updated = document.copyWith(
      version: document.version + 1,
      updatedAt: DateTime.utc(2026, 7, 14, 11),
    );
    if (index < 0) {
      _documents.add(updated);
    } else {
      _documents[index] = updated;
    }
    return updated;
  }

  @override
  Future<Document> updateTitle(String id, String title) async {
    final document = (await getDocumentById(id))!;
    return updateDocument(document.copyWith(title: title));
  }

  @override
  Future<Document> updateContent(String id, DocumentContent content) async {
    final document = (await getDocumentById(id))!;
    return updateDocument(document.copyWith(content: content));
  }

  @override
  Future<Document> toggleFavorite(String id) async {
    final document = (await getDocumentById(id))!;
    return updateDocument(document.copyWith(isFavorite: !document.isFavorite));
  }

  @override
  Future<Document> togglePinned(String id) async {
    final document = (await getDocumentById(id))!;
    return updateDocument(document.copyWith(isPinned: !document.isPinned));
  }

  @override
  Future<Document> moveToTrash(String id) async {
    final document = (await getDocumentById(id))!;
    return updateDocument(
      document.copyWith(deletedAt: DateTime.utc(2026, 7, 14)),
    );
  }

  @override
  Future<Document> restoreDocument(String id) async {
    final document = (await getDocumentById(id))!;
    return updateDocument(document.copyWith(clearDeletedAt: true));
  }

  @override
  Future<void> deletePermanently(String id) async {
    _documents.removeWhere((item) => item.id == id);
  }
}
