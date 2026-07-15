import 'content_format.dart';
import 'content_io_models.dart';

abstract interface class ContentAdapter {
  ContentFormatId get formatId;
}

/// Declares non-I/O capabilities supplied by an adapter, such as OCR,
/// previewing or media playback. Import and export are inferred from the
/// corresponding typed interfaces and must not be repeated here.
abstract interface class ContentCapabilityProvider implements ContentAdapter {
  Set<ContentFormatCapability> get providedCapabilities;
}

abstract interface class ContentImporter implements ContentAdapter {
  Future<ContentImportResult> importContent(ContentImportRequest request);
}

abstract interface class ContentExporter implements ContentAdapter {
  Future<ContentExportResult> exportContent(ContentExportRequest request);
}

class UnsupportedContentOperation implements Exception {
  const UnsupportedContentOperation({
    required this.formatId,
    required this.operation,
    this.reason,
  });

  final ContentFormatId formatId;
  final ContentIoOperation operation;
  final String? reason;

  @override
  String toString() =>
      'UnsupportedContentOperation(${formatId.value}, ${operation.name}'
      '${reason == null ? '' : ', $reason'})';
}
