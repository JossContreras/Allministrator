import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/entities/syncable_entity.dart';

enum BlockType { paragraph, heading, checklist, quote, code, divider, image, file, embed }

/// Unidad atómica y anidable del editor. Los cuatro mapas se persisten por
/// separado para permitir que tipos de bloque futuros evolucionen sin alterar
/// el modelo de la nota.
class Block implements SyncableEntity {
  const Block({required this.id, required this.noteId, required this.type, required this.position, required this.content, required this.properties, required this.style, required this.metadata, required this.createdAt, required this.updatedAt, required this.version, this.parentBlockId, this.deletedAt});
  @override final Uuid id;
  final Uuid noteId;
  final Uuid? parentBlockId;
  final BlockType type;
  final int position;
  final JsonMap content;
  final JsonMap properties;
  final JsonMap style;
  final JsonMap metadata;
  final DateTime createdAt;
  @override final DateTime updatedAt;
  @override final int version;
  @override final DateTime? deletedAt;
}
