import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/entities/syncable_entity.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';

/// Plantilla declarativa de documento, sin acoplarla al editor ni al almacén.
class Template implements SyncableEntity {
  const Template({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.document,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.deletedAt,
  });
  @override
  final Uuid id;
  final Uuid workspaceId;
  final String name;
  final DocumentContent document;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final int version;
  @override
  final DateTime? deletedAt;
}
