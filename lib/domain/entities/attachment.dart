import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/entities/syncable_entity.dart';

enum AttachmentType { image, audio, video, document, other }

class Attachment implements SyncableEntity {
  const Attachment({
    required this.id,
    required this.noteId,
    required this.type,
    required this.storageKey,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.documentNodeId,
    this.documentId,
    this.localPath,
    this.displayName,
    this.extension,
    this.checksum,
    this.deletedAt,
  });
  @override
  final Uuid id;
  final Uuid noteId;
  final Uuid? documentId;
  final String? documentNodeId;
  final AttachmentType type;
  final String storageKey;
  final String? localPath, displayName, extension, checksum;
  final String fileName;
  final String mimeType;
  final int byteSize;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final int version;
  @override
  final DateTime? deletedAt;
}
