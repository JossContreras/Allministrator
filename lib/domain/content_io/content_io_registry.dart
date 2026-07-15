import 'content_fidelity.dart';
import 'content_format.dart';
import 'content_io_adapter.dart';
import 'content_io_models.dart';

enum ContentDetectionConfidence { high, medium, low, ambiguous }

class ContentFormatDetection {
  ContentFormatDetection({
    required this.selected,
    required Iterable<ContentFormatDescriptor> candidates,
    required this.confidence,
    Iterable<ContentIoNotice> notices = const [],
  }) : candidates = List.unmodifiable(candidates),
       notices = List.unmodifiable(notices);

  final ContentFormatDescriptor? selected;
  final List<ContentFormatDescriptor> candidates;
  final ContentDetectionConfidence confidence;
  final List<ContentIoNotice> notices;

  bool get isAmbiguous => confidence == ContentDetectionConfidence.ambiguous;
}

class ContentOperationReadiness {
  const ContentOperationReadiness({
    required this.format,
    required this.operation,
    required this.declaredByFormat,
    required this.adapterAvailable,
  });

  final ContentFormatDescriptor format;
  final ContentIoOperation operation;
  final bool declaredByFormat;
  final bool adapterAvailable;

  bool get isReady => declaredByFormat && adapterAvailable;
  bool get isPlanned => declaredByFormat && !adapterAvailable;
}

class ContentCapabilityReadiness {
  const ContentCapabilityReadiness({
    required this.format,
    required this.capability,
    required this.declaredByFormat,
    required this.providerAvailable,
  });

  final ContentFormatDescriptor format;
  final ContentFormatCapability capability;
  final bool declaredByFormat;
  final bool providerAvailable;

  bool get isReady => declaredByFormat && providerAvailable;
  bool get isPlanned => declaredByFormat && !providerAvailable;
}

class ContentExportPreflight {
  ContentExportPreflight({
    required this.readiness,
    required this.lossReport,
    required Iterable<ContentIoNotice> notices,
  }) : notices = List.unmodifiable(notices);

  final ContentOperationReadiness readiness;
  final ContentLossReport lossReport;
  final List<ContentIoNotice> notices;

  bool get canProceed =>
      readiness.isReady && !notices.any((notice) => notice.isBlocking);
  bool get requiresConfirmation => lossReport.hasLosses;
}

class ContentIoRegistry {
  ContentIoRegistry();

  final Map<ContentFormatId, ContentFormatDescriptor> _formats = {};
  final Map<ContentFormatId, ContentImporter> _importers = {};
  final Map<ContentFormatId, ContentExporter> _exporters = {};
  final Map<ContentFormatId, Map<ContentFormatCapability, ContentAdapter>>
  _capabilityProviders = {};
  final Map<ContentFormatId, ContentFidelityPolicy> _exportPolicies = {};

  List<ContentFormatDescriptor> get formats =>
      List.unmodifiable(_formats.values);

  void registerFormat(
    ContentFormatDescriptor descriptor, {
    ContentFidelityPolicy? exportPolicy,
    bool replace = false,
  }) {
    if (_formats.containsKey(descriptor.id) && !replace) {
      throw StateError('El formato ${descriptor.id.value} ya está registrado.');
    }
    _formats[descriptor.id] = descriptor;
    if (exportPolicy != null) _exportPolicies[descriptor.id] = exportPolicy;
  }

  void registerAdapter(ContentAdapter adapter, {bool replace = false}) {
    final format = _formats[adapter.formatId];
    if (format == null) {
      throw StateError(
        'Registra primero el formato ${adapter.formatId.value}.',
      );
    }

    final provided = <ContentFormatCapability>{};
    if (adapter is ContentImporter) {
      provided.add(ContentFormatCapability.importContent);
    }
    if (adapter is ContentExporter) {
      provided.add(ContentFormatCapability.exportContent);
    }
    if (adapter is ContentCapabilityProvider) {
      if (adapter.providedCapabilities.contains(
            ContentFormatCapability.importContent,
          ) ||
          adapter.providedCapabilities.contains(
            ContentFormatCapability.exportContent,
          )) {
        throw ArgumentError(
          'Importar y exportar deben declararse mediante ContentImporter o '
          'ContentExporter.',
        );
      }
      provided.addAll(adapter.providedCapabilities);
    }
    if (provided.isEmpty) {
      throw ArgumentError('El adaptador no proporciona ninguna capacidad.');
    }

    final undeclared = provided.difference(format.capabilities);
    if (undeclared.isNotEmpty) {
      throw StateError(
        'El formato ${format.id.value} no declara: '
        '${undeclared.map((value) => value.name).join(', ')}.',
      );
    }
    final providers = _capabilityProviders[adapter.formatId];
    final collisions = provided.where(
      (capability) => providers?.containsKey(capability) ?? false,
    );
    if (collisions.isNotEmpty && !replace) {
      throw StateError(
        'Ya existe un adaptador para ${adapter.formatId.value}: '
        '${collisions.map((value) => value.name).join(', ')}.',
      );
    }

    // Mutation happens only after all validations, so a failed registration
    // cannot leave import and export maps partially updated.
    final targetProviders = _capabilityProviders.putIfAbsent(
      adapter.formatId,
      () => {},
    );
    for (final capability in provided) {
      targetProviders[capability] = adapter;
    }
    if (adapter is ContentImporter) _importers[adapter.formatId] = adapter;
    if (adapter is ContentExporter) _exporters[adapter.formatId] = adapter;
  }

  ContentFormatDescriptor? formatById(ContentFormatId id) => _formats[id];
  ContentImporter? importerFor(ContentFormatId id) => _importers[id];
  ContentExporter? exporterFor(ContentFormatId id) => _exporters[id];
  ContentAdapter? providerFor(
    ContentFormatId id,
    ContentFormatCapability capability,
  ) => _capabilityProviders[id]?[capability];

  ContentCapabilityReadiness capabilityReadiness(
    ContentFormatId id,
    ContentFormatCapability capability,
  ) {
    final format = _formats[id];
    if (format == null) {
      throw StateError('El formato ${id.value} no está registrado.');
    }
    return ContentCapabilityReadiness(
      format: format,
      capability: capability,
      declaredByFormat: format.supports(capability),
      providerAvailable:
          _capabilityProviders[id]?.containsKey(capability) ?? false,
    );
  }

  ContentOperationReadiness readiness(
    ContentFormatId id,
    ContentIoOperation operation,
  ) {
    final format = _formats[id];
    if (format == null) {
      throw StateError('El formato ${id.value} no está registrado.');
    }
    final declared = switch (operation) {
      ContentIoOperation.importContent => format.supports(
        ContentFormatCapability.importContent,
      ),
      ContentIoOperation.exportContent => format.supports(
        ContentFormatCapability.exportContent,
      ),
    };
    final available = switch (operation) {
      ContentIoOperation.importContent => _importers.containsKey(id),
      ContentIoOperation.exportContent => _exporters.containsKey(id),
    };
    return ContentOperationReadiness(
      format: format,
      operation: operation,
      declaredByFormat: declared,
      adapterAvailable: available,
    );
  }

  ContentFormatDetection detect({String? fileName, String? mimeType}) {
    final extension = extensionFromFileName(fileName);
    final byExtension = extension == null
        ? <ContentFormatDescriptor>[]
        : _formats.values
              .where((format) => format.matchesExtension(extension))
              .toList(growable: false);
    final byMime = mimeType == null || normalizeMimeType(mimeType).isEmpty
        ? <ContentFormatDescriptor>[]
        : _formats.values
              .where((format) => format.matchesMimeType(mimeType))
              .toList(growable: false);

    if (byExtension.isNotEmpty && byMime.isNotEmpty) {
      final agreement = byExtension
          .where((format) => byMime.any((other) => other.id == format.id))
          .toList(growable: false);
      if (agreement.length == 1) {
        return ContentFormatDetection(
          selected: agreement.single,
          candidates: agreement,
          confidence: ContentDetectionConfidence.high,
        );
      }
      final candidates = <ContentFormatDescriptor>[
        ...byMime,
        ...byExtension.where(
          (format) => !byMime.any((other) => other.id == format.id),
        ),
      ];
      return ContentFormatDetection(
        selected: null,
        candidates: candidates,
        confidence: ContentDetectionConfidence.ambiguous,
        notices: const [
          ContentIoNotice(
            code: 'detection.mime_extension_conflict',
            message:
                'La extensión y el tipo MIME identifican formatos diferentes.',
            severity: ContentIoNoticeSeverity.warning,
            operation: ContentIoOperation.importContent,
          ),
        ],
      );
    }

    final candidates = byMime.isNotEmpty ? byMime : byExtension;
    if (candidates.length == 1) {
      return ContentFormatDetection(
        selected: candidates.single,
        candidates: candidates,
        confidence: ContentDetectionConfidence.medium,
      );
    }
    if (candidates.length > 1) {
      return ContentFormatDetection(
        selected: null,
        candidates: candidates,
        confidence: ContentDetectionConfidence.ambiguous,
      );
    }
    return ContentFormatDetection(
      selected: _formats[const ContentFormatId('unknown')],
      candidates: const [],
      confidence: ContentDetectionConfidence.low,
    );
  }

  ContentExportPreflight preflightExport({
    required ContentFormatId targetFormat,
    required ContentFeatureManifest sourceFeatures,
  }) {
    final ready = readiness(targetFormat, ContentIoOperation.exportContent);
    final policy =
        _exportPolicies[targetFormat] ??
        ContentFidelityPolicy(defaultPreservation: ContentPreservation.unknown);
    final report = policy.evaluate(
      source: sourceFeatures,
      target: ready.format,
    );
    final notices = <ContentIoNotice>[
      if (!ready.declaredByFormat)
        ContentIoNotice(
          code: 'export.not_supported',
          message: '${ready.format.canonicalName} no admite exportación.',
          severity: ContentIoNoticeSeverity.error,
          operation: ContentIoOperation.exportContent,
        )
      else if (!ready.adapterAvailable)
        ContentIoNotice(
          code: 'export.adapter_unavailable',
          message:
              'La exportación a ${ready.format.canonicalName} aún no está '
              'instalada.',
          severity: ContentIoNoticeSeverity.error,
          operation: ContentIoOperation.exportContent,
        ),
      ...report.changes.map(
        (change) => ContentIoNotice.fromFeatureChange(
          change: change,
          target: ready.format,
        ),
      ),
    ];
    return ContentExportPreflight(
      readiness: ready,
      lossReport: report,
      notices: notices,
    );
  }
}
