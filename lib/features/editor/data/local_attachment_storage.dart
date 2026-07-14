import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:allministrator/core/utils/uuid_generator.dart';

class StoredImageAttachment {
  const StoredImageAttachment({
    required this.id,
    required this.localPath,
    required this.originalFileName,
    required this.mimeType,
    required this.sizeBytes,
  });
  final String id, localPath, originalFileName, mimeType;
  final int sizeBytes;
}

class LocalAttachmentStorage {
  LocalAttachmentStorage({this.maxBytes = 20 * 1024 * 1024});
  final int maxBytes;

  Future<StoredImageAttachment> copyImage(XFile source) async {
    final input = File(source.path);
    if (!await input.exists()) {
      throw const FileSystemException('La imagen no existe.');
    }
    final size = await input.length();
    if (size > maxBytes) {
      throw const FileSystemException('La imagen supera el limite de 20 MB.');
    }
    final extension = source.name.split('.').last.toLowerCase();
    const allowed = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
    };
    final mime = allowed[extension];
    if (mime == null) {
      throw const FileSystemException('Formato de imagen no compatible.');
    }
    final id = generateUuid();
    final directory = await getApplicationDocumentsDirectory();
    final images = Directory(
      '${directory.path}${Platform.pathSeparator}attachments',
    );
    await images.create(recursive: true);
    final destination = File(
      '${images.path}${Platform.pathSeparator}$id.$extension',
    );
    await input.copy(destination.path);
    return StoredImageAttachment(
      id: id,
      localPath: destination.path,
      originalFileName: source.name,
      mimeType: mime,
      sizeBytes: size,
    );
  }

  Future<String?> resolvePath(String attachmentId) async {
    final directory = await getApplicationDocumentsDirectory();
    final images = Directory(
      '${directory.path}${Platform.pathSeparator}attachments',
    );
    if (!await images.exists()) return null;
    await for (final entity in images.list()) {
      if (entity is File &&
          entity.uri.pathSegments.last.startsWith('$attachmentId.')) {
        return entity.path;
      }
    }
    return null;
  }

  Future<void> deleteDeferred(String path) async {
    // Deferred cleanup keeps Undo/Redo safe. A future garbage collector can
    // delete files that have no remaining attachment reference.
  }
}
