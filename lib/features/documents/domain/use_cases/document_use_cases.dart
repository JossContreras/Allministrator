import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';

class WatchActiveDocuments {
  const WatchActiveDocuments(this.repository);
  final DocumentRepository repository;
  Stream<List<Document>> call() => repository.watchActiveDocuments();
}

class WatchDeletedDocuments {
  const WatchDeletedDocuments(this.repository);
  final DocumentRepository repository;
  Stream<List<Document>> call() => repository.watchDeletedDocuments();
}

class GetDocumentById {
  const GetDocumentById(this.repository);
  final DocumentRepository repository;
  Future<Document?> call(Uuid id) => repository.getDocumentById(id);
}

class CreateDocument {
  const CreateDocument(this.repository);
  final DocumentRepository repository;
  Future<Document> call() => repository.createDocument();
}

class UpdateDocument {
  const UpdateDocument(this.repository);
  final DocumentRepository repository;
  Future<Document> call(Document document) =>
      repository.updateDocument(document);
}

class UpdateDocumentTitle {
  const UpdateDocumentTitle(this.repository);
  final DocumentRepository repository;
  Future<Document> call(Uuid id, String title) =>
      repository.updateTitle(id, title);
}

class UpdateDocumentContent {
  const UpdateDocumentContent(this.repository);
  final DocumentRepository repository;
  Future<Document> call(Uuid id, DocumentContent content) =>
      repository.updateContent(id, content);
}

class ToggleDocumentFavorite {
  const ToggleDocumentFavorite(this.repository);
  final DocumentRepository repository;
  Future<Document> call(Uuid id) => repository.toggleFavorite(id);
}

class ToggleDocumentPinned {
  const ToggleDocumentPinned(this.repository);
  final DocumentRepository repository;
  Future<Document> call(Uuid id) => repository.togglePinned(id);
}

class MoveDocumentToTrash {
  const MoveDocumentToTrash(this.repository);
  final DocumentRepository repository;
  Future<Document> call(Uuid id) => repository.moveToTrash(id);
}

class RestoreDocument {
  const RestoreDocument(this.repository);
  final DocumentRepository repository;
  Future<Document> call(Uuid id) => repository.restoreDocument(id);
}

class DeleteDocumentPermanently {
  const DeleteDocumentPermanently(this.repository);
  final DocumentRepository repository;
  Future<void> call(Uuid id) => repository.deletePermanently(id);
}
