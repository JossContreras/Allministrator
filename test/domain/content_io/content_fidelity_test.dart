import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/content_io/content_io.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/domain/value_objects/structured_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('content fidelity', () {
    test('discovers export-relevant features from a canvas workspace', () {
      final manifest = ContentFeatureManifest.fromWorkspace(_canvasWorkspace());

      expect(
        manifest.features,
        containsAll([
          ContentFeature.plainText,
          ContentFeature.richText,
          ContentFeature.headings,
          ContentFeature.lists,
          ContentFeature.links,
          ContentFeature.images,
          ContentFeature.video,
          ContentFeature.attachments,
          ContentFeature.spatialLayout,
          ContentFeature.interactiveBlocks,
          ContentFeature.metadata,
        ]),
      );
    });

    test('preflight reports omitted and flattened features separately', () {
      final registry = ContentIoRegistry()..registerStandardFormats();
      registry.registerAdapter(_PdfExporter());
      final preflight = registry.preflightExport(
        targetFormat: StandardContentFormatIds.pdf,
        sourceFeatures: ContentFeatureManifest.fromWorkspace(
          _canvasWorkspace(),
        ),
      );

      expect(preflight.canProceed, isTrue);
      expect(preflight.requiresConfirmation, isTrue);
      expect(preflight.lossReport.hasLosses, isTrue);
      expect(
        preflight.lossReport.changes.any(
          (change) =>
              change.feature == ContentFeature.spatialLayout &&
              change.preservation == ContentPreservation.flattened,
        ),
        isTrue,
      );
      expect(
        preflight.lossReport.changes.any(
          (change) =>
              change.feature == ContentFeature.video &&
              change.preservation == ContentPreservation.omitted,
        ),
        isTrue,
      );
      expect(
        preflight.notices.map((notice) => notice.code),
        contains('export.feature.omitted.video'),
      );
    });

    test('preflight blocks an export until its adapter is installed', () {
      final registry = ContentIoRegistry()..registerStandardFormats();
      final preflight = registry.preflightExport(
        targetFormat: StandardContentFormatIds.docx,
        sourceFeatures: ContentFeatureManifest(const [
          ContentFeature.plainText,
        ]),
      );

      expect(preflight.canProceed, isFalse);
      expect(preflight.readiness.isPlanned, isTrue);
      expect(
        preflight.notices.map((notice) => notice.code),
        contains('export.adapter_unavailable'),
      );
    });

    test('native canvas preserves every currently known feature', () {
      final registry = ContentIoRegistry()..registerStandardFormats();
      registry.registerAdapter(_CanvasExporter());
      final preflight = registry.preflightExport(
        targetFormat: StandardContentFormatIds.canvas,
        sourceFeatures: ContentFeatureManifest(ContentFeature.values),
      );

      expect(preflight.canProceed, isTrue);
      expect(preflight.lossReport.changes, isEmpty);
      expect(preflight.requiresConfirmation, isFalse);
    });
  });
}

class _PdfExporter implements ContentExporter {
  @override
  ContentFormatId get formatId => StandardContentFormatIds.pdf;

  @override
  Future<ContentExportResult> exportContent(ContentExportRequest request) {
    throw UnimplementedError();
  }
}

class _CanvasExporter implements ContentExporter {
  @override
  ContentFormatId get formatId => StandardContentFormatIds.canvas;

  @override
  Future<ContentExportResult> exportContent(ContentExportRequest request) {
    throw UnimplementedError();
  }
}

Workspace _canvasWorkspace() {
  final now = DateTime.utc(2026, 7, 15);
  return Workspace(
    id: 'canvas',
    title: 'Proyecto',
    description: null,
    workspaceType: WorkspaceType.canvas,
    pages: [
      WorkspacePage(
        id: 'page',
        workspaceId: 'canvas',
        title: null,
        layoutType: WorkspaceLayoutType.canvas,
        blocks: [
          TextBlock(
            id: 'text',
            orderKey: 0,
            paragraphs: const [
              BlockParagraph(
                id: 'paragraph',
                text: 'Pendiente',
                attributes: ParagraphAttributes(listType: 'bullet'),
                spans: [
                  TextSpanMark(
                    start: 0,
                    end: 9,
                    attributes: {'href': 'https://example.test'},
                  ),
                ],
                metadata: {'headingLevel': 2},
              ),
            ],
            createdAt: now,
            updatedAt: now,
          ),
          ImageBlock(
            id: 'image',
            orderKey: 1,
            attachmentId: 'image-file',
            createdAt: now,
            updatedAt: now,
          ),
          ChecklistBlock(
            id: 'checklist',
            orderKey: 2,
            items: const [BlockChecklistItem(id: 'item', text: 'Revisar')],
            createdAt: now,
            updatedAt: now,
          ),
          AttachmentBlock(
            id: 'video',
            orderKey: 3,
            attachmentId: 'video-file',
            displayName: 'demo.mp4',
            mimeType: 'video/mp4',
            extension: 'mp4',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        version: 1,
        metadata: const {'camera': 'persisted'},
      ),
    ],
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
