import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/entities/syncable_entity.dart';

/// Metadatos de una nota. Su contenido vive exclusivamente en [Block].
class Note implements SyncableEntity {
  const Note({required this.id, required this.workspaceId, required this.tagIds, required this.createdAt, required this.updatedAt, required this.version, this.folderId, this.deletedAt});
  @override final Uuid id;
  final Uuid workspaceId;
  final Uuid? folderId;
  final Set<Uuid> tagIds;
  final DateTime createdAt;
  @override final DateTime updatedAt;
  @override final int version;
  @override final DateTime? deletedAt;
}
