import 'content_fidelity.dart';
import 'content_format.dart';
import 'content_io_registry.dart';

abstract final class StandardContentFormatIds {
  static const nativeDocument = ContentFormatId('allministrator.document');
  static const canvas = ContentFormatId('allministrator.canvas');
  static const pdf = ContentFormatId('pdf');
  static const docx = ContentFormatId('docx');
  static const markdown = ContentFormatId('markdown');
  static const plainText = ContentFormatId('text');
  static const image = ContentFormatId('image');
  static const video = ContentFormatId('video');
  static const sourceCode = ContentFormatId('source-code');
  static const unknown = ContentFormatId('unknown');
}

extension StandardContentIoRegistry on ContentIoRegistry {
  void registerStandardFormats() {
    for (final entry in _standardFormats) {
      registerFormat(entry.descriptor, exportPolicy: entry.exportPolicy);
    }
  }
}

final List<_StandardFormat> _standardFormats = [
  _StandardFormat(
    descriptor: ContentFormatDescriptor(
      id: StandardContentFormatIds.nativeDocument,
      canonicalName: 'Documento Allministrator',
      family: ContentFormatFamily.native,
      extensions: const ['allmdoc'],
      mimeTypes: const ['application/vnd.allministrator.document+json'],
      capabilities: const {
        ContentFormatCapability.importContent,
        ContentFormatCapability.exportContent,
        ContentFormatCapability.preview,
        ContentFormatCapability.edit,
        ContentFormatCapability.annotate,
        ContentFormatCapability.extractText,
        ContentFormatCapability.preserveOriginal,
      },
      defaultOpenMode: ContentOpenMode.nativeEditor,
      visualIdentity: 'native-document',
      preferredExtension: 'allmdoc',
    ),
    exportPolicy: ContentFidelityPolicy(
      defaultPreservation: ContentPreservation.exact,
      overrides: const {
        ContentFeature.spatialLayout: ContentPreservation.omitted,
      },
    ),
  ),
  _StandardFormat(
    descriptor: ContentFormatDescriptor(
      id: StandardContentFormatIds.canvas,
      canonicalName: 'Canvas Allministrator',
      family: ContentFormatFamily.native,
      extensions: const ['allmcanvas'],
      mimeTypes: const ['application/vnd.allministrator.canvas+json'],
      capabilities: const {
        ContentFormatCapability.importContent,
        ContentFormatCapability.exportContent,
        ContentFormatCapability.preview,
        ContentFormatCapability.edit,
        ContentFormatCapability.annotate,
        ContentFormatCapability.extractText,
        ContentFormatCapability.preserveOriginal,
      },
      defaultOpenMode: ContentOpenMode.nativeEditor,
      visualIdentity: 'canvas',
      preferredExtension: 'allmcanvas',
    ),
    exportPolicy: ContentFidelityPolicy(
      defaultPreservation: ContentPreservation.exact,
    ),
  ),
  _StandardFormat(
    descriptor: ContentFormatDescriptor(
      id: StandardContentFormatIds.pdf,
      canonicalName: 'PDF',
      family: ContentFormatFamily.pagedDocument,
      extensions: const ['pdf'],
      mimeTypes: const ['application/pdf'],
      capabilities: const {
        ContentFormatCapability.importContent,
        ContentFormatCapability.exportContent,
        ContentFormatCapability.preview,
        ContentFormatCapability.annotate,
        ContentFormatCapability.extractText,
        ContentFormatCapability.preserveOriginal,
      },
      defaultOpenMode: ContentOpenMode.annotationEditor,
      visualIdentity: 'pdf',
      preferredExtension: 'pdf',
    ),
    exportPolicy: ContentFidelityPolicy(
      defaultPreservation: ContentPreservation.exact,
      overrides: const {
        ContentFeature.spatialLayout: ContentPreservation.flattened,
        ContentFeature.video: ContentPreservation.omitted,
        ContentFeature.attachments: ContentPreservation.omitted,
        ContentFeature.ink: ContentPreservation.flattened,
        ContentFeature.annotations: ContentPreservation.flattened,
        ContentFeature.interactiveBlocks: ContentPreservation.flattened,
        ContentFeature.unsupportedBlocks: ContentPreservation.omitted,
        ContentFeature.metadata: ContentPreservation.omitted,
      },
    ),
  ),
  _StandardFormat(
    descriptor: ContentFormatDescriptor(
      id: StandardContentFormatIds.docx,
      canonicalName: 'Microsoft Word',
      family: ContentFormatFamily.pagedDocument,
      extensions: const ['docx'],
      mimeTypes: const [
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ],
      capabilities: const {
        ContentFormatCapability.importContent,
        ContentFormatCapability.exportContent,
        ContentFormatCapability.preview,
        ContentFormatCapability.edit,
        ContentFormatCapability.extractText,
        ContentFormatCapability.preserveOriginal,
      },
      defaultOpenMode: ContentOpenMode.convertedWorkspace,
      visualIdentity: 'word',
      preferredExtension: 'docx',
    ),
    exportPolicy: ContentFidelityPolicy(
      defaultPreservation: ContentPreservation.exact,
      overrides: const {
        ContentFeature.spatialLayout: ContentPreservation.flattened,
        ContentFeature.video: ContentPreservation.omitted,
        ContentFeature.ink: ContentPreservation.flattened,
        ContentFeature.annotations: ContentPreservation.converted,
        ContentFeature.interactiveBlocks: ContentPreservation.converted,
        ContentFeature.unsupportedBlocks: ContentPreservation.omitted,
        ContentFeature.metadata: ContentPreservation.omitted,
      },
    ),
  ),
  _StandardFormat(
    descriptor: ContentFormatDescriptor(
      id: StandardContentFormatIds.markdown,
      canonicalName: 'Markdown',
      family: ContentFormatFamily.text,
      extensions: const ['md', 'markdown', 'mdown'],
      mimeTypes: const ['text/markdown', 'text/x-markdown'],
      capabilities: const {
        ContentFormatCapability.importContent,
        ContentFormatCapability.exportContent,
        ContentFormatCapability.preview,
        ContentFormatCapability.edit,
        ContentFormatCapability.extractText,
        ContentFormatCapability.preserveOriginal,
      },
      defaultOpenMode: ContentOpenMode.convertedWorkspace,
      visualIdentity: 'markdown',
      preferredExtension: 'md',
    ),
    exportPolicy: ContentFidelityPolicy(
      defaultPreservation: ContentPreservation.exact,
      overrides: const {
        ContentFeature.richText: ContentPreservation.converted,
        ContentFeature.tables: ContentPreservation.converted,
        ContentFeature.images: ContentPreservation.converted,
        ContentFeature.pagination: ContentPreservation.omitted,
        ContentFeature.spatialLayout: ContentPreservation.omitted,
        ContentFeature.video: ContentPreservation.omitted,
        ContentFeature.attachments: ContentPreservation.omitted,
        ContentFeature.ink: ContentPreservation.omitted,
        ContentFeature.annotations: ContentPreservation.omitted,
        ContentFeature.interactiveBlocks: ContentPreservation.converted,
        ContentFeature.unsupportedBlocks: ContentPreservation.omitted,
        ContentFeature.metadata: ContentPreservation.omitted,
      },
    ),
  ),
  _StandardFormat(
    descriptor: ContentFormatDescriptor(
      id: StandardContentFormatIds.plainText,
      canonicalName: 'Texto sin formato',
      family: ContentFormatFamily.text,
      extensions: const ['txt'],
      mimeTypes: const ['text/plain'],
      capabilities: const {
        ContentFormatCapability.importContent,
        ContentFormatCapability.exportContent,
        ContentFormatCapability.preview,
        ContentFormatCapability.edit,
        ContentFormatCapability.extractText,
        ContentFormatCapability.preserveOriginal,
      },
      defaultOpenMode: ContentOpenMode.convertedWorkspace,
      visualIdentity: 'text',
      preferredExtension: 'txt',
    ),
    exportPolicy: ContentFidelityPolicy(
      defaultPreservation: ContentPreservation.omitted,
      overrides: const {ContentFeature.plainText: ContentPreservation.exact},
    ),
  ),
  _StandardFormat(
    descriptor: ContentFormatDescriptor(
      id: StandardContentFormatIds.image,
      canonicalName: 'Imagen',
      family: ContentFormatFamily.image,
      extensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'heic', 'bmp'],
      mimeTypes: const ['image/*'],
      capabilities: const {
        ContentFormatCapability.importContent,
        ContentFormatCapability.exportContent,
        ContentFormatCapability.preview,
        ContentFormatCapability.annotate,
        ContentFormatCapability.extractText,
        ContentFormatCapability.preserveOriginal,
      },
      defaultOpenMode: ContentOpenMode.annotationEditor,
      visualIdentity: 'image',
      preferredExtension: 'png',
    ),
    exportPolicy: ContentFidelityPolicy(
      defaultPreservation: ContentPreservation.flattened,
      overrides: const {
        ContentFeature.video: ContentPreservation.omitted,
        ContentFeature.attachments: ContentPreservation.omitted,
        ContentFeature.interactiveBlocks: ContentPreservation.omitted,
        ContentFeature.unsupportedBlocks: ContentPreservation.omitted,
        ContentFeature.metadata: ContentPreservation.omitted,
      },
    ),
  ),
  _StandardFormat(
    descriptor: ContentFormatDescriptor(
      id: StandardContentFormatIds.video,
      canonicalName: 'Video',
      family: ContentFormatFamily.video,
      extensions: const ['mp4', 'mov', 'm4v', 'webm', 'mkv', 'avi'],
      mimeTypes: const ['video/*'],
      capabilities: const {
        ContentFormatCapability.importContent,
        ContentFormatCapability.preview,
        ContentFormatCapability.preserveOriginal,
        ContentFormatCapability.playMedia,
      },
      defaultOpenMode: ContentOpenMode.previewOnly,
      visualIdentity: 'video',
    ),
    exportPolicy: ContentFidelityPolicy(
      defaultPreservation: ContentPreservation.unknown,
    ),
  ),
  _StandardFormat(
    descriptor: ContentFormatDescriptor(
      id: StandardContentFormatIds.sourceCode,
      canonicalName: 'Código fuente',
      family: ContentFormatFamily.sourceCode,
      extensions: const [
        'dart',
        'js',
        'ts',
        'jsx',
        'tsx',
        'html',
        'css',
        'scss',
        'json',
        'yaml',
        'yml',
        'xml',
        'py',
        'java',
        'kt',
        'swift',
        'c',
        'h',
        'cpp',
        'cs',
        'go',
        'rs',
        'sh',
        'sql',
      ],
      mimeTypes: const [
        'application/json',
        'application/xml',
        'application/javascript',
        'text/javascript',
        'text/css',
        'text/html',
        'text/x-*',
      ],
      capabilities: const {
        ContentFormatCapability.importContent,
        ContentFormatCapability.exportContent,
        ContentFormatCapability.preview,
        ContentFormatCapability.edit,
        ContentFormatCapability.extractText,
        ContentFormatCapability.preserveOriginal,
      },
      defaultOpenMode: ContentOpenMode.convertedWorkspace,
      visualIdentity: 'code',
    ),
    exportPolicy: ContentFidelityPolicy(
      defaultPreservation: ContentPreservation.omitted,
      overrides: const {
        ContentFeature.plainText: ContentPreservation.exact,
        ContentFeature.code: ContentPreservation.exact,
      },
    ),
  ),
  _StandardFormat(
    descriptor: ContentFormatDescriptor(
      id: StandardContentFormatIds.unknown,
      canonicalName: 'Archivo',
      family: ContentFormatFamily.unknown,
      extensions: const [],
      mimeTypes: const [],
      capabilities: const {
        ContentFormatCapability.importContent,
        ContentFormatCapability.preserveOriginal,
      },
      defaultOpenMode: ContentOpenMode.externalViewer,
      visualIdentity: 'file',
    ),
    exportPolicy: ContentFidelityPolicy(
      defaultPreservation: ContentPreservation.unknown,
    ),
  ),
];

class _StandardFormat {
  const _StandardFormat({required this.descriptor, required this.exportPolicy});

  final ContentFormatDescriptor descriptor;
  final ContentFidelityPolicy exportPolicy;
}
