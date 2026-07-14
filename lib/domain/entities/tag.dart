import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/entities/syncable_entity.dart';

class Tag implements SyncableEntity {
  const Tag({required this.id, required this.workspaceId, required this.name, required this.createdAt, required this.updatedAt, required this.version, this.color, this.deletedAt});
  @override final Uuid id;
  final Uuid workspaceId;
  final String name;
  final String? color;
  final DateTime createdAt;
  @override final DateTime updatedAt;
  @override final int version;
  @override final DateTime? deletedAt;
}
