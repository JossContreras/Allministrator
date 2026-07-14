import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/entities/syncable_entity.dart';

class Folder implements SyncableEntity {
  const Folder({
    required this.id,
    required this.name,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.parentFolderId,
    this.deletedAt,
  });
  @override
  final Uuid id;
  final Uuid? parentFolderId;
  final String name;
  final int position;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final int version;
  @override
  final DateTime? deletedAt;
}
