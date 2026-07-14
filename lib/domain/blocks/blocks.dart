import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/value_objects/structured_document.dart';

enum BlockType {
  text,
  image,
  divider,
  checklist,
  code,
  table,
  attachment,
  quote,
  callout,
  unknown,
}

enum BlockCapability {
  selectable,
  editable,
  movable,
  deletable,
  duplicable,
  lockable,
  resizable,
  rotatable,
  formatable,
  openable,
  replaceable,
  shareable,
  convertible,
  exportable,
}

enum BlockAlignment { left, center, right }

enum DividerStyle { solid, dashed }

enum ImageDisplaySize { small, medium, large, original }

enum BlockCalloutType { info, tip, warning, success, error, note }

class BlockGeometry {
  const BlockGeometry({
    this.x = 0,
    this.y = 0,
    this.width,
    this.height,
    this.rotation = 0,
    this.scale = 1,
    this.layer = 0,
  });

  final double x;
  final double y;
  final double? width;
  final double? height;
  final double rotation;
  final double scale;
  final int layer;

  BlockGeometry copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    bool clearWidth = false,
    bool clearHeight = false,
    double? rotation,
    double? scale,
    int? layer,
  }) => BlockGeometry(
    x: x ?? this.x,
    y: y ?? this.y,
    width: clearWidth ? null : width ?? this.width,
    height: clearHeight ? null : height ?? this.height,
    rotation: rotation ?? this.rotation,
    scale: scale ?? this.scale,
    layer: layer ?? this.layer,
  );

  JsonMap toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'rotation': rotation,
    'scale': scale,
    'layer': layer,
  };

  factory BlockGeometry.fromJson(Object? value) {
    final map = _jsonMap(value);
    return BlockGeometry(
      x: _double(map['x']),
      y: _double(map['y']),
      width: _nullableDouble(map['width']),
      height: _nullableDouble(map['height']),
      rotation: _double(map['rotation']),
      scale: _double(map['scale'], 1),
      layer: _int(map['layer']),
    );
  }
}

class BlockTextSelection {
  const BlockTextSelection({
    required this.baseOffset,
    required this.extentOffset,
  });

  final int baseOffset;
  final int extentOffset;

  JsonMap toJson() => {'baseOffset': baseOffset, 'extentOffset': extentOffset};

  factory BlockTextSelection.fromJson(Object? value) {
    final map = _jsonMap(value);
    return BlockTextSelection(
      baseOffset: _int(map['baseOffset']),
      extentOffset: _int(map['extentOffset']),
    );
  }
}

class BlockParagraph {
  const BlockParagraph({
    required this.id,
    required this.text,
    this.attributes = const ParagraphAttributes(),
    this.spans = const [],
    this.metadata = const {},
  });

  final Uuid id;
  final String text;
  final ParagraphAttributes attributes;
  final List<TextSpanMark> spans;
  final JsonMap metadata;

  BlockParagraph copyWith({
    String? text,
    ParagraphAttributes? attributes,
    List<TextSpanMark>? spans,
    JsonMap? metadata,
  }) => BlockParagraph(
    id: id,
    text: text ?? this.text,
    attributes: attributes ?? this.attributes,
    spans: spans ?? this.spans,
    metadata: metadata ?? this.metadata,
  );

  JsonMap toJson() => {
    'id': id,
    'text': text,
    'attributes': attributes.toJson(),
    'spans': spans.map((span) => span.toJson()).toList(growable: false),
    'metadata': metadata,
  };

  factory BlockParagraph.fromJson(Object? value) {
    final map = _jsonMap(value);
    return BlockParagraph(
      id: map['id'] as String? ?? generateUuid(),
      text: map['text'] as String? ?? '',
      attributes: ParagraphAttributes.fromJson(map['attributes']),
      spans: _jsonList(map['spans']).map(TextSpanMark.fromJson).toList(),
      metadata: _jsonMap(map['metadata']),
    );
  }

  factory BlockParagraph.fromLegacy(ParagraphNode node) => BlockParagraph(
    id: node.id,
    text: node.text,
    attributes: node.attributes,
    spans: node.spans,
    metadata: node.metadata ?? const {},
  );

  ParagraphNode toLegacy() => ParagraphNode(
    id: id,
    text: text,
    attributes: attributes,
    spans: spans,
    metadata: metadata,
  );
}

class BlockChecklistItem {
  const BlockChecklistItem({
    required this.id,
    required this.text,
    this.isChecked = false,
    this.metadata = const {},
  });

  final Uuid id;
  final String text;
  final bool isChecked;
  final JsonMap metadata;

  BlockChecklistItem copyWith({String? text, bool? isChecked}) =>
      BlockChecklistItem(
        id: id,
        text: text ?? this.text,
        isChecked: isChecked ?? this.isChecked,
        metadata: metadata,
      );

  JsonMap toJson() => {
    'id': id,
    'text': text,
    'isChecked': isChecked,
    'metadata': metadata,
  };

  factory BlockChecklistItem.fromJson(Object? value) {
    final map = _jsonMap(value);
    return BlockChecklistItem(
      id: map['id'] as String? ?? generateUuid(),
      text: map['text'] as String? ?? '',
      isChecked: map['isChecked'] as bool? ?? false,
      metadata: _jsonMap(map['metadata']),
    );
  }
}

class BlockTableCell {
  const BlockTableCell({
    required this.id,
    this.text = '',
    this.spans = const [],
    this.metadata = const {},
  });

  final Uuid id;
  final String text;
  final List<TextSpanMark> spans;
  final JsonMap metadata;

  BlockTableCell copyWith({String? text, List<TextSpanMark>? spans}) =>
      BlockTableCell(
        id: id,
        text: text ?? this.text,
        spans: spans ?? this.spans,
        metadata: metadata,
      );

  JsonMap toJson() => {
    'id': id,
    'text': text,
    'spans': spans.map((span) => span.toJson()).toList(growable: false),
    'metadata': metadata,
  };

  factory BlockTableCell.fromJson(Object? value) {
    final map = _jsonMap(value);
    return BlockTableCell(
      id: map['id'] as String? ?? generateUuid(),
      text: map['text'] as String? ?? '',
      spans: _jsonList(map['spans']).map(TextSpanMark.fromJson).toList(),
      metadata: _jsonMap(map['metadata']),
    );
  }
}

class BlockTableRow {
  const BlockTableRow({required this.id, required this.cells});

  final Uuid id;
  final List<BlockTableCell> cells;

  BlockTableRow copyWith({List<BlockTableCell>? cells}) =>
      BlockTableRow(id: id, cells: cells ?? this.cells);

  JsonMap toJson() => {
    'id': id,
    'cells': cells.map((cell) => cell.toJson()).toList(growable: false),
  };

  factory BlockTableRow.fromJson(Object? value) {
    final map = _jsonMap(value);
    return BlockTableRow(
      id: map['id'] as String? ?? generateUuid(),
      cells: _jsonList(map['cells']).map(BlockTableCell.fromJson).toList(),
    );
  }
}

sealed class BaseBlock {
  const BaseBlock({
    required this.id,
    required this.type,
    required this.orderKey,
    required this.geometry,
    required this.capabilities,
    required this.isVisible,
    required this.isLocked,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.metadata,
  });

  final Uuid id;
  final BlockType type;
  final double orderKey;
  final BlockGeometry geometry;
  final Set<BlockCapability> capabilities;
  final bool isVisible;
  final bool isLocked;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final JsonMap metadata;

  bool supports(BlockCapability capability) =>
      capabilities.contains(capability);

  JsonMap toJson();

  BaseBlock copyWithCommon({
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  });

  JsonMap commonJson() => {
    'id': id,
    'type': type.name,
    'orderKey': orderKey,
    'geometry': geometry.toJson(),
    'capabilities': capabilities
        .map((capability) => capability.name)
        .toList(growable: false),
    'isVisible': isVisible,
    'isLocked': isLocked,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'version': version,
    'metadata': metadata,
  };
}

class TextBlock extends BaseBlock {
  TextBlock({
    required super.id,
    required super.orderKey,
    required this.paragraphs,
    this.selection,
    super.geometry = const BlockGeometry(),
    super.capabilities = const {
      BlockCapability.selectable,
      BlockCapability.editable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.duplicable,
      BlockCapability.lockable,
      BlockCapability.formatable,
      BlockCapability.convertible,
      BlockCapability.exportable,
    },
    super.isVisible = true,
    super.isLocked = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    super.version = 1,
    super.metadata = const {},
  }) : super(
         type: BlockType.text,
         createdAt: createdAt ?? DateTime.now().toUtc(),
         updatedAt: updatedAt ?? createdAt ?? DateTime.now().toUtc(),
       );

  final List<BlockParagraph> paragraphs;
  final BlockTextSelection? selection;

  String get plainText =>
      paragraphs.map((paragraph) => paragraph.text).join('\n');

  TextBlock copyWith({
    List<BlockParagraph>? paragraphs,
    BlockTextSelection? selection,
    bool clearSelection = false,
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => TextBlock(
    id: id,
    orderKey: orderKey ?? this.orderKey,
    paragraphs: paragraphs ?? this.paragraphs,
    selection: clearSelection ? null : selection ?? this.selection,
    geometry: geometry ?? this.geometry,
    capabilities: capabilities ?? this.capabilities,
    isVisible: isVisible ?? this.isVisible,
    isLocked: isLocked ?? this.isLocked,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    metadata: metadata ?? this.metadata,
  );

  TextBlock withPlainText(String value) {
    final previous = plainText;
    if (previous == value) return this;
    var prefix = 0;
    while (prefix < previous.length &&
        prefix < value.length &&
        previous[prefix] == value[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < previous.length - prefix &&
        suffix < value.length - prefix &&
        previous[previous.length - 1 - suffix] ==
            value[value.length - 1 - suffix]) {
      suffix++;
    }
    final oldEnd = previous.length - suffix;
    final insertedLength = value.length - prefix - suffix;
    final newEnd = prefix + insertedLength;
    final delta = value.length - previous.length;

    final globalMarks = <_GlobalTextMark>[];
    var paragraphStart = 0;
    for (final paragraph in paragraphs) {
      for (final mark in paragraph.spans) {
        if (mark.start < mark.end) {
          globalMarks.add(
            _GlobalTextMark(
              start: paragraphStart + mark.start,
              end: paragraphStart + mark.end,
              attributes: mark.attributes,
            ),
          );
        }
      }
      paragraphStart += paragraph.text.length + 1;
    }
    final transformedMarks = globalMarks
        .map(
          (mark) => mark.transform(
            replaceStart: prefix,
            replaceEnd: oldEnd,
            insertedEnd: newEnd,
            delta: delta,
          ),
        )
        .whereType<_GlobalTextMark>()
        .toList();

    final oldLines = paragraphs.map((paragraph) => paragraph.text).toList();
    final newLines = value.split('\n');
    var commonLinePrefix = 0;
    while (commonLinePrefix < oldLines.length &&
        commonLinePrefix < newLines.length &&
        oldLines[commonLinePrefix] == newLines[commonLinePrefix]) {
      commonLinePrefix++;
    }
    var commonLineSuffix = 0;
    while (commonLineSuffix < oldLines.length - commonLinePrefix &&
        commonLineSuffix < newLines.length - commonLinePrefix &&
        oldLines[oldLines.length - 1 - commonLineSuffix] ==
            newLines[newLines.length - 1 - commonLineSuffix]) {
      commonLineSuffix++;
    }

    final nextParagraphs = <BlockParagraph>[];
    var lineStart = 0;
    for (var index = 0; index < newLines.length; index++) {
      final text = newLines[index];
      BlockParagraph? source;
      if (index < commonLinePrefix) {
        source = paragraphs[index];
      } else if (index >= newLines.length - commonLineSuffix) {
        final oldIndex = oldLines.length - (newLines.length - index);
        source = paragraphs[oldIndex];
      } else if (index == commonLinePrefix &&
          commonLinePrefix < paragraphs.length) {
        source = paragraphs[commonLinePrefix];
      }
      final lineEnd = lineStart + text.length;
      final spans = <TextSpanMark>[];
      for (final mark in transformedMarks) {
        final start = mark.start.clamp(lineStart, lineEnd);
        final end = mark.end.clamp(lineStart, lineEnd);
        if (start < end) {
          spans.add(
            TextSpanMark(
              start: start - lineStart,
              end: end - lineStart,
              attributes: mark.attributes,
            ),
          );
        }
      }
      nextParagraphs.add(
        BlockParagraph(
          id: source?.id ?? generateUuid(),
          text: text,
          attributes: source?.attributes ?? const ParagraphAttributes(),
          spans: spans,
          metadata: source?.metadata ?? const {},
        ),
      );
      lineStart = lineEnd + 1;
    }
    return copyWith(paragraphs: nextParagraphs);
  }

  @override
  BaseBlock copyWithCommon({
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => copyWith(
    orderKey: orderKey,
    geometry: geometry,
    capabilities: capabilities,
    isVisible: isVisible,
    isLocked: isLocked,
    updatedAt: updatedAt,
    version: version,
    metadata: metadata,
  );

  @override
  JsonMap toJson() => {
    ...commonJson(),
    'paragraphs': paragraphs
        .map((paragraph) => paragraph.toJson())
        .toList(growable: false),
    'selection': selection?.toJson(),
  };
}

class ImageBlock extends BaseBlock {
  ImageBlock({
    required super.id,
    required super.orderKey,
    required this.attachmentId,
    this.altText,
    this.caption,
    this.alignment = BlockAlignment.center,
    this.displaySize = ImageDisplaySize.large,
    super.geometry = const BlockGeometry(),
    super.capabilities = const {
      BlockCapability.selectable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.duplicable,
      BlockCapability.lockable,
      BlockCapability.resizable,
      BlockCapability.openable,
      BlockCapability.replaceable,
      BlockCapability.shareable,
      BlockCapability.exportable,
    },
    super.isVisible = true,
    super.isLocked = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    super.version = 1,
    super.metadata = const {},
  }) : super(
         type: BlockType.image,
         createdAt: createdAt ?? DateTime.now().toUtc(),
         updatedAt: updatedAt ?? createdAt ?? DateTime.now().toUtc(),
       );

  final String attachmentId;
  final String? altText;
  final String? caption;
  final BlockAlignment alignment;
  final ImageDisplaySize displaySize;

  ImageBlock copyWith({
    String? attachmentId,
    String? altText,
    String? caption,
    bool clearAltText = false,
    bool clearCaption = false,
    BlockAlignment? alignment,
    ImageDisplaySize? displaySize,
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => ImageBlock(
    id: id,
    orderKey: orderKey ?? this.orderKey,
    attachmentId: attachmentId ?? this.attachmentId,
    altText: clearAltText ? null : altText ?? this.altText,
    caption: clearCaption ? null : caption ?? this.caption,
    alignment: alignment ?? this.alignment,
    displaySize: displaySize ?? this.displaySize,
    geometry: geometry ?? this.geometry,
    capabilities: capabilities ?? this.capabilities,
    isVisible: isVisible ?? this.isVisible,
    isLocked: isLocked ?? this.isLocked,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    metadata: metadata ?? this.metadata,
  );

  @override
  BaseBlock copyWithCommon({
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => copyWith(
    orderKey: orderKey,
    geometry: geometry,
    capabilities: capabilities,
    isVisible: isVisible,
    isLocked: isLocked,
    updatedAt: updatedAt,
    version: version,
    metadata: metadata,
  );

  @override
  JsonMap toJson() => {
    ...commonJson(),
    'attachmentId': attachmentId,
    'altText': altText,
    'caption': caption,
    'alignment': alignment.name,
    'displaySize': displaySize.name,
  };
}

class DividerBlock extends BaseBlock {
  DividerBlock({
    required super.id,
    required super.orderKey,
    this.style = DividerStyle.solid,
    this.thickness = 1,
    super.geometry = const BlockGeometry(),
    super.capabilities = const {
      BlockCapability.selectable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.duplicable,
      BlockCapability.lockable,
      BlockCapability.exportable,
    },
    super.isVisible = true,
    super.isLocked = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    super.version = 1,
    super.metadata = const {},
  }) : super(
         type: BlockType.divider,
         createdAt: createdAt ?? DateTime.now().toUtc(),
         updatedAt: updatedAt ?? createdAt ?? DateTime.now().toUtc(),
       );

  final DividerStyle style;
  final double thickness;

  DividerBlock copyWith({
    DividerStyle? style,
    double? thickness,
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => DividerBlock(
    id: id,
    orderKey: orderKey ?? this.orderKey,
    style: style ?? this.style,
    thickness: thickness ?? this.thickness,
    geometry: geometry ?? this.geometry,
    capabilities: capabilities ?? this.capabilities,
    isVisible: isVisible ?? this.isVisible,
    isLocked: isLocked ?? this.isLocked,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    metadata: metadata ?? this.metadata,
  );

  @override
  BaseBlock copyWithCommon({
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => copyWith(
    orderKey: orderKey,
    geometry: geometry,
    capabilities: capabilities,
    isVisible: isVisible,
    isLocked: isLocked,
    updatedAt: updatedAt,
    version: version,
    metadata: metadata,
  );

  @override
  JsonMap toJson() => {
    ...commonJson(),
    'style': style.name,
    'thickness': thickness,
  };
}

class ChecklistBlock extends BaseBlock {
  ChecklistBlock({
    required super.id,
    required super.orderKey,
    required this.items,
    super.geometry = const BlockGeometry(),
    super.capabilities = const {
      BlockCapability.selectable,
      BlockCapability.editable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.duplicable,
      BlockCapability.lockable,
      BlockCapability.exportable,
    },
    super.isVisible = true,
    super.isLocked = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    super.version = 1,
    super.metadata = const {},
  }) : super(
         type: BlockType.checklist,
         createdAt: createdAt ?? DateTime.now().toUtc(),
         updatedAt: updatedAt ?? createdAt ?? DateTime.now().toUtc(),
       );

  final List<BlockChecklistItem> items;

  ChecklistBlock copyWith({
    List<BlockChecklistItem>? items,
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => ChecklistBlock(
    id: id,
    orderKey: orderKey ?? this.orderKey,
    items: items ?? this.items,
    geometry: geometry ?? this.geometry,
    capabilities: capabilities ?? this.capabilities,
    isVisible: isVisible ?? this.isVisible,
    isLocked: isLocked ?? this.isLocked,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    metadata: metadata ?? this.metadata,
  );

  @override
  BaseBlock copyWithCommon({
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => copyWith(
    orderKey: orderKey,
    geometry: geometry,
    capabilities: capabilities,
    isVisible: isVisible,
    isLocked: isLocked,
    updatedAt: updatedAt,
    version: version,
    metadata: metadata,
  );

  @override
  JsonMap toJson() => {
    ...commonJson(),
    'items': items.map((item) => item.toJson()).toList(growable: false),
  };
}

class CodeBlock extends BaseBlock {
  CodeBlock({
    required super.id,
    required super.orderKey,
    this.code = '',
    this.languageId = 'plainText',
    this.showLineNumbers = false,
    this.wrapLines = true,
    this.caption,
    super.geometry = const BlockGeometry(),
    super.capabilities = const {
      BlockCapability.selectable,
      BlockCapability.editable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.duplicable,
      BlockCapability.lockable,
      BlockCapability.exportable,
    },
    super.isVisible = true,
    super.isLocked = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    super.version = 1,
    super.metadata = const {},
  }) : super(
         type: BlockType.code,
         createdAt: createdAt ?? DateTime.now().toUtc(),
         updatedAt: updatedAt ?? createdAt ?? DateTime.now().toUtc(),
       );

  final String code;
  final String languageId;
  final bool showLineNumbers;
  final bool wrapLines;
  final String? caption;

  CodeBlock copyWith({
    String? code,
    String? languageId,
    bool? showLineNumbers,
    bool? wrapLines,
    String? caption,
    bool clearCaption = false,
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => CodeBlock(
    id: id,
    orderKey: orderKey ?? this.orderKey,
    code: code ?? this.code,
    languageId: languageId ?? this.languageId,
    showLineNumbers: showLineNumbers ?? this.showLineNumbers,
    wrapLines: wrapLines ?? this.wrapLines,
    caption: clearCaption ? null : caption ?? this.caption,
    geometry: geometry ?? this.geometry,
    capabilities: capabilities ?? this.capabilities,
    isVisible: isVisible ?? this.isVisible,
    isLocked: isLocked ?? this.isLocked,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    metadata: metadata ?? this.metadata,
  );

  @override
  BaseBlock copyWithCommon({
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => copyWith(
    orderKey: orderKey,
    geometry: geometry,
    capabilities: capabilities,
    isVisible: isVisible,
    isLocked: isLocked,
    updatedAt: updatedAt,
    version: version,
    metadata: metadata,
  );

  @override
  JsonMap toJson() => {
    ...commonJson(),
    'code': code,
    'languageId': languageId,
    'showLineNumbers': showLineNumbers,
    'wrapLines': wrapLines,
    'caption': caption,
  };
}

class TableBlock extends BaseBlock {
  TableBlock({
    required super.id,
    required super.orderKey,
    required this.rows,
    required this.columnIds,
    this.hasHeaderRow = false,
    super.geometry = const BlockGeometry(),
    super.capabilities = const {
      BlockCapability.selectable,
      BlockCapability.editable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.duplicable,
      BlockCapability.lockable,
      BlockCapability.resizable,
      BlockCapability.exportable,
    },
    super.isVisible = true,
    super.isLocked = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    super.version = 1,
    super.metadata = const {},
  }) : super(
         type: BlockType.table,
         createdAt: createdAt ?? DateTime.now().toUtc(),
         updatedAt: updatedAt ?? createdAt ?? DateTime.now().toUtc(),
       );

  final List<BlockTableRow> rows;
  final List<Uuid> columnIds;
  final bool hasHeaderRow;

  int get columnCount => columnIds.length;

  TableBlock copyWith({
    List<BlockTableRow>? rows,
    List<Uuid>? columnIds,
    bool? hasHeaderRow,
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => TableBlock(
    id: id,
    orderKey: orderKey ?? this.orderKey,
    rows: rows ?? this.rows,
    columnIds: columnIds ?? this.columnIds,
    hasHeaderRow: hasHeaderRow ?? this.hasHeaderRow,
    geometry: geometry ?? this.geometry,
    capabilities: capabilities ?? this.capabilities,
    isVisible: isVisible ?? this.isVisible,
    isLocked: isLocked ?? this.isLocked,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    metadata: metadata ?? this.metadata,
  );

  @override
  BaseBlock copyWithCommon({
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => copyWith(
    orderKey: orderKey,
    geometry: geometry,
    capabilities: capabilities,
    isVisible: isVisible,
    isLocked: isLocked,
    updatedAt: updatedAt,
    version: version,
    metadata: metadata,
  );

  @override
  JsonMap toJson() => {
    ...commonJson(),
    'rows': rows.map((row) => row.toJson()).toList(growable: false),
    'columnIds': columnIds,
    'hasHeaderRow': hasHeaderRow,
  };
}

class AttachmentBlock extends BaseBlock {
  AttachmentBlock({
    required super.id,
    required super.orderKey,
    required this.attachmentId,
    required this.displayName,
    this.mimeType = 'application/octet-stream',
    this.extension = '',
    this.sizeBytes = 0,
    this.description,
    super.geometry = const BlockGeometry(),
    super.capabilities = const {
      BlockCapability.selectable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.duplicable,
      BlockCapability.lockable,
      BlockCapability.openable,
      BlockCapability.replaceable,
      BlockCapability.shareable,
      BlockCapability.exportable,
    },
    super.isVisible = true,
    super.isLocked = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    super.version = 1,
    super.metadata = const {},
  }) : super(
         type: BlockType.attachment,
         createdAt: createdAt ?? DateTime.now().toUtc(),
         updatedAt: updatedAt ?? createdAt ?? DateTime.now().toUtc(),
       );

  final String attachmentId;
  final String displayName;
  final String mimeType;
  final String extension;
  final int sizeBytes;
  final String? description;

  AttachmentBlock copyWith({
    String? attachmentId,
    String? displayName,
    String? mimeType,
    String? extension,
    int? sizeBytes,
    String? description,
    bool clearDescription = false,
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => AttachmentBlock(
    id: id,
    orderKey: orderKey ?? this.orderKey,
    attachmentId: attachmentId ?? this.attachmentId,
    displayName: displayName ?? this.displayName,
    mimeType: mimeType ?? this.mimeType,
    extension: extension ?? this.extension,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    description: clearDescription ? null : description ?? this.description,
    geometry: geometry ?? this.geometry,
    capabilities: capabilities ?? this.capabilities,
    isVisible: isVisible ?? this.isVisible,
    isLocked: isLocked ?? this.isLocked,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    metadata: metadata ?? this.metadata,
  );

  @override
  BaseBlock copyWithCommon({
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => copyWith(
    orderKey: orderKey,
    geometry: geometry,
    capabilities: capabilities,
    isVisible: isVisible,
    isLocked: isLocked,
    updatedAt: updatedAt,
    version: version,
    metadata: metadata,
  );

  @override
  JsonMap toJson() => {
    ...commonJson(),
    'attachmentId': attachmentId,
    'displayName': displayName,
    'mimeType': mimeType,
    'extension': extension,
    'sizeBytes': sizeBytes,
    'description': description,
  };
}

class QuoteBlock extends BaseBlock {
  QuoteBlock({
    required super.id,
    required super.orderKey,
    this.text = '',
    this.spans = const [],
    this.citation,
    super.geometry = const BlockGeometry(),
    super.capabilities = const {
      BlockCapability.selectable,
      BlockCapability.editable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.duplicable,
      BlockCapability.lockable,
      BlockCapability.formatable,
      BlockCapability.exportable,
    },
    super.isVisible = true,
    super.isLocked = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    super.version = 1,
    super.metadata = const {},
  }) : super(
         type: BlockType.quote,
         createdAt: createdAt ?? DateTime.now().toUtc(),
         updatedAt: updatedAt ?? createdAt ?? DateTime.now().toUtc(),
       );

  final String text;
  final List<TextSpanMark> spans;
  final String? citation;

  QuoteBlock copyWith({
    String? text,
    List<TextSpanMark>? spans,
    String? citation,
    bool clearCitation = false,
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => QuoteBlock(
    id: id,
    orderKey: orderKey ?? this.orderKey,
    text: text ?? this.text,
    spans: spans ?? this.spans,
    citation: clearCitation ? null : citation ?? this.citation,
    geometry: geometry ?? this.geometry,
    capabilities: capabilities ?? this.capabilities,
    isVisible: isVisible ?? this.isVisible,
    isLocked: isLocked ?? this.isLocked,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    metadata: metadata ?? this.metadata,
  );

  @override
  BaseBlock copyWithCommon({
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => copyWith(
    orderKey: orderKey,
    geometry: geometry,
    capabilities: capabilities,
    isVisible: isVisible,
    isLocked: isLocked,
    updatedAt: updatedAt,
    version: version,
    metadata: metadata,
  );

  @override
  JsonMap toJson() => {
    ...commonJson(),
    'text': text,
    'spans': spans.map((span) => span.toJson()).toList(growable: false),
    'citation': citation,
  };
}

class CalloutBlock extends BaseBlock {
  CalloutBlock({
    required super.id,
    required super.orderKey,
    this.title,
    this.text = '',
    this.spans = const [],
    this.calloutType = BlockCalloutType.info,
    super.geometry = const BlockGeometry(),
    super.capabilities = const {
      BlockCapability.selectable,
      BlockCapability.editable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.duplicable,
      BlockCapability.lockable,
      BlockCapability.formatable,
      BlockCapability.exportable,
    },
    super.isVisible = true,
    super.isLocked = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    super.version = 1,
    super.metadata = const {},
  }) : super(
         type: BlockType.callout,
         createdAt: createdAt ?? DateTime.now().toUtc(),
         updatedAt: updatedAt ?? createdAt ?? DateTime.now().toUtc(),
       );

  final String? title;
  final String text;
  final List<TextSpanMark> spans;
  final BlockCalloutType calloutType;

  CalloutBlock copyWith({
    String? title,
    bool clearTitle = false,
    String? text,
    List<TextSpanMark>? spans,
    BlockCalloutType? calloutType,
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => CalloutBlock(
    id: id,
    orderKey: orderKey ?? this.orderKey,
    title: clearTitle ? null : title ?? this.title,
    text: text ?? this.text,
    spans: spans ?? this.spans,
    calloutType: calloutType ?? this.calloutType,
    geometry: geometry ?? this.geometry,
    capabilities: capabilities ?? this.capabilities,
    isVisible: isVisible ?? this.isVisible,
    isLocked: isLocked ?? this.isLocked,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    metadata: metadata ?? this.metadata,
  );

  @override
  BaseBlock copyWithCommon({
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => copyWith(
    orderKey: orderKey,
    geometry: geometry,
    capabilities: capabilities,
    isVisible: isVisible,
    isLocked: isLocked,
    updatedAt: updatedAt,
    version: version,
    metadata: metadata,
  );

  @override
  JsonMap toJson() => {
    ...commonJson(),
    'title': title,
    'text': text,
    'spans': spans.map((span) => span.toJson()).toList(growable: false),
    'calloutType': calloutType.name,
  };
}

class UnknownBlock extends BaseBlock {
  UnknownBlock({
    required super.id,
    required super.orderKey,
    required this.originalType,
    required this.raw,
    super.geometry = const BlockGeometry(),
    super.capabilities = const {
      BlockCapability.selectable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.exportable,
    },
    super.isVisible = true,
    super.isLocked = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    super.version = 1,
    super.metadata = const {},
  }) : super(
         type: BlockType.unknown,
         createdAt: createdAt ?? DateTime.now().toUtc(),
         updatedAt: updatedAt ?? createdAt ?? DateTime.now().toUtc(),
       );

  final String originalType;
  final JsonMap raw;

  @override
  BaseBlock copyWithCommon({
    double? orderKey,
    BlockGeometry? geometry,
    Set<BlockCapability>? capabilities,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
    int? version,
    JsonMap? metadata,
  }) => UnknownBlock(
    id: id,
    orderKey: orderKey ?? this.orderKey,
    originalType: originalType,
    raw: raw,
    geometry: geometry ?? this.geometry,
    capabilities: capabilities ?? this.capabilities,
    isVisible: isVisible ?? this.isVisible,
    isLocked: isLocked ?? this.isLocked,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    metadata: metadata ?? this.metadata,
  );

  @override
  JsonMap toJson() => {
    ...commonJson(),
    'originalType': originalType,
    'raw': raw,
  };
}

typedef BlockDeserializer = BaseBlock Function(JsonMap json);

class BlockCodec {
  BlockCodec._();

  static final Map<String, BlockDeserializer> _deserializers = {
    BlockType.text.name: _textFromJson,
    BlockType.image.name: _imageFromJson,
    BlockType.divider.name: _dividerFromJson,
    BlockType.checklist.name: _checklistFromJson,
    BlockType.code.name: _codeFromJson,
    BlockType.table.name: _tableFromJson,
    BlockType.attachment.name: _attachmentFromJson,
    BlockType.quote.name: _quoteFromJson,
    BlockType.callout.name: _calloutFromJson,
  };

  static void register(String type, BlockDeserializer deserializer) {
    _deserializers[type] = deserializer;
  }

  static BaseBlock fromJson(Object? value) {
    final json = _jsonMap(value);
    final type = json['type'] as String? ?? BlockType.unknown.name;
    return _deserializers[type]?.call(json) ?? _unknownFromJson(json);
  }

  static JsonMap toJson(BaseBlock block) => block.toJson();

  static TextBlock _textFromJson(JsonMap json) => TextBlock(
    id: _id(json),
    orderKey: _order(json),
    paragraphs: _jsonList(
      json['paragraphs'],
    ).map(BlockParagraph.fromJson).toList(),
    selection: json['selection'] == null
        ? null
        : BlockTextSelection.fromJson(json['selection']),
    geometry: _geometry(json),
    capabilities: _capabilities(json, const {
      BlockCapability.selectable,
      BlockCapability.editable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.duplicable,
      BlockCapability.lockable,
      BlockCapability.formatable,
      BlockCapability.convertible,
      BlockCapability.exportable,
    }),
    isVisible: _visible(json),
    isLocked: _locked(json),
    createdAt: _createdAt(json),
    updatedAt: _updatedAt(json),
    version: _version(json),
    metadata: _jsonMap(json['metadata']),
  );

  static ImageBlock _imageFromJson(JsonMap json) => ImageBlock(
    id: _id(json),
    orderKey: _order(json),
    attachmentId: json['attachmentId'] as String? ?? '',
    altText: json['altText'] as String?,
    caption: json['caption'] as String?,
    alignment: _enumByName(
      BlockAlignment.values,
      json['alignment'],
      BlockAlignment.center,
    ),
    displaySize: _enumByName(
      ImageDisplaySize.values,
      json['displaySize'],
      ImageDisplaySize.large,
    ),
    geometry: _geometry(json),
    capabilities: _capabilities(json, const {
      BlockCapability.selectable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.duplicable,
      BlockCapability.lockable,
      BlockCapability.resizable,
      BlockCapability.openable,
      BlockCapability.replaceable,
      BlockCapability.shareable,
      BlockCapability.exportable,
    }),
    isVisible: _visible(json),
    isLocked: _locked(json),
    createdAt: _createdAt(json),
    updatedAt: _updatedAt(json),
    version: _version(json),
    metadata: _jsonMap(json['metadata']),
  );

  static DividerBlock _dividerFromJson(JsonMap json) => DividerBlock(
    id: _id(json),
    orderKey: _order(json),
    style: _enumByName(DividerStyle.values, json['style'], DividerStyle.solid),
    thickness: _double(json['thickness'], 1),
    geometry: _geometry(json),
    capabilities: _capabilities(json, const {
      BlockCapability.selectable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.duplicable,
      BlockCapability.lockable,
      BlockCapability.exportable,
    }),
    isVisible: _visible(json),
    isLocked: _locked(json),
    createdAt: _createdAt(json),
    updatedAt: _updatedAt(json),
    version: _version(json),
    metadata: _jsonMap(json['metadata']),
  );

  static ChecklistBlock _checklistFromJson(JsonMap json) => ChecklistBlock(
    id: _id(json),
    orderKey: _order(json),
    items: _jsonList(json['items']).map(BlockChecklistItem.fromJson).toList(),
    geometry: _geometry(json),
    capabilities: _capabilities(json, const {
      BlockCapability.selectable,
      BlockCapability.editable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.duplicable,
      BlockCapability.lockable,
      BlockCapability.exportable,
    }),
    isVisible: _visible(json),
    isLocked: _locked(json),
    createdAt: _createdAt(json),
    updatedAt: _updatedAt(json),
    version: _version(json),
    metadata: _jsonMap(json['metadata']),
  );

  static CodeBlock _codeFromJson(JsonMap json) => CodeBlock(
    id: _id(json),
    orderKey: _order(json),
    code: json['code'] as String? ?? '',
    languageId: json['languageId'] as String? ?? 'plainText',
    showLineNumbers: json['showLineNumbers'] as bool? ?? false,
    wrapLines: json['wrapLines'] as bool? ?? true,
    caption: json['caption'] as String?,
    geometry: _geometry(json),
    capabilities: _capabilities(json, const {
      BlockCapability.selectable,
      BlockCapability.editable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.duplicable,
      BlockCapability.lockable,
      BlockCapability.exportable,
    }),
    isVisible: _visible(json),
    isLocked: _locked(json),
    createdAt: _createdAt(json),
    updatedAt: _updatedAt(json),
    version: _version(json),
    metadata: _jsonMap(json['metadata']),
  );

  static TableBlock _tableFromJson(JsonMap json) => TableBlock(
    id: _id(json),
    orderKey: _order(json),
    rows: _jsonList(json['rows']).map(BlockTableRow.fromJson).toList(),
    columnIds: _jsonList(json['columnIds']).whereType<String>().toList(),
    hasHeaderRow: json['hasHeaderRow'] as bool? ?? false,
    geometry: _geometry(json),
    capabilities: _capabilities(json, const {
      BlockCapability.selectable,
      BlockCapability.editable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.duplicable,
      BlockCapability.lockable,
      BlockCapability.resizable,
      BlockCapability.exportable,
    }),
    isVisible: _visible(json),
    isLocked: _locked(json),
    createdAt: _createdAt(json),
    updatedAt: _updatedAt(json),
    version: _version(json),
    metadata: _jsonMap(json['metadata']),
  );

  static AttachmentBlock _attachmentFromJson(JsonMap json) => AttachmentBlock(
    id: _id(json),
    orderKey: _order(json),
    attachmentId: json['attachmentId'] as String? ?? '',
    displayName: json['displayName'] as String? ?? 'Archivo adjunto',
    mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
    extension: json['extension'] as String? ?? '',
    sizeBytes: _int(json['sizeBytes']),
    description: json['description'] as String?,
    geometry: _geometry(json),
    capabilities: _capabilities(json, const {
      BlockCapability.selectable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.duplicable,
      BlockCapability.lockable,
      BlockCapability.openable,
      BlockCapability.replaceable,
      BlockCapability.shareable,
      BlockCapability.exportable,
    }),
    isVisible: _visible(json),
    isLocked: _locked(json),
    createdAt: _createdAt(json),
    updatedAt: _updatedAt(json),
    version: _version(json),
    metadata: _jsonMap(json['metadata']),
  );

  static QuoteBlock _quoteFromJson(JsonMap json) => QuoteBlock(
    id: _id(json),
    orderKey: _order(json),
    text: json['text'] as String? ?? '',
    spans: _jsonList(json['spans']).map(TextSpanMark.fromJson).toList(),
    citation: json['citation'] as String?,
    geometry: _geometry(json),
    capabilities: _capabilities(json, const {
      BlockCapability.selectable,
      BlockCapability.editable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.duplicable,
      BlockCapability.lockable,
      BlockCapability.formatable,
      BlockCapability.exportable,
    }),
    isVisible: _visible(json),
    isLocked: _locked(json),
    createdAt: _createdAt(json),
    updatedAt: _updatedAt(json),
    version: _version(json),
    metadata: _jsonMap(json['metadata']),
  );

  static CalloutBlock _calloutFromJson(JsonMap json) => CalloutBlock(
    id: _id(json),
    orderKey: _order(json),
    title: json['title'] as String?,
    text: json['text'] as String? ?? '',
    spans: _jsonList(json['spans']).map(TextSpanMark.fromJson).toList(),
    calloutType: _enumByName(
      BlockCalloutType.values,
      json['calloutType'],
      BlockCalloutType.info,
    ),
    geometry: _geometry(json),
    capabilities: _capabilities(json, const {
      BlockCapability.selectable,
      BlockCapability.editable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.duplicable,
      BlockCapability.lockable,
      BlockCapability.formatable,
      BlockCapability.exportable,
    }),
    isVisible: _visible(json),
    isLocked: _locked(json),
    createdAt: _createdAt(json),
    updatedAt: _updatedAt(json),
    version: _version(json),
    metadata: _jsonMap(json['metadata']),
  );

  static UnknownBlock _unknownFromJson(JsonMap json) => UnknownBlock(
    id: _id(json),
    orderKey: _order(json),
    originalType:
        json['originalType'] as String? ?? json['type'] as String? ?? 'unknown',
    raw: _jsonMap(json['raw']).isEmpty ? json : _jsonMap(json['raw']),
    geometry: _geometry(json),
    capabilities: _capabilities(json, const {
      BlockCapability.selectable,
      BlockCapability.movable,
      BlockCapability.deletable,
      BlockCapability.exportable,
    }),
    isVisible: _visible(json),
    isLocked: _locked(json),
    createdAt: _createdAt(json),
    updatedAt: _updatedAt(json),
    version: _version(json),
    metadata: _jsonMap(json['metadata']),
  );
}

JsonMap _jsonMap(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : <String, Object?>{};

List<Object?> _jsonList(Object? value) =>
    value is List ? List<Object?>.from(value) : const [];

String _id(JsonMap json) => json['id'] as String? ?? generateUuid();

double _order(JsonMap json) => _double(json['orderKey']);

double _double(Object? value, [double fallback = 0]) =>
    (value as num?)?.toDouble() ?? fallback;

double? _nullableDouble(Object? value) => (value as num?)?.toDouble();

int _int(Object? value, [int fallback = 0]) =>
    (value as num?)?.toInt() ?? fallback;

int _version(JsonMap json) => _int(json['version'], 1);

bool _visible(JsonMap json) => json['isVisible'] as bool? ?? true;

bool _locked(JsonMap json) => json['isLocked'] as bool? ?? false;

DateTime _createdAt(JsonMap json) =>
    DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

DateTime _updatedAt(JsonMap json) =>
    DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toUtc() ??
    _createdAt(json);

BlockGeometry _geometry(JsonMap json) =>
    BlockGeometry.fromJson(json['geometry']);

Set<BlockCapability> _capabilities(
  JsonMap json,
  Set<BlockCapability> fallback,
) {
  final values = _jsonList(json['capabilities']).whereType<String>().toSet();
  if (values.isEmpty) return fallback;
  return BlockCapability.values
      .where((capability) => values.contains(capability.name))
      .toSet();
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

class _GlobalTextMark {
  const _GlobalTextMark({
    required this.start,
    required this.end,
    required this.attributes,
  });

  final int start;
  final int end;
  final JsonMap attributes;

  _GlobalTextMark? transform({
    required int replaceStart,
    required int replaceEnd,
    required int insertedEnd,
    required int delta,
  }) {
    if (end <= replaceStart) return this;
    if (start >= replaceEnd) {
      return _GlobalTextMark(
        start: start + delta,
        end: end + delta,
        attributes: attributes,
      );
    }
    if (start <= replaceStart && end >= replaceEnd) {
      return _GlobalTextMark(
        start: start,
        end: end + delta,
        attributes: attributes,
      );
    }
    if (start < replaceStart) {
      return _GlobalTextMark(
        start: start,
        end: insertedEnd,
        attributes: attributes,
      );
    }
    if (end > replaceEnd) {
      return _GlobalTextMark(
        start: insertedEnd,
        end: end + delta,
        attributes: attributes,
      );
    }
    return null;
  }
}
