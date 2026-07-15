import 'dart:typed_data';

import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/entities/workspace.dart';

import 'content_fidelity.dart';
import 'content_format.dart';

typedef ContentBytesLoader = Future<List<int>> Function();

class ContentSource {
  ContentSource({
    required this.fileName,
    required this.loadBytes,
    this.mimeType,
    this.byteSize,
    Map<String, Object?> metadata = const {},
  }) : metadata = Map.unmodifiable(metadata);

  final String fileName;
  final String? mimeType;
  final int? byteSize;
  final ContentBytesLoader loadBytes;
  final JsonMap metadata;

  Future<Uint8List> readBytes() async => Uint8List.fromList(await loadBytes());
}

class ContentBinaryArtifact {
  ContentBinaryArtifact({
    required this.fileName,
    required this.mimeType,
    required List<int> bytes,
    Map<String, Object?> metadata = const {},
  }) : _bytes = Uint8List.fromList(bytes),
       metadata = Map.unmodifiable(metadata);

  final String fileName;
  final String mimeType;
  final Uint8List _bytes;
  final JsonMap metadata;

  int get byteSize => _bytes.length;
  Uint8List get bytes => Uint8List.fromList(_bytes);
}

enum ContentIoOperation { importContent, exportContent }

enum ContentIoOutcome { succeeded, partial, failed, cancelled }

enum ContentIoNoticeSeverity { information, warning, error }

class ContentIoNotice {
  const ContentIoNotice({
    required this.code,
    required this.message,
    required this.severity,
    required this.operation,
    this.lossKind,
    this.feature,
  });

  final String code;
  final String message;
  final ContentIoNoticeSeverity severity;
  final ContentIoOperation operation;
  final ContentLossKind? lossKind;
  final ContentFeature? feature;

  bool get isBlocking => severity == ContentIoNoticeSeverity.error;

  factory ContentIoNotice.fromFeatureChange({
    required ContentFeatureChange change,
    required ContentFormatDescriptor target,
  }) {
    final action = switch (change.preservation) {
      ContentPreservation.converted => 'se convertirá',
      ContentPreservation.flattened => 'se aplanará',
      ContentPreservation.omitted => 'se omitirá',
      ContentPreservation.unknown => 'podría no conservarse',
      ContentPreservation.exact => 'se conservará',
    };
    return ContentIoNotice(
      code: 'export.feature.${change.preservation.name}.${change.feature.name}',
      message:
          'La característica ${change.feature.name} $action al exportar como '
          '${target.canonicalName}.',
      severity: change.isLossy
          ? ContentIoNoticeSeverity.warning
          : ContentIoNoticeSeverity.information,
      operation: ContentIoOperation.exportContent,
      lossKind: change.lossKind,
      feature: change.feature,
    );
  }
}

enum ContentImportMode { editableWorkspace, preserveOriginal, both }

class ContentImportRequest {
  ContentImportRequest({
    required this.source,
    required this.sourceFormat,
    this.mode = ContentImportMode.both,
    this.targetWorkspaceId,
    Map<String, Object?> metadata = const {},
  }) : metadata = Map.unmodifiable(metadata);

  final ContentSource source;
  final ContentFormatId sourceFormat;
  final ContentImportMode mode;
  final String? targetWorkspaceId;
  final JsonMap metadata;
}

sealed class ContentImportArtifact {
  const ContentImportArtifact();
}

final class WorkspaceImportArtifact extends ContentImportArtifact {
  const WorkspaceImportArtifact(this.workspace);

  final Workspace workspace;
}

/// Keeps a file available even when there is no lossless editable conversion.
/// The data layer is responsible for copying [source] to durable storage.
final class PreservedFileImportArtifact extends ContentImportArtifact {
  const PreservedFileImportArtifact({
    required this.source,
    required this.formatId,
    required this.openMode,
  });

  final ContentSource source;
  final ContentFormatId formatId;
  final ContentOpenMode openMode;
}

class ContentImportResult {
  ContentImportResult({
    required this.outcome,
    required Iterable<ContentImportArtifact> artifacts,
    Iterable<ContentIoNotice> notices = const [],
    Map<String, Object?> metadata = const {},
  }) : artifacts = List.unmodifiable(artifacts),
       notices = List.unmodifiable(notices),
       metadata = Map.unmodifiable(metadata) {
    if ((outcome == ContentIoOutcome.succeeded ||
            outcome == ContentIoOutcome.partial) &&
        this.artifacts.isEmpty) {
      throw ArgumentError('Un resultado exitoso debe contener un artefacto.');
    }
  }

  final ContentIoOutcome outcome;
  final List<ContentImportArtifact> artifacts;
  final List<ContentIoNotice> notices;
  final JsonMap metadata;

  bool get isSuccess =>
      outcome == ContentIoOutcome.succeeded ||
      outcome == ContentIoOutcome.partial;
  Workspace? get workspace =>
      artifacts.whereType<WorkspaceImportArtifact>().firstOrNull?.workspace;
}

class ContentExportRequest {
  ContentExportRequest({
    required this.workspace,
    required this.targetFormat,
    required this.fileName,
    ContentFeatureManifest? features,
    Map<String, Object?> options = const {},
  }) : features = features ?? ContentFeatureManifest.fromWorkspace(workspace),
       options = Map.unmodifiable(options);

  final Workspace workspace;
  final ContentFormatId targetFormat;
  final String fileName;
  final ContentFeatureManifest features;
  final JsonMap options;
}

class ContentExportResult {
  ContentExportResult({
    required this.outcome,
    this.artifact,
    Iterable<ContentIoNotice> notices = const [],
    Map<String, Object?> metadata = const {},
  }) : notices = List.unmodifiable(notices),
       metadata = Map.unmodifiable(metadata) {
    if ((outcome == ContentIoOutcome.succeeded ||
            outcome == ContentIoOutcome.partial) &&
        artifact == null) {
      throw ArgumentError('Una exportación exitosa debe producir un archivo.');
    }
  }

  final ContentIoOutcome outcome;
  final ContentBinaryArtifact? artifact;
  final List<ContentIoNotice> notices;
  final JsonMap metadata;

  bool get isSuccess =>
      artifact != null &&
      (outcome == ContentIoOutcome.succeeded ||
          outcome == ContentIoOutcome.partial);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
