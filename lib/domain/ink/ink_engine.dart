import 'dart:math' as math;

import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/ink/ink_models.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';

typedef InkPointResolver =
    SpatialPoint Function(InkElement element, SpatialPoint storedPoint);

class InkProcessor {
  const InkProcessor();

  /// A light Ramer-Douglas-Peucker pass runs only at commit. Preview keeps the
  /// original input stream so pointer updates remain inexpensive.
  List<InkPoint> simplify(
    List<InkPoint> points, {
    required InkBrushStyle brush,
    double zoom = 1,
  }) {
    if (points.length <= 2) return List.unmodifiable(points);
    final profileFactor = switch (brush.smoothingProfile) {
      InkSmoothingProfile.precise => .12,
      InkSmoothingProfile.balanced => .22,
      InkSmoothingProfile.smooth => .36,
    };
    final safeZoom = zoom.isFinite && zoom > 0 ? zoom : 1;
    final tolerance = math.max(
      .08,
      math.min(1.4, brush.baseWidth * profileFactor / safeZoom),
    );
    final kept = _rdp(points, tolerance);
    return List.unmodifiable(
      kept.length >= 2 ? kept : [points.first, points.last],
    );
  }

  InkStroke? createStroke({
    required String surfaceId,
    required List<InkPoint> points,
    required InkBrushStyle brush,
    AnnotationAnchor? anchor,
    int zOrder = 0,
    double zoom = 1,
    DateTime? now,
  }) {
    final committed = simplify(points, brush: brush, zoom: zoom)
        .where((point) => !point.isPredicted && point.isValid)
        .take(InkStroke.maxPointCount)
        .toList(growable: false);
    if (committed.length < 2) return null;
    final timestamp = now ?? DateTime.now().toUtc();
    final stroke = InkStroke(
      id: generateUuid(),
      surfaceId: surfaceId,
      brush: brush.normalized,
      points: committed,
      anchor: anchor,
      zOrder: zOrder,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    return stroke.isValid ? stroke : null;
  }

  InkShape? createShape({
    required String surfaceId,
    required InkShapeKind kind,
    required SpatialPoint start,
    required SpatialPoint end,
    required InkBrushStyle brush,
    AnnotationAnchor? anchor,
    int zOrder = 0,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now().toUtc();
    final shape = InkShape(
      id: generateUuid(),
      surfaceId: surfaceId,
      kind: kind,
      start: start,
      end: end,
      brush: brush.copyWith(kind: InkBrushKind.shape),
      anchor: anchor,
      zOrder: zOrder,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    return shape.isValid ? shape : null;
  }

  List<InkPoint> _rdp(List<InkPoint> points, double tolerance) {
    var farthest = 0.0;
    var index = 0;
    final start = points.first.workspacePosition;
    final end = points.last.workspacePosition;
    for (var current = 1; current < points.length - 1; current++) {
      final distance = _distanceToSegment(
        points[current].workspacePosition,
        start,
        end,
      );
      if (distance > farthest) {
        index = current;
        farthest = distance;
      }
    }
    if (farthest <= tolerance) return [points.first, points.last];
    final left = _rdp(points.sublist(0, index + 1), tolerance);
    final right = _rdp(points.sublist(index), tolerance);
    return [...left.take(left.length - 1), ...right];
  }
}

class InkSpatialIndex {
  InkSpatialIndex(Iterable<InkElement> elements)
    : _elements = List.unmodifiable(
        elements.where((element) => element.isVisible),
      );

  final List<InkElement> _elements;

  List<String> hitTest(
    SpatialPoint point, {
    required double tolerance,
    InkPointResolver? resolvePoint,
  }) {
    final resolver = resolvePoint ?? (_, stored) => stored;
    final matches = <InkElement>[];
    for (final element in _elements) {
      if (element.isLocked) continue;
      if (_hits(element, point, tolerance, resolver)) matches.add(element);
    }
    matches.sort((first, second) => second.zOrder.compareTo(first.zOrder));
    return matches.map((element) => element.id).toList(growable: false);
  }

  List<String> insideLasso(
    List<SpatialPoint> polygon, {
    InkPointResolver? resolvePoint,
  }) {
    if (polygon.length < 3) return const [];
    final resolver = resolvePoint ?? (_, stored) => stored;
    final selected = <String>[];
    for (final element in _elements) {
      if (element.isLocked) continue;
      final samples = _samplePoints(
        element,
      ).map((point) => resolver(element, point));
      if (samples.any((point) => _pointInPolygon(point, polygon))) {
        selected.add(element.id);
      }
    }
    return selected;
  }

  List<InkElement> visibleIn(
    SpatialRect bounds, {
    InkPointResolver? resolvePoint,
  }) {
    final resolver = resolvePoint ?? (_, stored) => stored;
    return _elements
        .where((element) {
          final points = _samplePoints(
            element,
          ).map((point) => resolver(element, point));
          return _bounds(points, element.brush.baseWidth / 2).overlaps(bounds);
        })
        .toList(growable: false);
  }

  bool _hits(
    InkElement element,
    SpatialPoint point,
    double tolerance,
    InkPointResolver resolver,
  ) {
    final margin = tolerance + element.brush.baseWidth / 2;
    if (element is InkStroke) {
      final points = element.points
          .map((item) => resolver(element, item.workspacePosition))
          .toList();
      for (var index = 1; index < points.length; index++) {
        if (_distanceToSegment(point, points[index - 1], points[index]) <=
            margin) {
          return true;
        }
      }
      return false;
    }
    final shape = element as InkShape;
    final start = resolver(shape, shape.start);
    final end = resolver(shape, shape.end);
    if (shape.kind == InkShapeKind.line || shape.kind == InkShapeKind.arrow) {
      return _distanceToSegment(point, start, end) <= margin;
    }
    final rect = _normalizedRect(start, end);
    if (shape.kind == InkShapeKind.rectangle) {
      final edges = [
        (rect.topLeft, SpatialPoint(rect.right, rect.top)),
        (
          SpatialPoint(rect.right, rect.top),
          SpatialPoint(rect.right, rect.bottom),
        ),
        (
          SpatialPoint(rect.right, rect.bottom),
          SpatialPoint(rect.left, rect.bottom),
        ),
        (SpatialPoint(rect.left, rect.bottom), rect.topLeft),
      ];
      return edges.any(
        (edge) => _distanceToSegment(point, edge.$1, edge.$2) <= margin,
      );
    }
    if (rect.width <= 0 || rect.height <= 0) return false;
    final center = rect.center;
    final rx = rect.width / 2;
    final ry = rect.height / 2;
    final normalized = math.sqrt(
      math.pow((point.x - center.x) / rx, 2) +
          math.pow((point.y - center.y) / ry, 2),
    );
    return (normalized - 1).abs() <= margin / math.max(rx, ry);
  }
}

Iterable<SpatialPoint> _samplePoints(InkElement element) => switch (element) {
  InkStroke(:final points) => points.map((point) => point.workspacePosition),
  InkShape(:final start, :final end) => [
    start,
    end,
    SpatialPoint((start.x + end.x) / 2, (start.y + end.y) / 2),
  ],
};

double _distanceToSegment(
  SpatialPoint point,
  SpatialPoint start,
  SpatialPoint end,
) {
  final dx = end.x - start.x;
  final dy = end.y - start.y;
  if (dx == 0 && dy == 0) {
    return math.sqrt(
      math.pow(point.x - start.x, 2) + math.pow(point.y - start.y, 2),
    );
  }
  final t =
      (((point.x - start.x) * dx + (point.y - start.y) * dy) /
              (dx * dx + dy * dy))
          .clamp(0, 1)
          .toDouble();
  final closest = SpatialPoint(start.x + t * dx, start.y + t * dy);
  return math.sqrt(
    math.pow(point.x - closest.x, 2) + math.pow(point.y - closest.y, 2),
  );
}

SpatialRect _bounds(Iterable<SpatialPoint> points, double padding) {
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

SpatialRect _normalizedRect(SpatialPoint first, SpatialPoint second) =>
    SpatialRect.fromLTRB(
      math.min(first.x, second.x),
      math.min(first.y, second.y),
      math.max(first.x, second.x),
      math.max(first.y, second.y),
    );

bool _pointInPolygon(SpatialPoint point, List<SpatialPoint> polygon) {
  var inside = false;
  for (
    var first = 0, second = polygon.length - 1;
    first < polygon.length;
    second = first++
  ) {
    final a = polygon[first];
    final b = polygon[second];
    final intersects =
        (a.y > point.y) != (b.y > point.y) &&
        point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x;
    if (intersects) inside = !inside;
  }
  return inside;
}
