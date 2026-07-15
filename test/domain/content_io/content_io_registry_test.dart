import 'package:allministrator/domain/content_io/content_io.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContentIoRegistry', () {
    late ContentIoRegistry registry;

    setUp(() {
      registry = ContentIoRegistry()..registerStandardFormats();
    });

    test('detects a standard format using extension and MIME evidence', () {
      final detection = registry.detect(
        fileName: r'C:\Downloads\REPORT.PDF',
        mimeType: 'application/pdf; charset=binary',
      );

      expect(detection.selected?.id, StandardContentFormatIds.pdf);
      expect(detection.confidence, ContentDetectionConfidence.high);
      expect(detection.notices, isEmpty);
    });

    test('detects generic image and video families by concrete MIME', () {
      expect(
        registry
            .detect(fileName: 'foto.JPG', mimeType: 'image/jpeg')
            .selected
            ?.id,
        StandardContentFormatIds.image,
      );
      expect(
        registry
            .detect(fileName: 'clip.mov', mimeType: 'video/quicktime')
            .selected
            ?.id,
        StandardContentFormatIds.video,
      );
    });

    test('does not silently choose when MIME and extension conflict', () {
      final detection = registry.detect(
        fileName: 'reporte.pdf',
        mimeType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );

      expect(detection.selected, isNull);
      expect(detection.isAmbiguous, isTrue);
      expect(
        detection.candidates.map((format) => format.id),
        containsAll([
          StandardContentFormatIds.pdf,
          StandardContentFormatIds.docx,
        ]),
      );
      expect(
        detection.notices.single.code,
        'detection.mime_extension_conflict',
      );
    });

    test('falls back to the preservable unknown-file descriptor', () {
      final detection = registry.detect(
        fileName: 'datos.proprietary',
        mimeType: 'application/x-proprietary',
      );

      expect(detection.selected?.id, StandardContentFormatIds.unknown);
      expect(detection.confidence, ContentDetectionConfidence.low);
    });

    test('distinguishes declared support from an installed adapter', () {
      final before = registry.readiness(
        StandardContentFormatIds.plainText,
        ContentIoOperation.exportContent,
      );
      expect(before.declaredByFormat, isTrue);
      expect(before.adapterAvailable, isFalse);
      expect(before.isPlanned, isTrue);

      registry.registerAdapter(_PlainTextAdapter());

      final after = registry.readiness(
        StandardContentFormatIds.plainText,
        ContentIoOperation.exportContent,
      );
      expect(after.isReady, isTrue);
      expect(
        registry.importerFor(StandardContentFormatIds.plainText),
        isNotNull,
      );
      expect(
        registry.exporterFor(StandardContentFormatIds.plainText),
        isNotNull,
      );
    });

    test('tracks OCR and preview providers independently from import', () {
      final before = registry.capabilityReadiness(
        StandardContentFormatIds.image,
        ContentFormatCapability.extractText,
      );
      expect(before.isPlanned, isTrue);

      registry.registerAdapter(_ImageOcrProvider());

      final after = registry.capabilityReadiness(
        StandardContentFormatIds.image,
        ContentFormatCapability.extractText,
      );
      expect(after.isReady, isTrue);
      expect(
        registry.providerFor(
          StandardContentFormatIds.image,
          ContentFormatCapability.extractText,
        ),
        isA<_ImageOcrProvider>(),
      );
      expect(registry.importerFor(StandardContentFormatIds.image), isNull);
    });

    test('rejects adapters for unregistered formats', () {
      expect(
        () => registry.registerAdapter(_UnregisteredAdapter()),
        throwsStateError,
      );
    });

    test(
      'adapter contracts support import and export without IO libraries',
      () async {
        final adapter = _PlainTextAdapter();
        registry.registerAdapter(adapter);
        final source = ContentSource(
          fileName: 'nota.txt',
          mimeType: 'text/plain',
          loadBytes: () async => [104, 111, 108, 97],
        );

        final imported = await registry
            .importerFor(StandardContentFormatIds.plainText)!
            .importContent(
              ContentImportRequest(
                source: source,
                sourceFormat: StandardContentFormatIds.plainText,
                mode: ContentImportMode.preserveOriginal,
              ),
            );
        final exported = await registry
            .exporterFor(StandardContentFormatIds.plainText)!
            .exportContent(
              ContentExportRequest(
                workspace: _emptyWorkspace(),
                targetFormat: StandardContentFormatIds.plainText,
                fileName: 'nota.txt',
              ),
            );

        expect(imported.isSuccess, isTrue);
        expect(imported.artifacts.single, isA<PreservedFileImportArtifact>());
        expect(exported.isSuccess, isTrue);
        expect(exported.artifact?.bytes, [104, 111, 108, 97]);
      },
    );
  });
}

class _PlainTextAdapter implements ContentImporter, ContentExporter {
  @override
  ContentFormatId get formatId => StandardContentFormatIds.plainText;

  @override
  Future<ContentImportResult> importContent(
    ContentImportRequest request,
  ) async {
    return ContentImportResult(
      outcome: ContentIoOutcome.succeeded,
      artifacts: [
        PreservedFileImportArtifact(
          source: request.source,
          formatId: formatId,
          openMode: ContentOpenMode.convertedWorkspace,
        ),
      ],
    );
  }

  @override
  Future<ContentExportResult> exportContent(
    ContentExportRequest request,
  ) async {
    return ContentExportResult(
      outcome: ContentIoOutcome.succeeded,
      artifact: ContentBinaryArtifact(
        fileName: request.fileName,
        mimeType: 'text/plain',
        bytes: const [104, 111, 108, 97],
      ),
    );
  }
}

class _UnregisteredAdapter implements ContentImporter {
  @override
  ContentFormatId get formatId => const ContentFormatId('custom.unregistered');

  @override
  Future<ContentImportResult> importContent(ContentImportRequest request) {
    throw UnimplementedError();
  }
}

class _ImageOcrProvider implements ContentCapabilityProvider {
  @override
  ContentFormatId get formatId => StandardContentFormatIds.image;

  @override
  Set<ContentFormatCapability> get providedCapabilities => const {
    ContentFormatCapability.extractText,
  };
}

Workspace _emptyWorkspace() {
  final now = DateTime.utc(2026, 7, 15);
  return Workspace(
    id: 'workspace',
    title: 'Vacío',
    description: null,
    workspaceType: WorkspaceType.document,
    pages: const [],
    themeId: null,
    templateId: null,
    isFavorite: false,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
    version: 1,
    deletedAt: null,
    metadata: const {},
  );
}
