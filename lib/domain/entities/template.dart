import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/entities/note_version.dart';
import 'package:allministrator/domain/entities/syncable_entity.dart';

/// Plantilla declarativa compuesta por instantáneas de bloques, sin acoplarla
/// a una nota, al editor ni a almacenamiento alguno.
class Template implements SyncableEntity {
  const Template({required this.id, required this.workspaceId, required this.name, required this.blocks, required this.createdAt, required this.updatedAt, required this.version, this.deletedAt});
  @override final Uuid id;
  final Uuid workspaceId;
  final String name;
  final List<BlockSnapshot> blocks;
  final DateTime createdAt;
  @override final DateTime updatedAt;
  @override final int version;
  @override final DateTime? deletedAt;
}
