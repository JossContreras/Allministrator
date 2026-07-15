import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/domain/value_objects/structured_document.dart';

import 'content_format.dart';

enum ContentFeature {
  plainText,
  richText,
  headings,
  lists,
  tables,
  images,
  video,
  attachments,
  links,
  code,
  pagination,
  spatialLayout,
  ink,
  annotations,
  interactiveBlocks,
  unsupportedBlocks,
  metadata,
}

enum ContentPreservation { exact, converted, flattened, omitted, unknown }

enum ContentLossKind {
  formatting,
  structure,
  layout,
  media,
  annotations,
  interactivity,
  metadata,
  unknown,
}

class ContentFeatureManifest {
  ContentFeatureManifest(Iterable<ContentFeature> features)
    : features = Set.unmodifiable(features);

  factory ContentFeatureManifest.fromWorkspace(Workspace workspace) {
    final features = <ContentFeature>{};
    if (workspace.pages.length > 1) features.add(ContentFeature.pagination);
    if (workspace.metadata.isNotEmpty) features.add(ContentFeature.metadata);

    for (final page in workspace.pages) {
      if (page.layoutType == WorkspaceLayoutType.canvas) {
        features.add(ContentFeature.spatialLayout);
      }
      if (page.metadata.isNotEmpty) features.add(ContentFeature.metadata);
      if (page.inkLayer.elements.isNotEmpty) {
        features
          ..add(ContentFeature.ink)
          ..add(ContentFeature.annotations);
      }
      for (final block in page.blocks) {
        if (block.metadata.isNotEmpty) features.add(ContentFeature.metadata);
        switch (block) {
          case TextBlock():
            if (block.plainText.isNotEmpty) {
              features.add(ContentFeature.plainText);
            }
            if (block.paragraphs.any(
              (paragraph) => paragraph.spans.isNotEmpty,
            )) {
              features.add(ContentFeature.richText);
            }
            if (block.paragraphs.any(
              (paragraph) => paragraph.attributes.listType != null,
            )) {
              features.add(ContentFeature.lists);
            }
            if (block.paragraphs.any(_paragraphIsHeading)) {
              features.add(ContentFeature.headings);
            }
            if (block.paragraphs.any(_paragraphContainsLink)) {
              features.add(ContentFeature.links);
            }
          case ImageBlock():
            features.add(ContentFeature.images);
          case ChecklistBlock():
            features
              ..add(ContentFeature.plainText)
              ..add(ContentFeature.lists)
              ..add(ContentFeature.interactiveBlocks);
          case CodeBlock():
            features
              ..add(ContentFeature.plainText)
              ..add(ContentFeature.code);
          case TableBlock():
            features
              ..add(ContentFeature.plainText)
              ..add(ContentFeature.tables);
            final cells = block.rows.expand((row) => row.cells);
            if (cells.any((cell) => cell.spans.isNotEmpty)) {
              features.add(ContentFeature.richText);
            }
            if (cells.any((cell) => _spansContainLink(cell.spans))) {
              features.add(ContentFeature.links);
            }
          case AttachmentBlock():
            features.add(ContentFeature.attachments);
            if (block.mimeType.toLowerCase().startsWith('video/')) {
              features.add(ContentFeature.video);
            }
          case QuoteBlock():
            features
              ..add(ContentFeature.plainText)
              ..add(ContentFeature.richText);
            if (_spansContainLink(block.spans)) {
              features.add(ContentFeature.links);
            }
          case CalloutBlock():
            features
              ..add(ContentFeature.plainText)
              ..add(ContentFeature.richText);
            if (_spansContainLink(block.spans)) {
              features.add(ContentFeature.links);
            }
          case UnknownBlock():
            features.add(ContentFeature.unsupportedBlocks);
          case DividerBlock():
            break;
        }
      }
    }
    return ContentFeatureManifest(features);
  }

  final Set<ContentFeature> features;

  bool contains(ContentFeature feature) => features.contains(feature);
}

class ContentFidelityPolicy {
  ContentFidelityPolicy({
    required this.defaultPreservation,
    Map<ContentFeature, ContentPreservation> overrides = const {},
  }) : overrides = Map.unmodifiable(overrides);

  final ContentPreservation defaultPreservation;
  final Map<ContentFeature, ContentPreservation> overrides;

  ContentPreservation preservationFor(ContentFeature feature) =>
      overrides[feature] ?? defaultPreservation;

  ContentLossReport evaluate({
    required ContentFeatureManifest source,
    required ContentFormatDescriptor target,
  }) {
    final changes =
        source.features
            .map(
              (feature) => ContentFeatureChange(
                feature: feature,
                preservation: preservationFor(feature),
                lossKind: _lossKindFor(feature),
              ),
            )
            .where((change) => change.preservation != ContentPreservation.exact)
            .toList(growable: false)
          ..sort(
            (first, second) =>
                first.feature.index.compareTo(second.feature.index),
          );
    return ContentLossReport(targetFormat: target.id, changes: changes);
  }
}

class ContentFeatureChange {
  const ContentFeatureChange({
    required this.feature,
    required this.preservation,
    required this.lossKind,
  });

  final ContentFeature feature;
  final ContentPreservation preservation;
  final ContentLossKind lossKind;

  bool get isLossy =>
      preservation == ContentPreservation.flattened ||
      preservation == ContentPreservation.omitted ||
      preservation == ContentPreservation.unknown;
}

class ContentLossReport {
  ContentLossReport({
    required this.targetFormat,
    required Iterable<ContentFeatureChange> changes,
  }) : changes = List.unmodifiable(changes);

  final ContentFormatId targetFormat;
  final List<ContentFeatureChange> changes;

  bool get hasLosses => changes.any((change) => change.isLossy);
  bool get omitsContent => changes.any(
    (change) => change.preservation == ContentPreservation.omitted,
  );

  Iterable<ContentFeatureChange> get losses =>
      changes.where((change) => change.isLossy);
}

bool _paragraphContainsLink(BlockParagraph paragraph) => paragraph.spans.any(
  (span) =>
      span.attributes.containsKey('link') ||
      span.attributes.containsKey('href') ||
      span.attributes.containsKey('url'),
);

bool _spansContainLink(Iterable<TextSpanMark> spans) => spans.any(
  (span) =>
      span.attributes.containsKey('link') ||
      span.attributes.containsKey('href') ||
      span.attributes.containsKey('url'),
);

bool _paragraphIsHeading(BlockParagraph paragraph) {
  final level = paragraph.metadata['headingLevel'];
  if (level is num) return level >= 1 && level <= 6;
  final style = paragraph.metadata['style']?.toString().toLowerCase();
  return style != null &&
      (style.startsWith('heading') || RegExp(r'^h[1-6]$').hasMatch(style));
}

ContentLossKind _lossKindFor(ContentFeature feature) => switch (feature) {
  ContentFeature.richText ||
  ContentFeature.headings => ContentLossKind.formatting,
  ContentFeature.lists ||
  ContentFeature.tables ||
  ContentFeature.links ||
  ContentFeature.code => ContentLossKind.structure,
  ContentFeature.pagination ||
  ContentFeature.spatialLayout => ContentLossKind.layout,
  ContentFeature.images ||
  ContentFeature.video ||
  ContentFeature.attachments => ContentLossKind.media,
  ContentFeature.ink ||
  ContentFeature.annotations => ContentLossKind.annotations,
  ContentFeature.interactiveBlocks => ContentLossKind.interactivity,
  ContentFeature.unsupportedBlocks => ContentLossKind.unknown,
  ContentFeature.metadata => ContentLossKind.metadata,
  ContentFeature.plainText => ContentLossKind.unknown,
};
