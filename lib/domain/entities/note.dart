import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/entities/syncable_entity.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';

/// Documento editable completo. Su estructura vive en [document], no en una
/// jerarquía de filas de bloques.
class Note implements SyncableEntity {
  const Note({
    required this.id,
    required this.document,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.folderId,
    this.deletedAt,
  });
  @override
  final Uuid id;
  final Uuid? folderId;
  final DocumentContent document;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final int version;
  @override
  final DateTime? deletedAt;
}
