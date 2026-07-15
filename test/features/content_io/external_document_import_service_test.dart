import 'dart:io';

import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:allministrator/features/content_io/data/external_document_import_service.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/editor/data/local_attachment_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imports TXT as editable content while preserving its source', () async {
    final directory = await Directory.systemTemp.createTemp('workspace-import');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}ideas.txt');
    await file.writeAsString('Primera línea\nSegunda línea');
    final repository = _MemoryRepository();
    final service = ExternalDocumentImportService(
      repository: repository,
      attachmentStorage: _TestStorage(),
    );

    final result = await service.importFile(
      PlatformFile(
        name: 'ideas.txt',
        path: file.path,
        size: await file.length(),
      ),
    );

    expect(result.convertedToEditableText, isTrue);
    expect(result.document.title, 'ideas');
    expect(result.document.sourceFormat, 'txt');
    expect(result.document.categoryId, 'archivos');
    expect(result.document.content.text, contains('Primera línea'));
    expect(
      result.document.content.workspace.metadata['originalAttachmentId'],
      'asset',
    );
    expect(result.document.content.workspace.primaryPage.blocks.length, 2);
  });
}

class _TestStorage extends LocalAttachmentStorage {
  @override
  Future<StoredFileAttachment> copyFile(PlatformFile source) async {
    return StoredFileAttachment(
      id: 'asset',
      localPath: source.path!,
      originalFileName: source.name,
      mimeType: 'text/plain',
      extension: 'txt',
      sizeBytes: source.size,
      checksum: 'checksum',
    );
  }
}

class _MemoryRepository implements DocumentRepository {
  Document? value;

  @override
  Future<Document> createDocument() async {
    final now = DateTime.utc(2026);
    value = Document(
      id: 'document',
      title: '',
      content: DocumentContent.forNewWorkspace(
        workspaceId: 'document',
        now: now,
      ),
      isFavorite: false,
      isPinned: false,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      version: 1,
    );
    return value!;
  }

  @override
  Future<Document> updateDocument(Document document) async => value = document;

  @override
  Future<Document?> getDocumentById(String id) async => value;

  @override
  Stream<List<Document>> watchActiveDocuments() => Stream.value([?value]);

  @override
  Stream<List<Document>> watchDeletedDocuments() => const Stream.empty();

  @override
  Future<Document> updateTitle(String id, String title) async =>
      value = value!.copyWith(title: title);

  @override
  Future<Document> updateContent(String id, DocumentContent content) async =>
      value = value!.copyWith(content: content);

  @override
  Future<Document> toggleFavorite(String id) async => value!;

  @override
  Future<Document> togglePinned(String id) async => value!;

  @override
  Future<Document> moveToTrash(String id) async => value!;

  @override
  Future<Document> restoreDocument(String id) async => value!;

  @override
  Future<void> deletePermanently(String id) async {}
}
