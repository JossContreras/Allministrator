import 'dart:convert';

import 'package:allministrator/core/database/app_database.dart';
import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/entities/note.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:drift/drift.dart';

abstract interface class NotesLocalDataSource {
  Stream<List<Note>> watchActive();
  Future<Note?> findActiveById(Uuid id);
  Future<void> save(Note note);
}

class DriftNotesLocalDataSource implements NotesLocalDataSource {
  DriftNotesLocalDataSource(this._database);

  final AppDatabase _database;

  @override
  Stream<List<Note>> watchActive() {
    final query = _database.select(_database.notes)
      ..where((table) => table.deletedAt.isNull())
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<Note?> findActiveById(Uuid id) async {
    final query = _database.select(_database.notes)
      ..where((table) => table.id.equals(id) & table.deletedAt.isNull());
    final row = await query.getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> save(Note note) async {
    await _database
        .into(_database.notes)
        .insertOnConflictUpdate(
          NotesCompanion(
            id: Value(note.id),
            folderId: Value(note.folderId),
            documentSchemaVersion: Value(note.document.schemaVersion),
            documentJson: Value(jsonEncode(note.document.data)),
            createdAt: Value(note.createdAt),
            updatedAt: Value(note.updatedAt),
            deletedAt: Value(note.deletedAt),
            version: Value(note.version),
          ),
        );
  }

  Note _toEntity(NoteRow row) {
    final decoded = jsonDecode(row.documentJson);
    if (decoded is! Map) {
      throw const FormatException(
        'El contenido de una nota debe ser un objeto JSON.',
      );
    }

    return Note(
      id: row.id,
      folderId: row.folderId,
      document: DocumentContent(
        schemaVersion: row.documentSchemaVersion,
        data: Map<String, Object?>.from(decoded),
      ),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      version: row.version,
    );
  }
}
