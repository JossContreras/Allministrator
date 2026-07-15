enum ContentFormatFamily {
  native,
  pagedDocument,
  text,
  image,
  video,
  sourceCode,
  unknown,
}

enum ContentFormatCapability {
  importContent,
  exportContent,
  preview,
  edit,
  annotate,
  extractText,
  preserveOriginal,
  playMedia,
}

enum ContentOpenMode {
  nativeEditor,
  convertedWorkspace,
  annotationEditor,
  previewOnly,
  externalViewer,
}

/// Stable, persistence-safe identifier for a content format.
///
/// It is deliberately a value object instead of an enum so plugins can add
/// formats without changing the core package or a database schema.
final class ContentFormatId {
  const ContentFormatId(this.value) : assert(value != '');

  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentFormatId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

class ContentFormatDescriptor {
  ContentFormatDescriptor({
    required this.id,
    required this.canonicalName,
    required this.family,
    required Iterable<String> extensions,
    required Iterable<String> mimeTypes,
    required Iterable<ContentFormatCapability> capabilities,
    required this.defaultOpenMode,
    required this.visualIdentity,
    this.preferredExtension,
  }) : extensions = Set.unmodifiable(
         extensions.map(normalizeExtension).where((value) => value.isNotEmpty),
       ),
       mimeTypes = Set.unmodifiable(
         mimeTypes.map(normalizeMimeType).where((value) => value.isNotEmpty),
       ),
       capabilities = Set.unmodifiable(capabilities) {
    if (preferredExtension != null &&
        !this.extensions.contains(normalizeExtension(preferredExtension!))) {
      throw ArgumentError.value(
        preferredExtension,
        'preferredExtension',
        'Debe estar incluida en extensions.',
      );
    }
  }

  final ContentFormatId id;
  final String canonicalName;
  final ContentFormatFamily family;
  final Set<String> extensions;
  final Set<String> mimeTypes;
  final Set<ContentFormatCapability> capabilities;
  final ContentOpenMode defaultOpenMode;

  /// Stable semantic token for the presentation layer (for example `pdf`).
  /// UI colors and icons remain outside the domain.
  final String visualIdentity;
  final String? preferredExtension;

  bool supports(ContentFormatCapability capability) =>
      capabilities.contains(capability);

  bool matchesExtension(String extension) =>
      extensions.contains(normalizeExtension(extension));

  bool matchesMimeType(String mimeType) {
    final normalized = normalizeMimeType(mimeType);
    if (normalized.isEmpty) return false;
    return mimeTypes.any((pattern) => _mimePatternMatches(pattern, normalized));
  }
}

String normalizeExtension(String value) {
  var normalized = value.trim().toLowerCase();
  while (normalized.startsWith('.')) {
    normalized = normalized.substring(1);
  }
  return normalized;
}

String normalizeMimeType(String value) =>
    value.split(';').first.trim().toLowerCase();

String? extensionFromFileName(String? fileName) {
  if (fileName == null || fileName.trim().isEmpty) return null;
  final normalized = fileName.replaceAll('\\', '/').split('/').last;
  final dot = normalized.lastIndexOf('.');
  if (dot <= 0 || dot == normalized.length - 1) return null;
  return normalizeExtension(normalized.substring(dot + 1));
}

bool _mimePatternMatches(String pattern, String mimeType) {
  if (pattern == mimeType || pattern == '*/*') return true;
  final wildcard = pattern.indexOf('*');
  if (wildcard < 0) return false;
  final prefix = pattern.substring(0, wildcard);
  final suffix = pattern.substring(wildcard + 1);
  return mimeType.startsWith(prefix) && mimeType.endsWith(suffix);
}
