import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/core/utils/uuid_generator.dart';

enum DocumentAffinity { upstream, downstream }

class ParagraphAttributes {
  const ParagraphAttributes({
    this.alignment = 'left',
    this.indent = 0,
    this.lineSpacing = 1,
    this.listType,
  });
  final String alignment;
  final int indent;
  final double lineSpacing;
  final String? listType;
  factory ParagraphAttributes.fromJson(Object? value) {
    final map = value is Map
        ? Map<String, Object?>.from(value)
        : const <String, Object?>{};
    return ParagraphAttributes(
      alignment: map['alignment'] as String? ?? 'left',
      indent: (map['indent'] as num?)?.toInt() ?? 0,
      lineSpacing: (map['lineSpacing'] as num?)?.toDouble() ?? 1,
      listType: map['listType'] as String?,
    );
  }
  Map<String, Object?> toJson() => {
    'alignment': alignment,
    'indent': indent,
    'lineSpacing': lineSpacing,
    'listType': listType,
  };
}

class TextSpanMark {
  const TextSpanMark({
    required this.start,
    required this.end,
    this.attributes = const {},
  });
  final int start, end;
  final Map<String, Object?> attributes;
  TextSpanMark copyWith({
    int? start,
    int? end,
    Map<String, Object?>? attributes,
  }) => TextSpanMark(
    start: start ?? this.start,
    end: end ?? this.end,
    attributes: attributes ?? this.attributes,
  );
  Map<String, Object?> toJson() => {
    'start': start,
    'end': end,
    'attributes': attributes,
  };
  factory TextSpanMark.fromJson(Object? value) {
    final map = value is Map
        ? Map<String, Object?>.from(value)
        : const <String, Object?>{};
    return TextSpanMark(
      start: (map['start'] as num?)?.toInt() ?? 0,
      end: (map['end'] as num?)?.toInt() ?? 0,
      attributes: map['attributes'] is Map
          ? Map<String, Object?>.from(map['attributes'] as Map)
          : const {},
    );
  }
}

sealed class DocumentNode {
  const DocumentNode({required this.id, required this.metadata});
  final Uuid id;
  final Map<String, Object?>? metadata;
  String get type;
  Map<String, Object?> toJson();
  factory DocumentNode.fromJson(Object? value) {
    final map = value is Map
        ? Map<String, Object?>.from(value)
        : const <String, Object?>{};
    if (map['type'] == 'paragraph') return ParagraphNode.fromJson(map);
    return ParagraphNode(
      id: map['id'] as String? ?? generateUuid(),
      text: '',
      metadata: map['metadata'] is Map
          ? Map<String, Object?>.from(map['metadata'] as Map)
          : null,
    );
  }
}

class ParagraphNode extends DocumentNode {
  const ParagraphNode({
    required super.id,
    required this.text,
    this.attributes = const ParagraphAttributes(),
    this.spans = const [],
    super.metadata,
  });
  final String text;
  final ParagraphAttributes attributes;
  final List<TextSpanMark> spans;
  @override
  String get type => 'paragraph';
  ParagraphNode copyWith({
    String? id,
    String? text,
    ParagraphAttributes? attributes,
    List<TextSpanMark>? spans,
    Map<String, Object?>? metadata,
  }) => ParagraphNode(
    id: id ?? this.id,
    text: text ?? this.text,
    attributes: attributes ?? this.attributes,
    spans: spans ?? this.spans,
    metadata: metadata ?? this.metadata,
  );
  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'text': text,
    'attributes': attributes.toJson(),
    'spans': spans.map((span) => span.toJson()).toList(growable: false),
    'metadata': metadata ?? const {},
  };
  factory ParagraphNode.fromJson(Map<String, Object?> map) => ParagraphNode(
    id: map['id'] as String? ?? generateUuid(),
    text: map['text'] as String? ?? '',
    attributes: ParagraphAttributes.fromJson(map['attributes']),
    spans: (map['spans'] is List
        ? (map['spans'] as List).map(TextSpanMark.fromJson).toList()
        : const []),
    metadata: map['metadata'] is Map
        ? Map<String, Object?>.from(map['metadata'] as Map)
        : null,
  );
}

class StructuredDocument {
  const StructuredDocument({
    this.schemaVersion = 2,
    required this.nodes,
    this.metadata,
  });
  final int schemaVersion;
  final List<DocumentNode> nodes;
  final Map<String, Object?>? metadata;
  factory StructuredDocument.empty() => StructuredDocument(
    nodes: [ParagraphNode(id: generateUuid(), text: '')],
  );
  factory StructuredDocument.fromPlainText(String text) => StructuredDocument(
    nodes: text
        .split('\n')
        .map((line) => ParagraphNode(id: generateUuid(), text: line))
        .toList(),
  );
  factory StructuredDocument.fromPlainTextWithSoftBreaks(
    String text,
    Set<int> softBreakOffsets,
  ) {
    final paragraphs = <ParagraphNode>[];
    final buffer = StringBuffer();
    for (var index = 0; index < text.length; index++) {
      final character = text[index];
      if (character == '\n' && !softBreakOffsets.contains(index)) {
        paragraphs.add(
          ParagraphNode(id: generateUuid(), text: buffer.toString()),
        );
        buffer.clear();
      } else {
        buffer.write(character);
      }
    }
    paragraphs.add(ParagraphNode(id: generateUuid(), text: buffer.toString()));
    return StructuredDocument(nodes: paragraphs);
  }

  StructuredDocument reconcileText(String text, Set<int> softBreakOffsets) {
    final next = StructuredDocument.fromPlainTextWithSoftBreaks(
      text,
      softBreakOffsets,
    );
    final existing = nodes.whereType<ParagraphNode>().toList();
    final reused = <ParagraphNode>[];
    for (var index = 0; index < next.nodes.length; index++) {
      final paragraph = next.nodes[index] as ParagraphNode;
      final previous = index < existing.length ? existing[index] : null;
      reused.add(
        paragraph.copyWith(
          id: previous?.id,
          attributes: previous?.attributes,
          metadata: previous?.metadata,
          spans: previous?.spans,
        ),
      );
    }
    return StructuredDocument(nodes: reused, metadata: metadata).normalized();
  }

  factory StructuredDocument.fromJson(Map<String, Object?> json) {
    final rawNodes = json['nodes'];
    if (rawNodes is List) {
      return StructuredDocument(
        nodes: rawNodes.map(DocumentNode.fromJson).toList(),
        metadata: json['metadata'] is Map
            ? Map<String, Object?>.from(json['metadata'] as Map)
            : null,
      ).normalized();
    }
    final legacy =
        json['text'] as String? ??
        (json['data'] is Map
            ? ((json['data'] as Map)['text'] as String? ?? '')
            : '');
    return StructuredDocument.fromPlainText(legacy);
  }
  Map<String, Object?> toJson() => {
    'schemaVersion': 2,
    'nodes': nodes.map((node) => node.toJson()).toList(growable: false),
    'metadata': metadata ?? const {},
  };
  String get plainText =>
      nodes.whereType<ParagraphNode>().map((node) => node.text).join('\n');
  StructuredDocument normalized() {
    final paragraphs = nodes.whereType<ParagraphNode>().toList();
    if (paragraphs.isEmpty) return StructuredDocument.empty();
    final used = <String>{};
    final safe = paragraphs.map((node) {
      var id = node.id;
      if (id.isEmpty || !used.add(id)) {
        do {
          id = generateUuid();
        } while (!used.add(id));
      }
      final spans =
          node.spans
              .where(
                (span) =>
                    span.start < span.end &&
                    span.start >= 0 &&
                    span.end <= node.text.length,
              )
              .map((span) => span.copyWith())
              .toList()
            ..sort((a, b) => a.start.compareTo(b.start));
      return node.copyWith(id: id, spans: spans);
    }).toList();
    return StructuredDocument(nodes: safe, metadata: metadata);
  }
}

class DocumentPosition {
  const DocumentPosition({
    required this.nodeId,
    required this.offset,
    this.affinity = DocumentAffinity.downstream,
  });
  final Uuid nodeId;
  final int offset;
  final DocumentAffinity affinity;
  Map<String, Object?> toJson() => {
    'nodeId': nodeId,
    'offset': offset,
    'affinity': affinity.name,
  };
}

class DocumentSelection {
  const DocumentSelection({required this.anchor, required this.focus});
  final DocumentPosition anchor, focus;
  bool get isCollapsed =>
      anchor.nodeId == focus.nodeId && anchor.offset == focus.offset;
  factory DocumentSelection.collapsed(DocumentPosition position) =>
      DocumentSelection(anchor: position, focus: position);
}

class EditingResult {
  const EditingResult(this.document, this.selection);
  final StructuredDocument document;
  final DocumentSelection selection;
}

class DocumentEditingEngine {
  DocumentEditingEngine(this.document, {DocumentSelection? selection})
    : selection =
          selection ??
          DocumentSelection.collapsed(
            DocumentPosition(
              nodeId: document.normalized().nodes.first.id,
              offset: 0,
            ),
          );
  StructuredDocument document;
  DocumentSelection selection;

  EditingResult setSelection(DocumentSelection value) {
    selection = value;
    return EditingResult(document, selection);
  }

  EditingResult backspace() {
    if (!selection.isCollapsed) return deleteRange(selection);
    final position = _position(selection.anchor);
    if (position.offset > 0) {
      return deleteRange(
        DocumentSelection(
          anchor: DocumentPosition(
            nodeId: selection.anchor.nodeId,
            offset: position.offset - 1,
          ),
          focus: selection.anchor,
        ),
      );
    }
    return position.index > 0
        ? mergeParagraphs(position.index - 1)
        : EditingResult(document, selection);
  }

  EditingResult deleteForward() {
    if (!selection.isCollapsed) return deleteRange(selection);
    final position = _position(selection.anchor);
    final node = _paragraph(position.index);
    if (position.offset < node.text.length) {
      return deleteRange(
        DocumentSelection(
          anchor: selection.anchor,
          focus: DocumentPosition(
            nodeId: selection.anchor.nodeId,
            offset: position.offset + 1,
          ),
        ),
      );
    }
    return position.index < document.nodes.length - 1
        ? mergeParagraphs(position.index)
        : EditingResult(document, selection);
  }

  EditingResult insertText(String value) => replaceSelection(value);
  EditingResult replaceSelection(String value) {
    if (!selection.isCollapsed) deleteRange(selection);
    final position = _position(selection.anchor);
    final node = _paragraph(position.index);
    final offset = position.offset.clamp(0, node.text.length);
    final parts = value.split('\n');
    if (parts.length == 1) {
      final updated = node.copyWith(
        text:
            '${node.text.substring(0, offset)}$value${node.text.substring(offset)}',
        spans: _shiftSpans(node.spans, offset, value.length),
      );
      _replaceNode(position.index, updated);
      selection = DocumentSelection.collapsed(
        DocumentPosition(nodeId: node.id, offset: offset + value.length),
      );
    } else {
      final prefix = node.text.substring(0, offset);
      final suffix = node.text.substring(offset);
      final inserted = <ParagraphNode>[];
      for (var partIndex = 0; partIndex < parts.length; partIndex++) {
        final part = partIndex == 0
            ? '$prefix${parts[partIndex]}'
            : partIndex == parts.length - 1
            ? '${parts[partIndex]}$suffix'
            : parts[partIndex];
        inserted.add(
          ParagraphNode(
            id: partIndex == 0 ? node.id : generateUuid(),
            text: part,
            attributes: node.attributes,
          ),
        );
      }
      final list = [...document.nodes]
        ..replaceRange(position.index, position.index + 1, inserted);
      document = StructuredDocument(nodes: list, metadata: document.metadata);
      final cursor = position.index + inserted.length - 1;
      selection = DocumentSelection.collapsed(
        DocumentPosition(
          nodeId: _paragraph(cursor).id,
          offset: _paragraph(cursor).text.length,
        ),
      );
    }
    document = document.normalized();
    return EditingResult(document, selection);
  }

  EditingResult splitParagraph(int offset) {
    final position = _position(selection.anchor);
    final node = _paragraph(position.index);
    final safe = offset.clamp(0, node.text.length);
    final left = node.copyWith(text: node.text.substring(0, safe));
    final right = ParagraphNode(
      id: generateUuid(),
      text: node.text.substring(safe),
      attributes: node.attributes,
    );
    final list = [...document.nodes]
      ..replaceRange(position.index, position.index + 1, [left, right]);
    document = StructuredDocument(
      nodes: list,
      metadata: document.metadata,
    ).normalized();
    selection = DocumentSelection.collapsed(
      DocumentPosition(nodeId: right.id, offset: 0),
    );
    return EditingResult(document, selection);
  }

  EditingResult mergeParagraphs(int index) {
    if (index < 0 || index >= document.nodes.length - 1) {
      return EditingResult(document, selection);
    }
    final first = _paragraph(index), second = _paragraph(index + 1);
    final merged = first.copyWith(
      text: first.text + second.text,
      spans: [
        ...first.spans,
        ...second.spans.map(
          (span) => span.copyWith(
            start: span.start + first.text.length,
            end: span.end + first.text.length,
          ),
        ),
      ],
    );
    final list = [...document.nodes]..replaceRange(index, index + 2, [merged]);
    document = StructuredDocument(
      nodes: list,
      metadata: document.metadata,
    ).normalized();
    selection = DocumentSelection.collapsed(
      DocumentPosition(nodeId: merged.id, offset: first.text.length),
    );
    return EditingResult(document, selection);
  }

  EditingResult deleteRange(DocumentSelection range) {
    final a = _position(range.anchor), b = _position(range.focus);
    final anchorFirst =
        a.index < b.index || (a.index == b.index && a.offset <= b.offset);
    final start = anchorFirst ? a : b;
    final end = anchorFirst ? b : a;
    if (start.index == end.index) {
      final node = _paragraph(start.index);
      _replaceNode(
        start.index,
        node.copyWith(
          text:
              node.text.substring(0, start.offset) +
              node.text.substring(end.offset),
          spans: _deleteSpans(node.spans, start.offset, end.offset),
        ),
      );
    } else {
      final first = _paragraph(start.index), last = _paragraph(end.index);
      final merged = first.copyWith(
        text:
            first.text.substring(0, start.offset) +
            last.text.substring(end.offset),
      );
      final list = [...document.nodes]
        ..replaceRange(start.index, end.index + 1, [merged]);
      document = StructuredDocument(nodes: list, metadata: document.metadata);
    }
    document = document.normalized();
    selection = DocumentSelection.collapsed(
      DocumentPosition(
        nodeId: _paragraph(start.index).id,
        offset: start.offset,
      ),
    );
    return EditingResult(document, selection);
  }

  StructuredDocument normalizeDocument() {
    document = document.normalized();
    return document;
  }

  ({int index, int offset}) _position(DocumentPosition position) {
    final index = document.nodes.indexWhere(
      (node) => node.id == position.nodeId,
    );
    return (index: index < 0 ? 0 : index, offset: position.offset);
  }

  ParagraphNode _paragraph(int index) =>
      document.nodes[index.clamp(0, document.nodes.length - 1)]
          as ParagraphNode;
  void _replaceNode(int index, ParagraphNode node) {
    final list = [...document.nodes]..[index] = node;
    document = StructuredDocument(nodes: list, metadata: document.metadata);
  }

  List<TextSpanMark> _shiftSpans(
    List<TextSpanMark> spans,
    int at,
    int amount,
  ) => spans
      .map(
        (span) => span.start >= at
            ? span.copyWith(start: span.start + amount, end: span.end + amount)
            : span.end > at
            ? span.copyWith(end: span.end + amount)
            : span,
      )
      .toList();
  List<TextSpanMark> _deleteSpans(
    List<TextSpanMark> spans,
    int start,
    int end,
  ) => spans
      .map((span) {
        final shift = end - start;
        if (span.end <= start) return span;
        if (span.start >= end) {
          return span.copyWith(
            start: span.start - shift,
            end: span.end - shift,
          );
        }
        return span.copyWith(
          start: span.start.clamp(0, start),
          end: span.end.clamp(0, start),
        );
      })
      .where((span) => span.start < span.end)
      .toList();
}
