import 'structured_document.dart';

/// JSON versionado del cuerpo editable. Mantiene compatibilidad con payloads
/// antiguos mientras expone un documento estructurado al editor.
class DocumentContent {
  const DocumentContent({required this.schemaVersion, required this.data});
  const DocumentContent.empty() : schemaVersion = 2, data = const {'nodes': []};
  final int schemaVersion;
  final Map<String, Object?> data;

  factory DocumentContent.fromJson(Map<String, Object?> json) {
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    final raw =
        json['data'] is Map
              ? Map<String, Object?>.from(json['data'] as Map)
              : {...json}
          ..remove('schemaVersion');
    if (version < 2) {
      return DocumentContent(
        schemaVersion: 2,
        data: StructuredDocument.fromJson(raw).toJson()
          ..remove('schemaVersion'),
      );
    }
    return DocumentContent(schemaVersion: version, data: raw);
  }

  Map<String, Object?> toJson() => {'schemaVersion': schemaVersion, ...data};
  StructuredDocument get structured =>
      StructuredDocument.fromJson({'schemaVersion': schemaVersion, ...data});
  String get text => structured.plainText;
  DocumentContent withStructured(StructuredDocument value) => DocumentContent(
    schemaVersion: 2,
    data: value.toJson()..remove('schemaVersion'),
  );
  DocumentContent withText(String value) =>
      withStructured(StructuredDocument.fromPlainText(value));
  DocumentContent withTextAndSoftBreaks(String value, Set<int> offsets) =>
      withStructured(
        StructuredDocument.fromPlainTextWithSoftBreaks(value, offsets),
      );
}
