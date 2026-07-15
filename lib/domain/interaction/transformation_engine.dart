import 'dart:math' as math;

import 'package:allministrator/domain/interaction/interaction_models.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';

enum ResizeHandle { east, south, southEast }

enum SmartGuideAxis { horizontal, vertical }

class SmartGuide {
  const SmartGuide({required this.axis, required this.position});

  final SmartGuideAxis axis;
  final double position;
}

class ResizeResolution {
  const ResizeResolution({required this.bounds, this.guides = const []});

  final SpatialRect bounds;
  final List<SmartGuide> guides;
}

class ResizeSession extends InteractionSession {
  ResizeSession({
    required super.id,
    required super.startedAt,
    required super.blockId,
    required this.pointerId,
    required this.handle,
    required this.startPosition,
    required this.currentPosition,
    required this.initialBounds,
    required this.previewBounds,
    this.guides = const [],
  }) : super(type: InteractionSessionType.resize, hasPendingChanges: true);

  final int pointerId;
  final ResizeHandle handle;
  final SpatialPoint startPosition;
  final SpatialPoint currentPosition;
  final SpatialRect initialBounds;
  final SpatialRect previewBounds;
  final List<SmartGuide> guides;

  ResizeSession copyWith({
    SpatialPoint? currentPosition,
    SpatialRect? previewBounds,
    List<SmartGuide>? guides,
  }) => ResizeSession(
    id: id,
    startedAt: startedAt,
    blockId: blockId,
    pointerId: pointerId,
    handle: handle,
    startPosition: startPosition,
    currentPosition: currentPosition ?? this.currentPosition,
    initialBounds: initialBounds,
    previewBounds: previewBounds ?? this.previewBounds,
    guides: guides ?? this.guides,
  );
}

class SnapResolver {
  const SnapResolver({this.threshold = 6, this.minimumSize = 48});

  final double threshold;
  final double minimumSize;

  ResizeResolution resolveResize({
    required ResizeSession session,
    required SpatialPoint position,
    required Iterable<SpatialRect> candidates,
  }) {
    final delta = position - session.startPosition;
    var width = session.initialBounds.width;
    var height = session.initialBounds.height;
    if (session.handle == ResizeHandle.east ||
        session.handle == ResizeHandle.southEast) {
      width = math.max(minimumSize, width + delta.x);
    }
    if (session.handle == ResizeHandle.south ||
        session.handle == ResizeHandle.southEast) {
      height = math.max(minimumSize, height + delta.y);
    }
    var right = session.initialBounds.left + width;
    var bottom = session.initialBounds.top + height;
    final guides = <SmartGuide>[];
    for (final candidate in candidates) {
      if (session.handle != ResizeHandle.south) {
        final snapped = _nearest(right, [
          candidate.left,
          candidate.center.x,
          candidate.right,
        ]);
        if (snapped != null) {
          right = snapped;
          guides.add(
            SmartGuide(axis: SmartGuideAxis.vertical, position: snapped),
          );
          break;
        }
      }
    }
    for (final candidate in candidates) {
      if (session.handle != ResizeHandle.east) {
        final snapped = _nearest(bottom, [
          candidate.top,
          candidate.center.y,
          candidate.bottom,
        ]);
        if (snapped != null) {
          bottom = snapped;
          guides.add(
            SmartGuide(axis: SmartGuideAxis.horizontal, position: snapped),
          );
          break;
        }
      }
    }
    return ResizeResolution(
      bounds: SpatialRect.fromLTRB(
        session.initialBounds.left,
        session.initialBounds.top,
        math.max(session.initialBounds.left + minimumSize, right),
        math.max(session.initialBounds.top + minimumSize, bottom),
      ),
      guides: guides,
    );
  }

  double? _nearest(double value, Iterable<double> candidates) {
    double? best;
    var bestDistance = threshold + 1;
    for (final candidate in candidates) {
      final distance = (candidate - value).abs();
      if (distance <= threshold && distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
      }
    }
    return best;
  }
}

enum BlockAlignmentAxis {
  left,
  horizontalCenter,
  right,
  top,
  verticalCenter,
  bottom,
}

class TransformationEngine {
  const TransformationEngine();

  Map<String, SpatialPoint> align(
    Map<String, SpatialRect> bounds,
    BlockAlignmentAxis alignment,
  ) {
    if (bounds.length < 2) return const {};
    final union = _union(bounds.values);
    return {
      for (final entry in bounds.entries)
        entry.key: _alignmentDelta(entry.value, union, alignment),
    };
  }

  Map<String, SpatialPoint> distributeVertically(
    List<String> visualOrder,
    Map<String, SpatialRect> bounds,
  ) {
    final ordered = visualOrder.where(bounds.containsKey).toList();
    if (ordered.length < 3) return const {};
    final first = bounds[ordered.first]!;
    final last = bounds[ordered.last]!;
    final totalHeight = ordered.fold<double>(
      0,
      (sum, id) => sum + bounds[id]!.height,
    );
    final gap = math.max(
      0,
      (last.bottom - first.top - totalHeight) / (ordered.length - 1),
    );
    var cursor = first.top;
    final result = <String, SpatialPoint>{};
    for (final id in ordered) {
      final rect = bounds[id]!;
      result[id] = SpatialPoint(0, cursor - rect.top);
      cursor += rect.height + gap;
    }
    return result;
  }

  Map<String, SpatialPoint> distributeHorizontally(
    List<String> visualOrder,
    Map<String, SpatialRect> bounds,
  ) {
    final ordered = visualOrder.where(bounds.containsKey).toList()
      ..sort((a, b) => bounds[a]!.left.compareTo(bounds[b]!.left));
    if (ordered.length < 3) return const {};
    final first = bounds[ordered.first]!;
    final last = bounds[ordered.last]!;
    final totalWidth = ordered.fold<double>(
      0,
      (sum, id) => sum + bounds[id]!.width,
    );
    final gap = math.max(
      0,
      (last.right - first.left - totalWidth) / (ordered.length - 1),
    );
    var cursor = first.left;
    final result = <String, SpatialPoint>{};
    for (final id in ordered) {
      final rect = bounds[id]!;
      result[id] = SpatialPoint(cursor - rect.left, 0);
      cursor += rect.width + gap;
    }
    return result;
  }

  SpatialPoint _alignmentDelta(
    SpatialRect rect,
    SpatialRect union,
    BlockAlignmentAxis alignment,
  ) => switch (alignment) {
    BlockAlignmentAxis.left => SpatialPoint(union.left - rect.left, 0),
    BlockAlignmentAxis.horizontalCenter => SpatialPoint(
      union.center.x - rect.center.x,
      0,
    ),
    BlockAlignmentAxis.right => SpatialPoint(union.right - rect.right, 0),
    BlockAlignmentAxis.top => SpatialPoint(0, union.top - rect.top),
    BlockAlignmentAxis.verticalCenter => SpatialPoint(
      0,
      union.center.y - rect.center.y,
    ),
    BlockAlignmentAxis.bottom => SpatialPoint(0, union.bottom - rect.bottom),
  };

  SpatialRect _union(Iterable<SpatialRect> rects) {
    final values = rects.toList();
    var left = values.first.left;
    var top = values.first.top;
    var right = values.first.right;
    var bottom = values.first.bottom;
    for (final rect in values.skip(1)) {
      left = math.min(left, rect.left);
      top = math.min(top, rect.top);
      right = math.max(right, rect.right);
      bottom = math.max(bottom, rect.bottom);
    }
    return SpatialRect.fromLTRB(left, top, right, bottom);
  }
}
