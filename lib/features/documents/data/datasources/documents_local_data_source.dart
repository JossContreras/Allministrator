import 'dart:convert';

import 'package:allministrator/core/database/app_database.dart';
import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:drift/drift.dart';

abstract interface class DocumentsLocalDataSource {
  Stream<List<Document>> watchActiveDocuments();
  Stream<List<Document>> watchDeletedDocuments();
  Future<Document?> getDocumentById(Uuid id);
  Future<void> save(Document document);
  Future<void> deletePermanently(Uuid id);
}

class DriftDocumentsLocalDataSource implements DocumentsLocalDataSource {
  DriftDocumentsLocalDataSource(this._database);

  final AppDatabase _database;

  @override
  Stream<List<Document>> watchActiveDocuments() {
    final query = _database.select(_database.documents)
      ..where((table) => table.deletedAt.isNull())
      ..orderBy([
        (table) => OrderingTerm.desc(table.isPinned),
        (table) => OrderingTerm.desc(table.updatedAt),
      ]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Stream<List<Document>> watchDeletedDocuments() {
    final query = _database.select(_database.documents)
      ..where((table) => table.deletedAt.isNotNull())
      ..orderBy([(table) => OrderingTerm.desc(table.deletedAt)]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<Document?> getDocumentById(Uuid id) async {
    final query = _database.select(_database.documents)
      ..where((table) => table.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> save(Document document) async {
    await _database
        .into(_database.documents)
        .insertOnConflictUpdate(
          DocumentsCompanion(
            id: Value(document.id),
            title: Value(document.title),
            contentJson: Value(jsonEncode(document.content.toJson())),
            categoryId: Value(document.categoryId),
            isFavorite: Value(document.isFavorite),
            isPinned: Value(document.isPinned),
            createdAt: Value(document.createdAt),
            updatedAt: Value(document.updatedAt),
            deletedAt: Value(document.deletedAt),
            version: Value(document.version),
          ),
        );
  }

  @override
  Future<void> deletePermanently(Uuid id) async {
    await (_database.delete(
      _database.documents,
    )..where((table) => table.id.equals(id))).go();
  }

  Document _toEntity(DocumentRow row) {
    final decoded = jsonDecode(row.contentJson);
    if (decoded is! Map) {
      throw const FormatException(
        'El contenido del documento no es JSON válido.',
      );
    }
    return Document(
      id: row.id,
      title: row.title,
      content: DocumentContent.fromJson(Map<String, Object?>.from(decoded)),
      categoryId: row.categoryId,
      isFavorite: row.isFavorite,
      isPinned: row.isPinned,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      version: row.version,
    );
  }
}
