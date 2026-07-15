import 'dart:math' as math;

import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';

enum CanvasConnectorKind { straight }

class CanvasPlacement {
  const CanvasPlacement({
    required this.blockId,
    required this.x,
    required this.y,
    this.width,
    this.height,
    required this.zIndex,
    this.containerId,
    this.locked = false,
  });

  final Uuid blockId;
  final double x;
  final double y;
  final double? width;
  final double? height;
  final int zIndex;
  final Uuid? containerId;
  final bool locked;

  SpatialRect bounds({
    double fallbackWidth = 360,
    double fallbackHeight = 96,
  }) => SpatialRect.fromLTWH(
    x,
    y,
    width ?? fallbackWidth,
    height ?? fallbackHeight,
  );

  bool get isValid =>
      x.isFinite &&
      y.isFinite &&
      (width == null || width!.isFinite && width! > 0) &&
      (height == null || height!.isFinite && height! > 0);

  CanvasPlacement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    bool clearWidth = false,
    bool clearHeight = false,
    int? zIndex,
    String? containerId,
    bool clearContainerId = false,
    bool? locked,
  }) => CanvasPlacement(
    blockId: blockId,
    x: x ?? this.x,
    y: y ?? this.y,
    width: clearWidth ? null : width ?? this.width,
    height: clearHeight ? null : height ?? this.height,
    zIndex: zIndex ?? this.zIndex,
    containerId: clearContainerId ? null : containerId ?? this.containerId,
    locked: locked ?? this.locked,
  );

  JsonMap toJson() => {
    'blockId': blockId,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'zIndex': zIndex,
    'containerId': containerId,
    'locked': locked,
  };

  factory CanvasPlacement.fromJson(Object? value) {
    final json = _map(value);
    final placement = CanvasPlacement(
      blockId: json['blockId'] as String? ?? generateUuid(),
      x: _finiteDouble(json['x']),
      y: _finiteDouble(json['y']),
      width: _positiveDouble(json['width']),
      height: _positiveDouble(json['height']),
      zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
      containerId: json['containerId'] as String?,
      locked: json['locked'] as bool? ?? false,
    );
    return placement;
  }
}

class CanvasConnector {
  const CanvasConnector({
    required this.id,
    required this.sourceBlockId,
    required this.targetBlockId,
    this.kind = CanvasConnectorKind.straight,
    this.label,
  });

  final Uuid id;
  final Uuid sourceBlockId;
  final Uuid targetBlockId;
  final CanvasConnectorKind kind;
  final String? label;

  JsonMap toJson() => {
    'id': id,
    'sourceBlockId': sourceBlockId,
    'targetBlockId': targetBlockId,
    'kind': kind.name,
    'label': label,
  };

  factory CanvasConnector.fromJson(Object? value) {
    final json = _map(value);
    return CanvasConnector(
      id: json['id'] as String? ?? generateUuid(),
      sourceBlockId: json['sourceBlockId'] as String? ?? '',
      targetBlockId: json['targetBlockId'] as String? ?? '',
      kind: CanvasConnectorKind.values.firstWhere(
        (kind) => kind.name == json['kind'],
        orElse: () => CanvasConnectorKind.straight,
      ),
      label: json['label'] as String?,
    );
  }
}

class CanvasFrame {
  const CanvasFrame({
    required this.id,
    required this.title,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.zIndex,
  });

  final Uuid id;
  final String title;
  final double x;
  final double y;
  final double width;
  final double height;
  final int zIndex;

  SpatialRect get bounds => SpatialRect.fromLTWH(x, y, width, height);

  JsonMap toJson() => {
    'id': id,
    'title': title,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'zIndex': zIndex,
  };

  factory CanvasFrame.fromJson(Object? value) {
    final json = _map(value);
    return CanvasFrame(
      id: json['id'] as String? ?? generateUuid(),
      title: json['title'] as String? ?? 'Marco',
      x: _finiteDouble(json['x']),
      y: _finiteDouble(json['y']),
      width: _positiveDouble(json['width']) ?? 720,
      height: _positiveDouble(json['height']) ?? 480,
      zIndex: (json['zIndex'] as num?)?.toInt() ?? -1,
    );
  }
}

class CanvasLayoutState {
  const CanvasLayoutState({
    required this.placements,
    this.connectors = const [],
    this.frames = const [],
    this.showGrid = true,
    this.snapToGrid = true,
    this.gridSize = 24,
  });

  final List<CanvasPlacement> placements;
  final List<CanvasConnector> connectors;
  final List<CanvasFrame> frames;
  final bool showGrid;
  final bool snapToGrid;
  final double gridSize;

  CanvasPlacement? placementFor(String blockId) {
    for (final placement in placements) {
      if (placement.blockId == blockId) return placement;
    }
    return null;
  }

  int get topZIndex =>
      placements.fold(0, (value, item) => math.max(value, item.zIndex));

  CanvasLayoutState copyWith({
    List<CanvasPlacement>? placements,
    List<CanvasConnector>? connectors,
    List<CanvasFrame>? frames,
    bool? showGrid,
    bool? snapToGrid,
    double? gridSize,
  }) => CanvasLayoutState(
    placements: placements ?? this.placements,
    connectors: connectors ?? this.connectors,
    frames: frames ?? this.frames,
    showGrid: showGrid ?? this.showGrid,
    snapToGrid: snapToGrid ?? this.snapToGrid,
    gridSize: gridSize ?? this.gridSize,
  );

  CanvasLayoutState normalizedFor(List<BaseBlock> blocks) {
    final ids = blocks.map((block) => block.id).toSet();
    final frameIds = frames.map((frame) => frame.id).toSet();
    final byId = {
      for (final placement in placements) placement.blockId: placement,
    };
    final normalized = <CanvasPlacement>[];
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      final existing = byId[block.id];
      final placement = existing != null && existing.isValid
          ? existing
          : _defaultPlacement(block, index);
      normalized.add(
        placement.containerId == null ||
                frameIds.contains(placement.containerId)
            ? placement
            : placement.copyWith(clearContainerId: true),
      );
    }
    return copyWith(
      placements: normalized,
      connectors: connectors
          .where(
            (connector) =>
                ids.contains(connector.sourceBlockId) &&
                ids.contains(connector.targetBlockId) &&
                connector.sourceBlockId != connector.targetBlockId,
          )
          .toList(growable: false),
    );
  }

  JsonMap toJson() => {
    'placements': placements
        .map((item) => item.toJson())
        .toList(growable: false),
    'connectors': connectors
        .map((item) => item.toJson())
        .toList(growable: false),
    'frames': frames.map((item) => item.toJson()).toList(growable: false),
    'showGrid': showGrid,
    'snapToGrid': snapToGrid,
    'gridSize': gridSize,
  };

  factory CanvasLayoutState.fromJson(Object? value) {
    final json = _map(value);
    final gridSize = _positiveDouble(json['gridSize']) ?? 24;
    return CanvasLayoutState(
      placements: _list(
        json['placements'],
      ).map(CanvasPlacement.fromJson).where((item) => item.isValid).toList(),
      connectors: _list(
        json['connectors'],
      ).map(CanvasConnector.fromJson).toList(),
      frames: _list(json['frames']).map(CanvasFrame.fromJson).toList(),
      showGrid: json['showGrid'] as bool? ?? true,
      snapToGrid: json['snapToGrid'] as bool? ?? true,
      gridSize: gridSize,
    );
  }

  factory CanvasLayoutState.forBlocks(List<BaseBlock> blocks) =>
      CanvasLayoutState(
        placements: [
          for (var index = 0; index < blocks.length; index++)
            _defaultPlacement(blocks[index], index),
        ],
      );

  static CanvasPlacement _defaultPlacement(BaseBlock block, int index) {
    final column = index % 3;
    final row = index ~/ 3;
    final geometry = block.geometry;
    final hasPosition = geometry.x != 0 || geometry.y != 0;
    return CanvasPlacement(
      blockId: block.id,
      x: hasPosition ? geometry.x : 160 + column * 420,
      y: hasPosition ? geometry.y : 120 + row * 220,
      width: geometry.width ?? 360,
      height: geometry.height,
      zIndex: geometry.layer == 0 ? index : geometry.layer,
      locked: block.isLocked,
    );
  }
}

class CanvasSpatialIndex {
  CanvasSpatialIndex(Iterable<CanvasPlacement> placements)
    : _placements = List.unmodifiable(placements);

  final List<CanvasPlacement> _placements;

  List<String> intersecting(SpatialRect bounds) => _placements
      .where((placement) => placement.bounds().overlaps(bounds))
      .map((placement) => placement.blockId)
      .toList(growable: false);

  CanvasPlacement? hitTest(SpatialPoint point) {
    final matches =
        _placements
            .where((placement) => placement.bounds().contains(point))
            .toList()
          ..sort((first, second) => second.zIndex.compareTo(first.zIndex));
    return matches.firstOrNull;
  }
}

JsonMap _map(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : <String, Object?>{};

List<Object?> _list(Object? value) =>
    value is List ? List<Object?>.from(value) : const [];

double _finiteDouble(Object? value, [double fallback = 0]) {
  final result = (value as num?)?.toDouble();
  return result != null && result.isFinite ? result : fallback;
}

double? _positiveDouble(Object? value) {
  final result = (value as num?)?.toDouble();
  return result != null && result.isFinite && result > 0 ? result : null;
}
