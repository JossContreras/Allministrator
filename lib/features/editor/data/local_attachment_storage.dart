import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
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
  LocalAttachmentStorage({this.maxBytes = 50 * 1024 * 1024});
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

  Future<StoredFileAttachment> copyFile(PlatformFile source) async {
    final sourcePath = source.path;
    if (sourcePath == null) {
      throw const FileSystemException(
        'No se pudo acceder al archivo seleccionado.',
      );
    }
    final input = File(sourcePath);
    if (!await input.exists()) {
      throw const FileSystemException('El archivo no existe.');
    }
    final size = await input.length();
    if (size > maxBytes) {
      throw FileSystemException(
        'El archivo supera el límite de ${maxBytes ~/ (1024 * 1024)} MB.',
      );
    }
    final originalName = source.name.trim().isEmpty
        ? 'Archivo adjunto'
        : source.name;
    final extension = _extension(originalName);
    final mime = _mimeFor(extension) ?? 'application/octet-stream';
    final id = generateUuid();
    final directory = await getApplicationDocumentsDirectory();
    final attachments = Directory(
      '${directory.path}${Platform.pathSeparator}attachments',
    );
    await attachments.create(recursive: true);
    final destination = File(
      '${attachments.path}${Platform.pathSeparator}$id${extension.isEmpty ? '' : '.$extension'}',
    );
    try {
      await input.copy(destination.path);
      final digest = await sha256.bind(destination.openRead()).first;
      return StoredFileAttachment(
        id: id,
        localPath: destination.path,
        originalFileName: originalName,
        mimeType: mime,
        extension: extension,
        sizeBytes: size,
        checksum: digest.toString(),
      );
    } catch (_) {
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }

  String _extension(String name) =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
  String? _mimeFor(String extension) => const {
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'csv': 'text/csv',
    'json': 'application/json',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'zip': 'application/zip',
    'rar': 'application/vnd.rar',
  }[extension];

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

class StoredFileAttachment {
  const StoredFileAttachment({
    required this.id,
    required this.localPath,
    required this.originalFileName,
    required this.mimeType,
    required this.extension,
    required this.sizeBytes,
    required this.checksum,
  });
  final String id, localPath, originalFileName, mimeType, extension, checksum;
  final int sizeBytes;
}
