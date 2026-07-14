import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/editor/presentation/document_editor_screen.dart';
import 'package:flutter/material.dart';
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
}

class _MemoryDocumentRepository implements DocumentRepository {
  _MemoryDocumentRepository() {
    final now = DateTime.utc(2026);
    document = Document(
      id: '00000000-0000-0000-0000-000000000001',
      title: 'Prueba',
      content: DocumentContent.forNewWorkspace(
        workspaceId: '00000000-0000-0000-0000-000000000001',
        now: now,
      ),
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
