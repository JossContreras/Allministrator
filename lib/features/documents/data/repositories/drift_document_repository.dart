import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:allministrator/features/documents/data/datasources/documents_local_data_source.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';

class DriftDocumentRepository implements DocumentRepository {
  DriftDocumentRepository(this._localDataSource);

  final DocumentsLocalDataSource _localDataSource;

  @override
  Stream<List<Document>> watchActiveDocuments() =>
      _localDataSource.watchActiveDocuments();

  @override
  Stream<List<Document>> watchDeletedDocuments() =>
      _localDataSource.watchDeletedDocuments();

  @override
  Future<Document?> getDocumentById(Uuid id) =>
      _localDataSource.getDocumentById(id);

  @override
  Future<Document> createDocument() async {
    final now = DateTime.now().toUtc();
    final document = Document(
      id: generateUuid(),
      title: '',
      content: const DocumentContent.empty(),
      isFavorite: false,
      isPinned: false,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      version: 1,
    );
    await _localDataSource.save(document);
    return document;
  }

  @override
  Future<Document> updateDocument(Document document) async {
    final current = await _require(document.id);
    if (_sameContent(current, document)) return current;
    return _saveChanged(
      current.copyWith(
        title: document.title,
        content: document.content,
        categoryId: document.categoryId,
      ),
    );
  }

  @override
  Future<Document> updateTitle(Uuid id, String title) async {
    final current = await _require(id);
    if (current.title == title) return current;
    return _saveChanged(current.copyWith(title: title));
  }

  @override
  Future<Document> updateContent(Uuid id, DocumentContent content) async {
    final current = await _require(id);
    if (current.content.toJson().toString() == content.toJson().toString()) {
      return current;
    }
    return _saveChanged(current.copyWith(content: content));
  }

  @override
  Future<Document> toggleFavorite(Uuid id) async {
    final current = await _require(id);
    return _saveChanged(current.copyWith(isFavorite: !current.isFavorite));
  }

  @override
  Future<Document> togglePinned(Uuid id) async {
    final current = await _require(id);
    return _saveChanged(current.copyWith(isPinned: !current.isPinned));
  }

  @override
  Future<Document> moveToTrash(Uuid id) async {
    final current = await _require(id);
    return _saveChanged(current.copyWith(deletedAt: DateTime.now().toUtc()));
  }

  @override
  Future<Document> restoreDocument(Uuid id) async {
    final current = await _require(id);
    return _saveChanged(current.copyWith(clearDeletedAt: true));
  }

  @override
  Future<void> deletePermanently(Uuid id) =>
      _localDataSource.deletePermanently(id);

  Future<Document> _require(Uuid id) async =>
      await _localDataSource.getDocumentById(id) ??
      (throw StateError('No se encontró el documento $id.'));

  Future<Document> _saveChanged(Document document) async {
    final changed = document.copyWith(
      updatedAt: DateTime.now().toUtc(),
      version: document.version + 1,
    );
    await _localDataSource.save(changed);
    return changed;
  }

  bool _sameContent(Document first, Document second) =>
      first.title == second.title &&
      first.categoryId == second.categoryId &&
      first.content.toJson().toString() == second.content.toJson().toString();
}
