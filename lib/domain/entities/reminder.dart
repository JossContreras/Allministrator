import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/entities/syncable_entity.dart';

class Reminder implements SyncableEntity {
  const Reminder({required this.id, required this.workspaceId, required this.noteId, required this.scheduledAt, required this.createdAt, required this.updatedAt, required this.version, this.blockId, this.deletedAt});
  @override final Uuid id;
  final Uuid workspaceId;
  final Uuid noteId;
  final Uuid? blockId;
  final DateTime scheduledAt;
  final DateTime createdAt;
  @override final DateTime updatedAt;
  @override final int version;
  @override final DateTime? deletedAt;
}
