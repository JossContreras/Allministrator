import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/entities/block.dart';
import 'package:allministrator/domain/entities/syncable_entity.dart';

/// Instantánea inmutable de un bloque dentro de una revisión de nota.
class BlockSnapshot {
  const BlockSnapshot({required this.blockId, required this.parentBlockId, required this.type, required this.position, required this.content, required this.properties, required this.style, required this.metadata});
  final Uuid blockId;
  final Uuid? parentBlockId;
  final BlockType type;
  final int position;
  final JsonMap content;
  final JsonMap properties;
  final JsonMap style;
  final JsonMap metadata;
}

class NoteVersion implements SyncableEntity {
  const NoteVersion({required this.id, required this.noteId, required this.revision, required this.blocks, required this.createdAt, required this.updatedAt, required this.version, this.deletedAt});
  @override final Uuid id;
  final Uuid noteId;
  final int revision;
  final List<BlockSnapshot> blocks;
  final DateTime createdAt;
  @override final DateTime updatedAt;
  @override final int version;
  @override final DateTime? deletedAt;
}
