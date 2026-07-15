import 'dart:convert';
import 'dart:io';

import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/editor/data/local_attachment_storage.dart';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart';

class ExternalImportResult {
  const ExternalImportResult({
    required this.document,
    required this.sourceExtension,
    required this.convertedToEditableText,
    this.warning,
  });

  final Document document;
  final String sourceExtension;
  final bool convertedToEditableText;
  final String? warning;
}

/// Imports an external resource into the native Workspace model. The original
/// file is always retained as an attachment; loss-prone formats are never
/// silently overwritten by their extracted representation.
class ExternalDocumentImportService {
  ExternalDocumentImportService({
    required DocumentRepository repository,
    LocalAttachmentStorage? attachmentStorage,
  }) : _repository = repository,
       _storage = attachmentStorage ?? LocalAttachmentStorage();

  final DocumentRepository _repository;
  final LocalAttachmentStorage _storage;

  static const supportedExtensions = <String>[
    'txt',
    'md',
    'markdown',
    'pdf',
    'docx',
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'mp4',
    'mov',
    'm4v',
    'webm',
    'dart',
    'py',
    'js',
    'ts',
    'html',
    'css',
    'java',
    'c',
    'cpp',
    'json',
    'sql',
  ];

  Future<ExternalImportResult?> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedExtensions,
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return importFile(result.files.single);
  }

  Future<ExternalImportResult> importFile(PlatformFile source) async {
    final extension = _extension(source.name);
    if (!supportedExtensions.contains(extension)) {
      throw FormatException('Formato .$extension no compatible.');
    }
    await _validateSignature(source, extension);
    final stored = await _storage.copyFile(source);
    final blocks = <BaseBlock>[];
    var editable = false;
    String? warning;

    if (_plainTextExtensions.contains(extension)) {
      final text = await File(stored.localPath).readAsString();
      blocks.add(_textBlock(text, 0));
      editable = true;
    } else if (_codeLanguages.containsKey(extension)) {
      final text = await File(stored.localPath).readAsString();
      blocks.add(
        CodeBlock(
          id: generateUuid(),
          orderKey: 0,
          code: text,
          languageId: _codeLanguages[extension]!,
          showLineNumbers: true,
          caption: source.name,
        ),
      );
      editable = true;
    } else if (extension == 'docx') {
      final text = await _extractDocxText(stored.localPath);
      if (text.trim().isNotEmpty) {
        blocks.add(_textBlock(text, 0));
        editable = true;
      }
      warning =
          'Se extrajo el texto compatible. El archivo Word original se conserva porque estilos avanzados pueden variar.';
    } else if (_imageExtensions.contains(extension)) {
      blocks.add(
        ImageBlock(
          id: generateUuid(),
          orderKey: 0,
          attachmentId: stored.id,
          altText: source.name,
          metadata: _attachmentMetadata(stored, sourceFormat: extension),
        ),
      );
      warning =
          'Puedes usar OCR desde las opciones de la imagen para convertir su texto en bloques editables.';
    } else {
      warning = extension == 'pdf'
          ? 'El PDF se conserva sin alteraciones. La edición requiere extraer o reconstruir su contenido.'
          : 'El archivo multimedia se conserva como recurso adjunto.';
    }

    if (!_imageExtensions.contains(extension)) {
      blocks.add(
        AttachmentBlock(
          id: generateUuid(),
          orderKey: blocks.length.toDouble(),
          attachmentId: stored.id,
          displayName: stored.originalFileName,
          mimeType: stored.mimeType,
          extension: stored.extension,
          sizeBytes: stored.sizeBytes,
          description: 'Archivo original importado',
          metadata: _attachmentMetadata(stored, sourceFormat: extension),
        ),
      );
    }

    final draft = await _repository.createDocument();
    final workspace = draft.content.workspace;
    final page = workspace.primaryPage.copyWith(blocks: blocks);
    final nextWorkspace = workspace.copyWith(
      title: _baseName(source.name),
      pages: [page, ...workspace.pages.skip(1)],
      metadata: {
        ...workspace.metadata,
        'sourceFormat': extension,
        'sourceMimeType': stored.mimeType,
        'originalAttachmentId': stored.id,
        'importedAt': DateTime.now().toUtc().toIso8601String(),
        'editableExtraction': editable,
      },
    );
    final document = await _repository.updateDocument(
      draft.copyWith(
        title: _baseName(source.name),
        content: draft.content.withWorkspace(nextWorkspace),
        categoryId: 'archivos',
      ),
    );
    return ExternalImportResult(
      document: document,
      sourceExtension: extension,
      convertedToEditableText: editable,
      warning: warning,
    );
  }

  TextBlock _textBlock(String text, double order) => TextBlock(
    id: generateUuid(),
    orderKey: order,
    paragraphs: [
      for (final line in text.replaceAll('\r\n', '\n').split('\n'))
        BlockParagraph(id: generateUuid(), text: line),
    ],
    metadata: const {'origin': 'externalImport'},
  );

  Future<String> _extractDocxText(String path) async {
    final source = File(path);
    final compressedBytes = await source.length();
    if (compressedBytes > 25 * 1024 * 1024) {
      throw const FormatException(
        'El DOCX supera el límite seguro de procesamiento de 25 MB.',
      );
    }
    final bytes = await source.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    if (archive.length > 2000 ||
        archive.files.fold<int>(0, (total, file) => total + file.size) >
            100 * 1024 * 1024) {
      throw const FormatException(
        'El DOCX contiene demasiados recursos o datos expandidos.',
      );
    }
    final entry = archive.findFile('word/document.xml');
    if (entry == null) return '';
    if (entry.size > 20 * 1024 * 1024) {
      throw const FormatException(
        'El contenido XML del DOCX es demasiado grande.',
      );
    }
    final document = XmlDocument.parse(utf8.decode(entry.content as List<int>));
    return document.descendants
        .whereType<XmlElement>()
        .where((node) => node.name.local == 'p')
        .map(
          (paragraph) => paragraph.descendants
              .whereType<XmlElement>()
              .where((node) => node.name.local == 't')
              .map((node) => node.innerText)
              .join(),
        )
        .join('\n');
  }

  Map<String, Object?> _attachmentMetadata(
    StoredFileAttachment stored, {
    required String sourceFormat,
  }) => {
    'checksum': stored.checksum,
    'sourceFormat': sourceFormat,
    'originalFileName': stored.originalFileName,
  };

  String _extension(String name) =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
  String _baseName(String name) {
    final value = name.trim();
    if (!value.contains('.')) return value;
    return value.substring(0, value.lastIndexOf('.'));
  }

  static const _plainTextExtensions = {'txt', 'md', 'markdown'};
  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif'};
  static const _codeLanguages = <String, String>{
    'dart': 'dart',
    'py': 'python',
    'js': 'javascript',
    'ts': 'typescript',
    'html': 'html',
    'css': 'css',
    'java': 'java',
    'c': 'c',
    'cpp': 'cpp',
    'json': 'json',
    'sql': 'sql',
  };

  Future<void> _validateSignature(PlatformFile source, String extension) async {
    final path = source.path;
    if (path == null ||
        _plainTextExtensions.contains(extension) ||
        _codeLanguages.containsKey(extension)) {
      return;
    }
    final file = File(path);
    final handle = await file.open();
    try {
      final bytes = await handle.read(16);
      bool starts(List<int> signature) =>
          bytes.length >= signature.length &&
          List.generate(signature.length, (index) => bytes[index]).join(',') ==
              signature.join(',');
      final valid = switch (extension) {
        'pdf' => starts(const [0x25, 0x50, 0x44, 0x46, 0x2D]),
        'docx' => starts(const [0x50, 0x4B]),
        'jpg' || 'jpeg' => starts(const [0xFF, 0xD8, 0xFF]),
        'png' => starts(const [0x89, 0x50, 0x4E, 0x47]),
        'gif' => starts(const [0x47, 0x49, 0x46, 0x38]),
        'webp' =>
          bytes.length >= 12 &&
              String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
              String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP',
        'mp4' || 'mov' || 'm4v' =>
          bytes.length >= 8 &&
              String.fromCharCodes(bytes.skip(4).take(4)) == 'ftyp',
        'webm' => starts(const [0x1A, 0x45, 0xDF, 0xA3]),
        _ => true,
      };
      if (!valid) {
        throw FormatException(
          'El contenido del archivo no coincide con la extensión .$extension.',
        );
      }
    } finally {
      await handle.close();
    }
  }
}
