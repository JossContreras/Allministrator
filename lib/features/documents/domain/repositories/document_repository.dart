import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';

abstract interface class DocumentRepository {
  Stream<List<Document>> watchActiveDocuments();
  Stream<List<Document>> watchDeletedDocuments();
  Future<Document?> getDocumentById(Uuid id);
  Future<Document> createDocument();
  Future<Document> updateDocument(Document document);
  Future<Document> updateTitle(Uuid id, String title);
  Future<Document> updateContent(Uuid id, DocumentContent content);
  Future<Document> toggleFavorite(Uuid id);
  Future<Document> togglePinned(Uuid id);
  Future<Document> moveToTrash(Uuid id);
  Future<Document> restoreDocument(Uuid id);
  Future<void> deletePermanently(Uuid id);
}
