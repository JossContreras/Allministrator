import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/core/utils/uuid_generator.dart';

enum DocumentAffinity { upstream, downstream }

enum DocumentNodeType {
  paragraph,
  image,
  divider,
  checklist,
  quote,
  callout,
  code,
  codeBlock,
  table,
  attachment,
  audio,
  video,
  drawing,
}

enum ChecklistStyle { checkbox, task, compact }

enum QuoteStyle { standard, large, pullQuote }

enum CalloutType { info, tip, warning, success, error, note }

class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.text,
    this.isChecked = false,
    this.indentLevel = 0,
    this.spans = const [],
    this.metadata,
  });
  final Uuid id;
  final String text;
  final bool isChecked;
  final int indentLevel;
  final List<TextSpanMark> spans;
  final Map<String, Object?>? metadata;
  ChecklistItem copyWith({
    String? text,
    bool? isChecked,
    int? indentLevel,
    List<TextSpanMark>? spans,
    Map<String, Object?>? metadata,
  }) => ChecklistItem(
    id: id,
    text: text ?? this.text,
    isChecked: isChecked ?? this.isChecked,
    indentLevel: (indentLevel ?? this.indentLevel).clamp(0, 6),
    spans: spans ?? this.spans,
    metadata: metadata ?? this.metadata,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'isChecked': isChecked,
    'indentLevel': indentLevel,
    'spans': spans.map((e) => e.toJson()).toList(growable: false),
    'metadata': metadata ?? const <String, Object?>{},
  };
  factory ChecklistItem.fromJson(Object? value) {
    final m = value is Map
        ? Map<String, Object?>.from(value)
        : const <String, Object?>{};
    return ChecklistItem(
      id: m['id'] as String? ?? generateUuid(),
      text: m['text'] as String? ?? '',
      isChecked: m['isChecked'] as bool? ?? false,
      indentLevel: ((m['indentLevel'] as num?)?.toInt() ?? 0).clamp(0, 6),
      spans: m['spans'] is List
          ? (m['spans'] as List).map(TextSpanMark.fromJson).toList()
          : const [],
      metadata: m['metadata'] is Map
          ? Map<String, Object?>.from(m['metadata'] as Map)
          : null,
    );
  }
}

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

  bool covers(int position) => start <= position && position < end;
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
    if (map['type'] == 'image') {
      return ImageNode.fromJson(map);
    }
    if (map['type'] == 'divider') {
      return DividerNode.fromJson(map);
    }
    if (map['type'] == 'checklist') {
      return ChecklistNode.fromJson(map);
    }
    if (map['type'] == 'quote') {
      return QuoteNode.fromJson(map);
    }
    if (map['type'] == 'callout') {
      return CalloutNode.fromJson(map);
    }
    if (map['type'] == 'code' || map['type'] == 'codeBlock') {
      return CodeBlockNode.fromJson(map);
    }
    return UnknownNode(
      id: map['id'] as String? ?? generateUuid(),
      unknownType: map['type'] as String? ?? 'unknown',
      raw: map,
    );
  }
}

enum NodeAlignment { left, center, right }

class ImageNode extends DocumentNode {
  const ImageNode({
    required super.id,
    required this.attachmentId,
    this.altText,
    this.caption,
    this.alignment = NodeAlignment.center,
    this.displayWidth,
    this.aspectRatio,
    this.originalWidth,
    this.originalHeight,
    this.createdAt,
    super.metadata,
  });
  final String attachmentId;
  final String? altText, caption;
  final NodeAlignment alignment;
  final double? displayWidth, aspectRatio;
  final int? originalWidth, originalHeight;
  final DateTime? createdAt;
  @override
  String get type => DocumentNodeType.image.name;
  ImageNode copyWith({
    String? attachmentId,
    String? altText,
    String? caption,
    NodeAlignment? alignment,
    double? displayWidth,
    double? aspectRatio,
    int? originalWidth,
    int? originalHeight,
    Map<String, Object?>? metadata,
  }) => ImageNode(
    id: id,
    attachmentId: attachmentId ?? this.attachmentId,
    altText: altText ?? this.altText,
    caption: caption ?? this.caption,
    alignment: alignment ?? this.alignment,
    displayWidth: displayWidth ?? this.displayWidth,
    aspectRatio: aspectRatio ?? this.aspectRatio,
    originalWidth: originalWidth ?? this.originalWidth,
    originalHeight: originalHeight ?? this.originalHeight,
    createdAt: createdAt,
    metadata: metadata ?? this.metadata,
  );
  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'attachmentId': attachmentId,
    'altText': altText,
    'caption': caption,
    'alignment': alignment.name,
    'displayWidth': displayWidth,
    'aspectRatio': aspectRatio,
    'originalWidth': originalWidth,
    'originalHeight': originalHeight,
    'createdAt': createdAt?.toIso8601String(),
    'metadata': metadata ?? const {},
  };
  factory ImageNode.fromJson(Map<String, Object?> map) => ImageNode(
    id: map['id'] as String? ?? generateUuid(),
    attachmentId: map['attachmentId'] as String? ?? '',
    altText: map['altText'] as String?,
    caption: map['caption'] as String?,
    alignment: NodeAlignment.values.firstWhere(
      (value) => value.name == map['alignment'],
      orElse: () => NodeAlignment.center,
    ),
    displayWidth: (map['displayWidth'] as num?)?.toDouble(),
    aspectRatio: (map['aspectRatio'] as num?)?.toDouble(),
    originalWidth: (map['originalWidth'] as num?)?.toInt(),
    originalHeight: (map['originalHeight'] as num?)?.toInt(),
    createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
    metadata: map['metadata'] is Map
        ? Map<String, Object?>.from(map['metadata'] as Map)
        : null,
  );
}

class DividerNode extends DocumentNode {
  const DividerNode({
    required super.id,
    this.style = 'solid',
    this.thickness = 1,
    this.widthFactor = 1,
    this.alignment = NodeAlignment.center,
    super.metadata,
  });
  final String style;
  final double thickness, widthFactor;
  final NodeAlignment alignment;
  @override
  String get type => DocumentNodeType.divider.name;
  DividerNode copyWith({
    String? style,
    double? thickness,
    double? widthFactor,
    NodeAlignment? alignment,
  }) => DividerNode(
    id: id,
    style: style ?? this.style,
    thickness: thickness ?? this.thickness,
    widthFactor: widthFactor ?? this.widthFactor,
    alignment: alignment ?? this.alignment,
    metadata: metadata,
  );
  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'style': style,
    'thickness': thickness,
    'widthFactor': widthFactor,
    'alignment': alignment.name,
    'metadata': metadata ?? const {},
  };
  factory DividerNode.fromJson(Map<String, Object?> map) => DividerNode(
    id: map['id'] as String? ?? generateUuid(),
    style: map['style'] as String? ?? 'solid',
    thickness: (map['thickness'] as num?)?.toDouble() ?? 1,
    widthFactor: (map['widthFactor'] as num?)?.toDouble() ?? 1,
    alignment: NodeAlignment.values.firstWhere(
      (value) => value.name == map['alignment'],
      orElse: () => NodeAlignment.center,
    ),
    metadata: map['metadata'] is Map
        ? Map<String, Object?>.from(map['metadata'] as Map)
        : null,
  );
}

class ChecklistNode extends DocumentNode {
  const ChecklistNode({
    required super.id,
    this.items = const [],
    this.style = ChecklistStyle.checkbox,
    super.metadata,
  });
  final List<ChecklistItem> items;
  final ChecklistStyle style;
  @override
  String get type => DocumentNodeType.checklist.name;
  ChecklistNode copyWith({List<ChecklistItem>? items, ChecklistStyle? style}) =>
      ChecklistNode(
        id: id,
        items: items ?? this.items,
        style: style ?? this.style,
        metadata: metadata,
      );
  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'items': items.map((e) => e.toJson()).toList(growable: false),
    'style': style.name,
    'metadata': metadata ?? const <String, Object?>{},
  };
  factory ChecklistNode.fromJson(Map<String, Object?> m) => ChecklistNode(
    id: m['id'] as String? ?? generateUuid(),
    items: m['items'] is List && (m['items'] as List).isNotEmpty
        ? (m['items'] as List).map(ChecklistItem.fromJson).toList()
        : [ChecklistItem(id: generateUuid(), text: '')],
    style: ChecklistStyle.values.firstWhere(
      (e) => e.name == m['style'],
      orElse: () => ChecklistStyle.checkbox,
    ),
    metadata: m['metadata'] is Map
        ? Map<String, Object?>.from(m['metadata'] as Map)
        : null,
  );
}

class QuoteNode extends DocumentNode {
  const QuoteNode({
    required super.id,
    this.text = '',
    this.spans = const [],
    this.citation,
    this.style = QuoteStyle.standard,
    super.metadata,
  });
  final String text;
  final List<TextSpanMark> spans;
  final String? citation;
  final QuoteStyle style;
  @override
  String get type => DocumentNodeType.quote.name;
  QuoteNode copyWith({
    String? text,
    List<TextSpanMark>? spans,
    String? citation,
    QuoteStyle? style,
  }) => QuoteNode(
    id: id,
    text: text ?? this.text,
    spans: spans ?? this.spans,
    citation: citation ?? this.citation,
    style: style ?? this.style,
    metadata: metadata,
  );
  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'text': text,
    'spans': spans.map((e) => e.toJson()).toList(growable: false),
    'citation': citation,
    'style': style.name,
    'metadata': metadata ?? const <String, Object?>{},
  };
  factory QuoteNode.fromJson(Map<String, Object?> m) => QuoteNode(
    id: m['id'] as String? ?? generateUuid(),
    text: m['text'] as String? ?? '',
    spans: m['spans'] is List
        ? (m['spans'] as List).map(TextSpanMark.fromJson).toList()
        : const [],
    citation: m['citation'] as String?,
    style: QuoteStyle.values.firstWhere(
      (e) => e.name == m['style'],
      orElse: () => QuoteStyle.standard,
    ),
    metadata: m['metadata'] is Map
        ? Map<String, Object?>.from(m['metadata'] as Map)
        : null,
  );
}

class CalloutNode extends DocumentNode {
  const CalloutNode({
    required super.id,
    this.title,
    this.text = '',
    this.spans = const [],
    this.calloutType = CalloutType.info,
    this.iconId,
    this.colorId,
    super.metadata,
  });
  final String? title;
  final String text;
  final List<TextSpanMark> spans;
  final CalloutType calloutType;
  final String? iconId;
  final String? colorId;
  @override
  String get type => DocumentNodeType.callout.name;
  CalloutNode copyWith({
    String? title,
    String? text,
    List<TextSpanMark>? spans,
    CalloutType? calloutType,
    String? iconId,
    String? colorId,
  }) => CalloutNode(
    id: id,
    title: title ?? this.title,
    text: text ?? this.text,
    spans: spans ?? this.spans,
    calloutType: calloutType ?? this.calloutType,
    iconId: iconId ?? this.iconId,
    colorId: colorId ?? this.colorId,
    metadata: metadata,
  );
  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'text': text,
    'spans': spans.map((e) => e.toJson()).toList(growable: false),
    'calloutType': calloutType.name,
    'iconId': iconId,
    'colorId': colorId,
    'metadata': metadata ?? const <String, Object?>{},
  };
  factory CalloutNode.fromJson(Map<String, Object?> m) => CalloutNode(
    id: m['id'] as String? ?? generateUuid(),
    title: m['title'] as String?,
    text: m['text'] as String? ?? '',
    spans: m['spans'] is List
        ? (m['spans'] as List).map(TextSpanMark.fromJson).toList()
        : const [],
    calloutType: CalloutType.values.firstWhere(
      (e) => e.name == (m['calloutType'] ?? m['typeValue']),
      orElse: () => CalloutType.info,
    ),
    iconId: m['iconId'] as String?,
    colorId: m['colorId'] as String?,
    metadata: m['metadata'] is Map
        ? Map<String, Object?>.from(m['metadata'] as Map)
        : null,
  );
}

class CodeBlockNode extends DocumentNode {
  const CodeBlockNode({
    required super.id,
    this.code = '',
    this.languageId = 'plainText',
    this.themeId,
    this.showLineNumbers = false,
    this.wrapLines = true,
    this.caption,
    super.metadata,
  });
  final String code;
  final String? languageId;
  final String? themeId;
  final bool showLineNumbers;
  final bool wrapLines;
  final String? caption;
  @override
  String get type => DocumentNodeType.codeBlock.name;
  CodeBlockNode copyWith({
    String? code,
    String? languageId,
    String? themeId,
    bool? showLineNumbers,
    bool? wrapLines,
    String? caption,
  }) => CodeBlockNode(
    id: id,
    code: code ?? this.code,
    languageId: languageId ?? this.languageId,
    themeId: themeId ?? this.themeId,
    showLineNumbers: showLineNumbers ?? this.showLineNumbers,
    wrapLines: wrapLines ?? this.wrapLines,
    caption: caption ?? this.caption,
    metadata: metadata,
  );
  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'code': code,
    'languageId': languageId,
    'themeId': themeId,
    'showLineNumbers': showLineNumbers,
    'wrapLines': wrapLines,
    'caption': caption,
    'metadata': metadata ?? const <String, Object?>{},
  };
  factory CodeBlockNode.fromJson(Map<String, Object?> m) => CodeBlockNode(
    id: m['id'] as String? ?? generateUuid(),
    code: m['code'] as String? ?? '',
    languageId: m['languageId'] as String? ?? 'plainText',
    themeId: m['themeId'] as String?,
    showLineNumbers: m['showLineNumbers'] as bool? ?? false,
    wrapLines: m['wrapLines'] as bool? ?? true,
    caption: m['caption'] as String?,
    metadata: m['metadata'] is Map
        ? Map<String, Object?>.from(m['metadata'] as Map)
        : null,
  );
}

class UnknownNode extends DocumentNode {
  const UnknownNode({
    required super.id,
    required this.unknownType,
    required this.raw,
    super.metadata,
  });
  final String unknownType;
  final Map<String, Object?> raw;
  @override
  String get type => unknownType;
  @override
  Map<String, Object?> toJson() => raw;
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
    final paragraphs = <ParagraphNode>[];
    for (var index = 0; index < next.nodes.length; index++) {
      final paragraph = next.nodes[index] as ParagraphNode;
      final previous = index < existing.length ? existing[index] : null;
      paragraphs.add(
        paragraph.copyWith(
          id: previous?.id,
          attributes: previous?.attributes,
          metadata: previous?.metadata,
          spans: previous?.spans,
        ),
      );
    }
    var paragraphIndex = 0;
    final merged = <DocumentNode>[];
    for (final node in nodes) {
      if (node is ParagraphNode && paragraphIndex < paragraphs.length) {
        merged.add(paragraphs[paragraphIndex++]);
      } else if (node is! ParagraphNode) {
        merged.add(node);
      }
    }
    while (paragraphIndex < paragraphs.length) {
      merged.add(paragraphs[paragraphIndex++]);
    }
    return StructuredDocument(nodes: merged, metadata: metadata).normalized();
  }

  StructuredDocument applyFormat(
    DocumentSelection selection,
    String attribute,
    Object? value,
  ) {
    final positions = _orderedPositions(selection);
    final updated = <DocumentNode>[];
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      if (node is! ParagraphNode) {
        updated.add(node);
        continue;
      }
      final start = index == positions.startIndex
          ? positions.startOffset
          : index > positions.startIndex
          ? 0
          : node.text.length;
      final end = index == positions.endIndex
          ? positions.endOffset
          : index < positions.endIndex
          ? node.text.length
          : 0;
      updated.add(
        start < end
            ? node.copyWith(
                spans: _formatSpans(node, start, end, attribute, value),
              )
            : node,
      );
    }
    return StructuredDocument(nodes: updated, metadata: metadata).normalized();
  }

  StructuredDocument setParagraphAttribute(
    DocumentSelection selection,
    String attribute,
    Object? value,
  ) {
    final positions = _orderedPositions(selection);
    final updated = nodes.asMap().entries.map((entry) {
      final node = entry.value;
      if (node is! ParagraphNode ||
          entry.key < positions.startIndex ||
          entry.key > positions.endIndex) {
        return node;
      }
      final current = node.attributes.toJson()..[attribute] = value;
      return node.copyWith(attributes: ParagraphAttributes.fromJson(current));
    }).toList();
    return StructuredDocument(nodes: updated, metadata: metadata).normalized();
  }

  bool formatActive(
    DocumentSelection selection,
    String attribute,
    Object? expected,
  ) {
    final positions = _orderedPositions(selection);
    var found = false;
    for (
      var index = positions.startIndex;
      index <= positions.endIndex;
      index++
    ) {
      final node = nodes[index] as ParagraphNode;
      final start = index == positions.startIndex ? positions.startOffset : 0;
      final end = index == positions.endIndex
          ? positions.endOffset
          : node.text.length;
      for (var offset = start; offset < end; offset++) {
        found = true;
        final mark = node.spans
            .where((span) => span.covers(offset))
            .fold<Object?>(
              null,
              (value, span) => span.attributes[attribute] ?? value,
            );
        if (mark != expected) return false;
      }
    }
    return found;
  }

  ({int startIndex, int startOffset, int endIndex, int endOffset})
  _orderedPositions(DocumentSelection selection) {
    var anchorIndex = nodes.indexWhere(
      (node) => node.id == selection.anchor.nodeId,
    );
    var focusIndex = nodes.indexWhere(
      (node) => node.id == selection.focus.nodeId,
    );
    if (anchorIndex < 0) anchorIndex = 0;
    if (focusIndex < 0) focusIndex = 0;
    final anchorFirst =
        anchorIndex < focusIndex ||
        (anchorIndex == focusIndex &&
            selection.anchor.offset <= selection.focus.offset);
    final start = anchorFirst ? selection.anchor : selection.focus;
    final end = anchorFirst ? selection.focus : selection.anchor;
    return (
      startIndex: anchorFirst ? anchorIndex : focusIndex,
      startOffset: start.offset,
      endIndex: anchorFirst ? focusIndex : anchorIndex,
      endOffset: end.offset,
    );
  }

  List<TextSpanMark> _formatSpans(
    ParagraphNode node,
    int start,
    int end,
    String attribute,
    Object? value,
  ) {
    final boundaries = <int>{0, node.text.length, start, end};
    for (final span in node.spans) {
      boundaries
        ..add(span.start)
        ..add(span.end);
    }
    final sorted = boundaries.toList()..sort();
    final result = <TextSpanMark>[];
    for (var index = 0; index < sorted.length - 1; index++) {
      final segmentStart = sorted[index], segmentEnd = sorted[index + 1];
      if (segmentStart == segmentEnd) continue;
      final attributes = <String, Object?>{};
      for (final span in node.spans.where(
        (span) => span.start <= segmentStart && span.end >= segmentEnd,
      )) {
        attributes.addAll(span.attributes);
      }
      if (segmentStart >= start && segmentEnd <= end) {
        if (value == null || value == false) {
          attributes.remove(attribute);
        } else {
          attributes[attribute] = value;
        }
      }
      if (attributes.isNotEmpty) {
        final previous = result.isNotEmpty ? result.last : null;
        if (previous != null &&
            _mapsEqual(previous.attributes, attributes) &&
            previous.end == segmentStart) {
          result[result.length - 1] = previous.copyWith(end: segmentEnd);
        } else {
          result.add(
            TextSpanMark(
              start: segmentStart,
              end: segmentEnd,
              attributes: attributes,
            ),
          );
        }
      }
    }
    return result;
  }

  bool _mapsEqual(Map<String, Object?> first, Map<String, Object?> second) {
    if (first.length != second.length) return false;
    for (final entry in first.entries) {
      if (second[entry.key] != entry.value) return false;
    }
    return true;
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
    final source = nodes.isEmpty
        ? <DocumentNode>[ParagraphNode(id: generateUuid(), text: '')]
        : nodes;
    final used = <String>{};
    final safe = source.map((node) {
      var id = node.id;
      if (id.isEmpty || !used.add(id)) {
        do {
          id = generateUuid();
        } while (!used.add(id));
      }
      if (node is ChecklistNode) {
        final itemIds = <String>{};
        final items = node.items.map((item) {
          var itemId = item.id;
          if (itemId.isEmpty || !itemIds.add(itemId)) {
            do {
              itemId = generateUuid();
            } while (!itemIds.add(itemId));
          }
          final spans = item.spans
              .where(
                (s) =>
                    s.start < s.end &&
                    s.start >= 0 &&
                    s.end <= item.text.length,
              )
              .toList();
          return ChecklistItem(
            id: itemId,
            text: item.text,
            isChecked: item.isChecked,
            indentLevel: item.indentLevel,
            spans: spans,
            metadata: item.metadata,
          );
        }).toList();
        return ChecklistNode(
          id: id,
          items: items.isEmpty
              ? [ChecklistItem(id: generateUuid(), text: '')]
              : items,
          style: node.style,
          metadata: node.metadata,
        );
      }
      if (node is CodeBlockNode) {
        return node.copyWith(
          code: node.code,
          languageId: _codeLanguages.contains(node.languageId)
              ? node.languageId
              : 'plainText',
        );
      }
      if (node is! ParagraphNode) return node;
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

  static const _codeLanguages = <String>{
    'plainText',
    'dart',
    'python',
    'javascript',
    'typescript',
    'json',
    'html',
    'css',
    'sql',
    'java',
    'kotlin',
    'c',
    'cpp',
    'csharp',
    'bash',
    'yaml',
    'markdown',
  };
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

  EditingResult applyInlineAttributes(String attribute, Object? value) {
    document = document.applyFormat(selection, attribute, value);
    return EditingResult(document, selection);
  }

  EditingResult applyParagraphAttributes(String attribute, Object? value) {
    document = document.setParagraphAttribute(selection, attribute, value);
    return EditingResult(document, selection);
  }

  EditingResult insertNode(DocumentNode node) {
    final position = _position(selection.anchor);
    final paragraph = _paragraph(position.index);
    final offset = position.offset.clamp(0, paragraph.text.length);
    final before = paragraph.copyWith(
      text: paragraph.text.substring(0, offset),
    );
    final after = ParagraphNode(
      id: generateUuid(),
      text: paragraph.text.substring(offset),
      attributes: paragraph.attributes,
    );
    final list = [...document.nodes]
      ..replaceRange(position.index, position.index + 1, [before, node, after]);
    document = StructuredDocument(
      nodes: list,
      metadata: document.metadata,
    ).normalized();
    selection = DocumentSelection.collapsed(
      DocumentPosition(nodeId: after.id, offset: 0),
    );
    return EditingResult(document, selection);
  }

  EditingResult insertImage(ImageNode node) => insertNode(node);
  EditingResult insertDivider(DividerNode node) => insertNode(node);

  EditingResult updateChecklistItem(
    String nodeId,
    String itemId, {
    String? text,
    bool? isChecked,
    int? indentLevel,
  }) {
    final index = document.nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0 || document.nodes[index] is! ChecklistNode) {
      return EditingResult(document, selection);
    }
    final node = document.nodes[index] as ChecklistNode;
    final items = node.items
        .map(
          (item) => item.id == itemId
              ? item.copyWith(
                  text: text,
                  isChecked: isChecked,
                  indentLevel: indentLevel,
                )
              : item,
        )
        .toList();
    return replaceNode(nodeId, node.copyWith(items: items));
  }

  EditingResult addChecklistItem(String nodeId, {int? afterIndex}) {
    final index = document.nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0 || document.nodes[index] is! ChecklistNode) {
      return EditingResult(document, selection);
    }
    final node = document.nodes[index] as ChecklistNode;
    final items = [...node.items];
    final at = ((afterIndex ?? items.length - 1) + 1).clamp(0, items.length);
    items.insert(at, ChecklistItem(id: generateUuid(), text: ''));
    return replaceNode(nodeId, node.copyWith(items: items));
  }

  EditingResult removeChecklistItem(String nodeId, String itemId) {
    final index = document.nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0 || document.nodes[index] is! ChecklistNode) {
      return EditingResult(document, selection);
    }
    final node = document.nodes[index] as ChecklistNode;
    final items = node.items.where((item) => item.id != itemId).toList();
    return replaceNode(
      nodeId,
      node.copyWith(
        items: items.isEmpty
            ? [ChecklistItem(id: generateUuid(), text: '')]
            : items,
      ),
    );
  }

  EditingResult toggleChecklistItem(String nodeId, String itemId) {
    final node = document.nodes.where((n) => n.id == nodeId).firstOrNull;
    if (node is! ChecklistNode) return EditingResult(document, selection);
    final item = node.items.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return EditingResult(document, selection);
    return updateChecklistItem(nodeId, itemId, isChecked: !item.isChecked);
  }

  EditingResult convertNodeToParagraph(String nodeId) {
    final index = document.nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0 || document.nodes[index] is ParagraphNode) {
      return EditingResult(document, selection);
    }
    final node = document.nodes[index];
    final texts = switch (node) {
      ChecklistNode() =>
        node.items
            .map(
              (i) => ParagraphNode(
                id: generateUuid(),
                text: i.text,
                spans: i.spans,
              ),
            )
            .toList(),
      QuoteNode() => [
        ParagraphNode(id: generateUuid(), text: node.text, spans: node.spans),
      ],
      CalloutNode() => [
        ParagraphNode(id: generateUuid(), text: node.text, spans: node.spans),
      ],
      CodeBlockNode() =>
        node.code
            .split('\n')
            .map((line) => ParagraphNode(id: generateUuid(), text: line))
            .toList(),
      _ => <ParagraphNode>[ParagraphNode(id: generateUuid(), text: '')],
    };
    final list = [...document.nodes]..replaceRange(index, index + 1, texts);
    document = StructuredDocument(
      nodes: list,
      metadata: document.metadata,
    ).normalized();
    selection = DocumentSelection.collapsed(
      DocumentPosition(nodeId: texts.first.id, offset: 0),
    );
    return EditingResult(document, selection);
  }

  EditingResult removeNode(String nodeId) {
    final index = document.nodes.indexWhere((node) => node.id == nodeId);
    if (index < 0 || document.nodes[index] is ParagraphNode) {
      return EditingResult(document, selection);
    }
    final list = [...document.nodes]..removeAt(index);
    if (!list.any((node) => node is ParagraphNode)) {
      list.add(ParagraphNode(id: generateUuid(), text: ''));
    }
    document = StructuredDocument(
      nodes: list,
      metadata: document.metadata,
    ).normalized();
    final fallback = list.whereType<ParagraphNode>().first;
    selection = DocumentSelection.collapsed(
      DocumentPosition(nodeId: fallback.id, offset: 0),
    );
    return EditingResult(document, selection);
  }

  EditingResult replaceNode(String nodeId, DocumentNode replacement) {
    final index = document.nodes.indexWhere((node) => node.id == nodeId);
    if (index < 0 || document.nodes[index] is ParagraphNode) {
      return EditingResult(document, selection);
    }
    final list = [...document.nodes]..[index] = replacement;
    document = StructuredDocument(
      nodes: list,
      metadata: document.metadata,
    ).normalized();
    return EditingResult(document, selection);
  }

  EditingResult moveNode(String nodeId, int targetIndex) {
    final index = document.nodes.indexWhere((node) => node.id == nodeId);
    if (index < 0 || document.nodes[index] is ParagraphNode) {
      return EditingResult(document, selection);
    }
    final list = [...document.nodes];
    final node = list.removeAt(index);
    final destination = targetIndex.clamp(0, list.length);
    list.insert(destination, node);
    document = StructuredDocument(
      nodes: list,
      metadata: document.metadata,
    ).normalized();
    return EditingResult(document, selection);
  }

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
