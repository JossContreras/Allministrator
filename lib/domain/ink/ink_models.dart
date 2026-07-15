import 'dart:math' as math;

import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';

enum InkBrushKind { pen, highlighter, eraserPreview, shape }

enum InkSmoothingProfile { precise, balanced, smooth }

enum InkBlendMode { sourceOver, multiply }

enum InkStrokeCap { round, square }

enum InkStrokeJoin { round, bevel }

enum InkShapeKind { line, arrow, rectangle, ellipse }

enum AnnotationAnchorKind {
  freeCanvas,
  blockRelative,
  imageRelative,
  documentPageRelative,
}

/// When an anchored target disappears, ink remains at its last absolute
/// coordinates and becomes free ink. This avoids silent data loss.
enum OrphanedAnnotationPolicy { convertToFreeCanvas }

class InkPoint {
  const InkPoint({
    required this.workspacePosition,
    required this.timestamp,
    this.pressure,
    this.tiltX,
    this.tiltY,
    this.azimuth,
    this.isPredicted = false,
    this.isCoalesced = false,
  });

  final SpatialPoint workspacePosition;
  final Duration timestamp;
  final double? pressure;
  final double? tiltX;
  final double? tiltY;
  final double? azimuth;
  final bool isPredicted;
  final bool isCoalesced;

  bool get isValid =>
      workspacePosition.x.isFinite &&
      workspacePosition.y.isFinite &&
      timestamp >= Duration.zero &&
      _optionalFinite(pressure) &&
      _optionalFinite(tiltX) &&
      _optionalFinite(tiltY) &&
      _optionalFinite(azimuth);

  InkPoint translated(SpatialPoint delta) => InkPoint(
    workspacePosition: workspacePosition + delta,
    timestamp: timestamp,
    pressure: pressure,
    tiltX: tiltX,
    tiltY: tiltY,
    azimuth: azimuth,
    isPredicted: isPredicted,
    isCoalesced: isCoalesced,
  );

  JsonMap toJson() => {
    'x': workspacePosition.x,
    'y': workspacePosition.y,
    'timestampMicros': timestamp.inMicroseconds,
    if (pressure != null) 'pressure': pressure,
    if (tiltX != null) 'tiltX': tiltX,
    if (tiltY != null) 'tiltY': tiltY,
    if (azimuth != null) 'azimuth': azimuth,
  };

  factory InkPoint.fromJson(Object? value) {
    final json = _map(value);
    final pressure = _finiteOrNull(json['pressure']);
    return InkPoint(
      workspacePosition: SpatialPoint(_finite(json['x']), _finite(json['y'])),
      timestamp: Duration(
        microseconds: math.max(
          0,
          (json['timestampMicros'] as num?)?.toInt() ?? 0,
        ),
      ),
      pressure: pressure?.clamp(0, 1).toDouble(),
      tiltX: _finiteOrNull(json['tiltX']),
      tiltY: _finiteOrNull(json['tiltY']),
      azimuth: _finiteOrNull(json['azimuth']),
    );
  }
}

class InkBrushStyle {
  const InkBrushStyle({
    required this.kind,
    required this.color,
    required this.baseWidth,
    required this.opacity,
    this.pressureEnabled = true,
    this.smoothingProfile = InkSmoothingProfile.balanced,
    this.blendMode = InkBlendMode.sourceOver,
    this.cap = InkStrokeCap.round,
    this.join = InkStrokeJoin.round,
  });

  factory InkBrushStyle.pen({
    int color = 0xFF1F2937,
    double width = 3,
    double opacity = 1,
  }) => InkBrushStyle(
    kind: InkBrushKind.pen,
    color: color,
    baseWidth: width,
    opacity: opacity,
  );

  factory InkBrushStyle.highlighter({
    int color = 0xFFFFD54F,
    double width = 16,
    double opacity = .32,
  }) => InkBrushStyle(
    kind: InkBrushKind.highlighter,
    color: color,
    baseWidth: width,
    opacity: opacity,
    pressureEnabled: false,
    smoothingProfile: InkSmoothingProfile.smooth,
    blendMode: InkBlendMode.multiply,
  );

  factory InkBrushStyle.shape({
    int color = 0xFF2563EB,
    double width = 3,
    double opacity = 1,
  }) => InkBrushStyle(
    kind: InkBrushKind.shape,
    color: color,
    baseWidth: width,
    opacity: opacity,
    pressureEnabled: false,
    smoothingProfile: InkSmoothingProfile.precise,
  );

  final InkBrushKind kind;
  final int color;
  final double baseWidth;
  final double opacity;
  final bool pressureEnabled;
  final InkSmoothingProfile smoothingProfile;
  final InkBlendMode blendMode;
  final InkStrokeCap cap;
  final InkStrokeJoin join;

  InkBrushStyle get normalized => InkBrushStyle(
    kind: kind,
    color: color & 0xFFFFFFFF,
    baseWidth: baseWidth.isFinite ? baseWidth.clamp(.5, 96).toDouble() : 3,
    opacity: opacity.isFinite ? opacity.clamp(.05, 1).toDouble() : 1,
    pressureEnabled: pressureEnabled,
    smoothingProfile: smoothingProfile,
    blendMode: blendMode,
    cap: cap,
    join: join,
  );

  InkBrushStyle copyWith({
    InkBrushKind? kind,
    int? color,
    double? baseWidth,
    double? opacity,
    bool? pressureEnabled,
    InkSmoothingProfile? smoothingProfile,
    InkBlendMode? blendMode,
    InkStrokeCap? cap,
    InkStrokeJoin? join,
  }) => InkBrushStyle(
    kind: kind ?? this.kind,
    color: color ?? this.color,
    baseWidth: baseWidth ?? this.baseWidth,
    opacity: opacity ?? this.opacity,
    pressureEnabled: pressureEnabled ?? this.pressureEnabled,
    smoothingProfile: smoothingProfile ?? this.smoothingProfile,
    blendMode: blendMode ?? this.blendMode,
    cap: cap ?? this.cap,
    join: join ?? this.join,
  ).normalized;

  JsonMap toJson() => {
    'kind': kind.name,
    'color': color,
    'baseWidth': baseWidth,
    'opacity': opacity,
    'pressureEnabled': pressureEnabled,
    'smoothingProfile': smoothingProfile.name,
    'blendMode': blendMode.name,
    'cap': cap.name,
    'join': join.name,
  };

  factory InkBrushStyle.fromJson(Object? value) {
    final json = _map(value);
    return InkBrushStyle(
      kind: _enumValue(InkBrushKind.values, json['kind'], InkBrushKind.pen),
      color: (json['color'] as num?)?.toInt() ?? 0xFF1F2937,
      baseWidth: _finite(json['baseWidth'], 3),
      opacity: _finite(json['opacity'], 1),
      pressureEnabled: json['pressureEnabled'] as bool? ?? true,
      smoothingProfile: _enumValue(
        InkSmoothingProfile.values,
        json['smoothingProfile'],
        InkSmoothingProfile.balanced,
      ),
      blendMode: _enumValue(
        InkBlendMode.values,
        json['blendMode'],
        InkBlendMode.sourceOver,
      ),
      cap: _enumValue(InkStrokeCap.values, json['cap'], InkStrokeCap.round),
      join: _enumValue(InkStrokeJoin.values, json['join'], InkStrokeJoin.round),
    ).normalized;
  }
}

class AnnotationAnchor {
  const AnnotationAnchor({
    required this.kind,
    this.targetId,
    this.referenceBounds,
  });

  const AnnotationAnchor.freeCanvas()
    : kind = AnnotationAnchorKind.freeCanvas,
      targetId = null,
      referenceBounds = null;

  final AnnotationAnchorKind kind;
  final Uuid? targetId;
  final SpatialRect? referenceBounds;

  bool get isValid => switch (kind) {
    AnnotationAnchorKind.freeCanvas => true,
    _ =>
      targetId != null &&
          targetId!.isNotEmpty &&
          referenceBounds != null &&
          !referenceBounds!.isEmpty,
  };

  SpatialPoint resolve(SpatialPoint stored, SpatialRect? currentTargetBounds) {
    final reference = referenceBounds;
    if (kind == AnnotationAnchorKind.freeCanvas ||
        reference == null ||
        reference.isEmpty ||
        currentTargetBounds == null ||
        currentTargetBounds.isEmpty) {
      return stored;
    }
    final xRatio = (stored.x - reference.left) / reference.width;
    final yRatio = (stored.y - reference.top) / reference.height;
    return SpatialPoint(
      currentTargetBounds.left + xRatio * currentTargetBounds.width,
      currentTargetBounds.top + yRatio * currentTargetBounds.height,
    );
  }

  JsonMap toJson() => {
    'kind': kind.name,
    if (targetId != null) 'targetId': targetId,
    if (referenceBounds != null)
      'referenceBounds': {
        'left': referenceBounds!.left,
        'top': referenceBounds!.top,
        'right': referenceBounds!.right,
        'bottom': referenceBounds!.bottom,
      },
  };

  factory AnnotationAnchor.fromJson(Object? value) {
    final json = _map(value);
    final rawBounds = _map(json['referenceBounds']);
    final bounds = rawBounds.isEmpty
        ? null
        : SpatialRect.fromLTRB(
            _finite(rawBounds['left']),
            _finite(rawBounds['top']),
            _finite(rawBounds['right']),
            _finite(rawBounds['bottom']),
          );
    final anchor = AnnotationAnchor(
      kind: _enumValue(
        AnnotationAnchorKind.values,
        json['kind'],
        AnnotationAnchorKind.freeCanvas,
      ),
      targetId: json['targetId'] as String?,
      referenceBounds: bounds,
    );
    return anchor.isValid ? anchor : const AnnotationAnchor.freeCanvas();
  }
}

sealed class InkElement {
  const InkElement();

  Uuid get id;
  InkBrushStyle get brush;
  AnnotationAnchor? get anchor;
  int get zOrder;
  bool get isVisible;
  bool get isLocked;
  DateTime get createdAt;
  DateTime get updatedAt;
  SpatialRect get bounds;

  InkElement translated(SpatialPoint delta, {required DateTime updatedAt});
  InkElement withBrush(InkBrushStyle style, {required DateTime updatedAt});
  InkElement withAnchor(AnnotationAnchor? anchor);
  InkElement duplicate({required Uuid id, required SpatialPoint delta});
  JsonMap toJson();
}

class InkStroke extends InkElement {
  const InkStroke({
    required this.id,
    required this.surfaceId,
    required this.brush,
    required this.points,
    this.anchor,
    this.zOrder = 0,
    this.isVisible = true,
    this.isLocked = false,
    required this.createdAt,
    required this.updatedAt,
  });

  static const maxPointCount = 20000;

  @override
  final Uuid id;
  final Uuid surfaceId;
  @override
  final InkBrushStyle brush;
  final List<InkPoint> points;
  @override
  final AnnotationAnchor? anchor;
  @override
  final int zOrder;
  @override
  final bool isVisible;
  @override
  final bool isLocked;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  bool get isValid =>
      id.isNotEmpty &&
      surfaceId.isNotEmpty &&
      points.length >= 2 &&
      points.length <= maxPointCount &&
      points.every((point) => point.isValid);

  @override
  SpatialRect get bounds => _boundsForPoints(
    points.map((point) => point.workspacePosition),
    padding: brush.baseWidth / 2,
  );

  InkStroke copyWith({
    InkBrushStyle? brush,
    List<InkPoint>? points,
    AnnotationAnchor? anchor,
    bool clearAnchor = false,
    int? zOrder,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
  }) => InkStroke(
    id: id,
    surfaceId: surfaceId,
    brush: brush ?? this.brush,
    points: points ?? this.points,
    anchor: clearAnchor ? null : anchor ?? this.anchor,
    zOrder: zOrder ?? this.zOrder,
    isVisible: isVisible ?? this.isVisible,
    isLocked: isLocked ?? this.isLocked,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  InkStroke translated(SpatialPoint delta, {required DateTime updatedAt}) =>
      copyWith(
        points: points.map((point) => point.translated(delta)).toList(),
        updatedAt: updatedAt,
      );

  @override
  InkStroke withBrush(InkBrushStyle style, {required DateTime updatedAt}) =>
      copyWith(brush: style.normalized, updatedAt: updatedAt);

  @override
  InkStroke withAnchor(AnnotationAnchor? anchor) =>
      copyWith(anchor: anchor, clearAnchor: anchor == null);

  @override
  InkStroke duplicate({required Uuid id, required SpatialPoint delta}) {
    final now = DateTime.now().toUtc();
    return InkStroke(
      id: id,
      surfaceId: surfaceId,
      brush: brush,
      points: points.map((point) => point.translated(delta)).toList(),
      anchor: anchor,
      zOrder: zOrder + 1,
      isVisible: true,
      isLocked: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  JsonMap toJson() => {
    'entityType': 'stroke',
    'formatVersion': 1,
    'id': id,
    'surfaceId': surfaceId,
    'brush': brush.toJson(),
    'points': points
        .where((point) => !point.isPredicted)
        .map((point) => point.toJson())
        .toList(growable: false),
    if (anchor != null) 'anchor': anchor!.toJson(),
    'zOrder': zOrder,
    'isVisible': isVisible,
    'isLocked': isLocked,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory InkStroke.fromJson(Object? value) {
    final json = _map(value);
    final createdAt = _date(json['createdAt']);
    final points = _list(json['points'])
        .take(maxPointCount)
        .map(InkPoint.fromJson)
        .where((point) => point.isValid)
        .toList(growable: false);
    return InkStroke(
      id: json['id'] as String? ?? generateUuid(),
      surfaceId: json['surfaceId'] as String? ?? '',
      brush: InkBrushStyle.fromJson(json['brush']),
      points: points,
      anchor: json['anchor'] is Map
          ? AnnotationAnchor.fromJson(json['anchor'])
          : null,
      zOrder: (json['zOrder'] as num?)?.toInt() ?? 0,
      isVisible: json['isVisible'] as bool? ?? true,
      isLocked: json['isLocked'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt: _date(json['updatedAt'], createdAt),
    );
  }
}

class InkShape extends InkElement {
  const InkShape({
    required this.id,
    required this.surfaceId,
    required this.kind,
    required this.start,
    required this.end,
    required this.brush,
    this.anchor,
    this.zOrder = 0,
    this.isVisible = true,
    this.isLocked = false,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  final Uuid id;
  final Uuid surfaceId;
  final InkShapeKind kind;
  final SpatialPoint start;
  final SpatialPoint end;
  @override
  final InkBrushStyle brush;
  @override
  final AnnotationAnchor? anchor;
  @override
  final int zOrder;
  @override
  final bool isVisible;
  @override
  final bool isLocked;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  bool get isValid =>
      id.isNotEmpty &&
      surfaceId.isNotEmpty &&
      start.x.isFinite &&
      start.y.isFinite &&
      end.x.isFinite &&
      end.y.isFinite &&
      (end.x - start.x).abs() + (end.y - start.y).abs() >= .5;

  @override
  SpatialRect get bounds => _boundsForPoints(
    [start, end],
    padding: math.max(brush.baseWidth / 2, kind == InkShapeKind.arrow ? 8 : 0),
  );

  InkShape copyWith({
    SpatialPoint? start,
    SpatialPoint? end,
    InkBrushStyle? brush,
    AnnotationAnchor? anchor,
    bool clearAnchor = false,
    int? zOrder,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
  }) => InkShape(
    id: id,
    surfaceId: surfaceId,
    kind: kind,
    start: start ?? this.start,
    end: end ?? this.end,
    brush: brush ?? this.brush,
    anchor: clearAnchor ? null : anchor ?? this.anchor,
    zOrder: zOrder ?? this.zOrder,
    isVisible: isVisible ?? this.isVisible,
    isLocked: isLocked ?? this.isLocked,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  InkShape translated(SpatialPoint delta, {required DateTime updatedAt}) =>
      copyWith(start: start + delta, end: end + delta, updatedAt: updatedAt);

  @override
  InkShape withBrush(InkBrushStyle style, {required DateTime updatedAt}) =>
      copyWith(brush: style.normalized, updatedAt: updatedAt);

  @override
  InkShape withAnchor(AnnotationAnchor? anchor) =>
      copyWith(anchor: anchor, clearAnchor: anchor == null);

  @override
  InkShape duplicate({required Uuid id, required SpatialPoint delta}) {
    final now = DateTime.now().toUtc();
    return InkShape(
      id: id,
      surfaceId: surfaceId,
      kind: kind,
      start: start + delta,
      end: end + delta,
      brush: brush,
      anchor: anchor,
      zOrder: zOrder + 1,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  JsonMap toJson() => {
    'entityType': 'shape',
    'formatVersion': 1,
    'id': id,
    'surfaceId': surfaceId,
    'kind': kind.name,
    'start': {'x': start.x, 'y': start.y},
    'end': {'x': end.x, 'y': end.y},
    'brush': brush.toJson(),
    if (anchor != null) 'anchor': anchor!.toJson(),
    'zOrder': zOrder,
    'isVisible': isVisible,
    'isLocked': isLocked,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory InkShape.fromJson(Object? value) {
    final json = _map(value);
    final createdAt = _date(json['createdAt']);
    final start = _map(json['start']);
    final end = _map(json['end']);
    return InkShape(
      id: json['id'] as String? ?? generateUuid(),
      surfaceId: json['surfaceId'] as String? ?? '',
      kind: _enumValue(InkShapeKind.values, json['kind'], InkShapeKind.line),
      start: SpatialPoint(_finite(start['x']), _finite(start['y'])),
      end: SpatialPoint(_finite(end['x']), _finite(end['y'])),
      brush: InkBrushStyle.fromJson(json['brush']),
      anchor: json['anchor'] is Map
          ? AnnotationAnchor.fromJson(json['anchor'])
          : null,
      zOrder: (json['zOrder'] as num?)?.toInt() ?? 0,
      isVisible: json['isVisible'] as bool? ?? true,
      isLocked: json['isLocked'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt: _date(json['updatedAt'], createdAt),
    );
  }
}

class InkLayerState {
  const InkLayerState({
    this.formatVersion = 1,
    this.elements = const [],
    this.orphanedAnnotationPolicy =
        OrphanedAnnotationPolicy.convertToFreeCanvas,
  });

  static const maxElementCount = 10000;

  final int formatVersion;
  final List<InkElement> elements;
  final OrphanedAnnotationPolicy orphanedAnnotationPolicy;

  List<InkStroke> get strokes => elements.whereType<InkStroke>().toList();
  List<InkShape> get shapes => elements.whereType<InkShape>().toList();
  int get topZOrder =>
      elements.fold(0, (top, item) => math.max(top, item.zOrder));

  InkElement? elementById(String id) {
    for (final element in elements) {
      if (element.id == id) return element;
    }
    return null;
  }

  InkLayerState copyWith({
    List<InkElement>? elements,
    OrphanedAnnotationPolicy? orphanedAnnotationPolicy,
  }) => InkLayerState(
    formatVersion: formatVersion,
    elements: elements ?? this.elements,
    orphanedAnnotationPolicy:
        orphanedAnnotationPolicy ?? this.orphanedAnnotationPolicy,
  );

  InkLayerState normalizedForBlockIds(Set<String> blockIds) => copyWith(
    elements: [
      for (final element in elements)
        if (element.anchor?.targetId case final targetId?)
          blockIds.contains(targetId) ? element : element.withAnchor(null)
        else
          element,
    ],
  );

  JsonMap toJson() => {
    'formatVersion': formatVersion,
    'orphanedAnnotationPolicy': orphanedAnnotationPolicy.name,
    'elements': elements.map((item) => item.toJson()).toList(growable: false),
  };

  factory InkLayerState.fromJson(Object? value) {
    final json = _map(value);
    final elements = <InkElement>[];
    for (final raw in _list(json['elements']).take(maxElementCount)) {
      final map = _map(raw);
      final InkElement? element = switch (map['entityType']) {
        'stroke' => InkStroke.fromJson(map),
        'shape' => InkShape.fromJson(map),
        _ => null,
      };
      if (element is InkStroke && element.isValid ||
          element is InkShape && element.isValid) {
        elements.add(element!);
      }
    }
    elements.sort((first, second) => first.zOrder.compareTo(second.zOrder));
    return InkLayerState(
      formatVersion: math.max(1, (json['formatVersion'] as num?)?.toInt() ?? 1),
      elements: elements,
      orphanedAnnotationPolicy: _enumValue(
        OrphanedAnnotationPolicy.values,
        json['orphanedAnnotationPolicy'],
        OrphanedAnnotationPolicy.convertToFreeCanvas,
      ),
    );
  }
}

SpatialRect _boundsForPoints(
  Iterable<SpatialPoint> points, {
  double padding = 0,
}) {
  final values = points.toList();
  if (values.isEmpty) return SpatialRect.zero;
  var left = values.first.x;
  var top = values.first.y;
  var right = values.first.x;
  var bottom = values.first.y;
  for (final point in values.skip(1)) {
    left = math.min(left, point.x);
    top = math.min(top, point.y);
    right = math.max(right, point.x);
    bottom = math.max(bottom, point.y);
  }
  return SpatialRect.fromLTRB(
    left - padding,
    top - padding,
    right + padding,
    bottom + padding,
  );
}

bool _optionalFinite(double? value) => value == null || value.isFinite;
JsonMap _map(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : <String, Object?>{};
List<Object?> _list(Object? value) =>
    value is List ? List<Object?>.from(value) : const [];
double _finite(Object? value, [double fallback = 0]) {
  final result = (value as num?)?.toDouble();
  return result != null && result.isFinite ? result : fallback;
}

double? _finiteOrNull(Object? value) {
  final result = (value as num?)?.toDouble();
  return result != null && result.isFinite ? result : null;
}

DateTime _date(Object? value, [DateTime? fallback]) =>
    DateTime.tryParse(value as String? ?? '')?.toUtc() ??
    fallback ??
    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}
