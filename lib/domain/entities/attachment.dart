import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/entities/syncable_entity.dart';

enum AttachmentType { image, audio, video, document, other }

class Attachment implements SyncableEntity {
  const Attachment({required this.id, required this.workspaceId, required this.blockId, required this.type, required this.storageKey, required this.fileName, required this.mimeType, required this.byteSize, required this.createdAt, required this.updatedAt, required this.version, this.deletedAt});
  @override final Uuid id;
  final Uuid workspaceId;
  final Uuid blockId;
  final AttachmentType type;
  final String storageKey;
  final String fileName;
  final String mimeType;
  final int byteSize;
  final DateTime createdAt;
  @override final DateTime updatedAt;
  @override final int version;
  @override final DateTime? deletedAt;
}
