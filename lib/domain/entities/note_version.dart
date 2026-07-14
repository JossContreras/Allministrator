import 'package:allministrator/domain/entities/syncable_entity.dart';
import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';

class NoteVersion implements SyncableEntity {
  const NoteVersion({
    required this.id,
    required this.noteId,
    required this.revision,
    required this.document,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.deletedAt,
  });
  @override
  final Uuid id;
  final Uuid noteId;
  final int revision;
  final DocumentContent document;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final int version;
  @override
  final DateTime? deletedAt;
}
