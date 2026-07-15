import 'dart:math' as math;

import 'package:allministrator/domain/editing/workspace_editor_session.dart';
import 'package:allministrator/app/theme/app_radius.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const bool _inkDebugEnabled = bool.fromEnvironment('WORKSPACE_INK_DEBUG');

class InkCanvasLayer extends StatelessWidget {
  const InkCanvasLayer({
    required this.session,
    required this.interaction,
    required this.registry,
    super.key,
  });

  final WorkspaceEditorSession session;
  final WorkspaceInteractionController interaction;
  final BlockGeometryRegistry registry;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Semantics(
      label: 'Anotaciones de tinta',
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            session.presentationRevision,
            interaction,
            registry,
          ]),
          builder: (context, _) {
            final activeSession =
                interaction.context.activeSession is InkSession
                ? interaction.context.activeSession! as InkSession
                : null;
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  key: const ValueKey('ink-canvas-layer'),
                  painter: InkLayerPainter(
                    elements: session.page.inkLayer.elements,
                    activeSession: activeSession,
                    selection:
                        interaction.context.currentSelection is InkSelection
                        ? interaction.context.currentSelection as InkSelection
                        : null,
                    pointer: interaction.context.currentPointer,
                    activeTool: interaction.context.activeTool,
                    registry: registry,
                    viewport: registry.viewport,
                    geometrySignature: Object.hashAll(
                      registry.entries.map(
                        (entry) => Object.hash(
                          entry.blockId,
                          entry.globalBounds,
                          entry.lastLayoutPass,
                        ),
                      ),
                    ),
                    colorScheme: Theme.of(context).colorScheme,
                  ),
                ),
                if (kDebugMode && _inkDebugEnabled)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: .9),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          'Ink ${interaction.context.activeTool.name}\n'
                          'session=${activeSession?.correlationId ?? '-'} '
                          'points=${activeSession?.points.length ?? 0} '
                          'visible=${session.page.inkLayer.elements.length}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

@visibleForTesting
class InkLayerPainter extends CustomPainter {
  const InkLayerPainter({
    required this.elements,
    required this.activeSession,
    required this.selection,
    required this.pointer,
    required this.activeTool,
    required this.registry,
    required this.viewport,
    required this.geometrySignature,
    required this.colorScheme,
  });

  final List<InkElement> elements;
  final InkSession? activeSession;
  final InkSelection? selection;
  final InteractionPointer? pointer;
  final WorkspaceTool activeTool;
  final BlockGeometryRegistry registry;
  final WorkspaceViewportGeometry? viewport;
  final int geometrySignature;
  final ColorScheme colorScheme;

  GeometryResolver get _geometry => GeometryResolver(registry);

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = registry.viewport;
    if (viewport == null) return;
    final visibleWorkspace = _geometry.resolveRect(
      viewport.visibleBounds,
      from: GeometryCoordinateSpace.screen,
      to: GeometryCoordinateSpace.workspace,
    );
    final visible = InkSpatialIndex(
      elements,
    ).visibleIn(visibleWorkspace, resolvePoint: _resolveAnchoredPoint);
    for (final element in visible) {
      _paintElement(canvas, element);
    }
    _paintActiveSession(canvas);
    _paintSelection(canvas);
    _paintHover(canvas);
  }

  void _paintElement(
    Canvas canvas,
    InkElement element, {
    Color? overrideColor,
    double widthMultiplier = 1,
  }) {
    final paint = _paintFor(
      element.brush,
      overrideColor: overrideColor,
      widthMultiplier: widthMultiplier,
    );
    if (element is InkStroke) {
      final points = element.points
          .map(
            (point) => _workspaceToLocal(
              _resolveAnchoredPoint(element, point.workspacePosition),
            ),
          )
          .toList(growable: false);
      _paintStroke(canvas, points, paint, element);
      return;
    }
    final shape = element as InkShape;
    _paintShape(
      canvas,
      shape.kind,
      _workspaceToLocal(_resolveAnchoredPoint(shape, shape.start)),
      _workspaceToLocal(_resolveAnchoredPoint(shape, shape.end)),
      paint,
    );
  }

  void _paintStroke(
    Canvas canvas,
    List<Offset> points,
    Paint paint,
    InkStroke stroke,
  ) {
    if (points.length < 2) return;
    if (stroke.brush.pressureEnabled && stroke.points.length == points.length) {
      for (var index = 1; index < points.length; index++) {
        final pressure = stroke.points[index].pressure ?? .5;
        paint.strokeWidth =
            stroke.brush.baseWidth * (.65 + pressure * .7) * _zoom;
        canvas.drawLine(points[index - 1], points[index], paint);
      }
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length - 1; index++) {
      final midpoint = Offset(
        (points[index].dx + points[index + 1].dx) / 2,
        (points[index].dy + points[index + 1].dy) / 2,
      );
      path.quadraticBezierTo(
        points[index].dx,
        points[index].dy,
        midpoint.dx,
        midpoint.dy,
      );
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint);
  }

  void _paintShape(
    Canvas canvas,
    InkShapeKind kind,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    final rect = Rect.fromPoints(start, end);
    switch (kind) {
      case InkShapeKind.line:
        canvas.drawLine(start, end, paint);
      case InkShapeKind.arrow:
        canvas.drawLine(start, end, paint);
        final direction = end - start;
        if (direction.distance < 2) return;
        final unit = direction / direction.distance;
        final normal = Offset(-unit.dy, unit.dx);
        final head = math.max(10.0, paint.strokeWidth * 3);
        canvas.drawLine(end, end - unit * head + normal * head * .45, paint);
        canvas.drawLine(end, end - unit * head - normal * head * .45, paint);
      case InkShapeKind.rectangle:
        canvas.drawRect(rect, paint);
      case InkShapeKind.ellipse:
        canvas.drawOval(rect, paint);
    }
  }

  void _paintActiveSession(Canvas canvas) {
    final session = activeSession;
    if (session == null || session.points.isEmpty) return;
    if (session.tool == WorkspaceTool.eraser) {
      for (final id in session.affectedElementIds) {
        final element = elements.where((item) => item.id == id).firstOrNull;
        if (element != null) {
          _paintElement(
            canvas,
            element,
            overrideColor: colorScheme.error,
            widthMultiplier: 1.8,
          );
        }
      }
      final center = _workspaceToLocal(session.currentPoint.workspacePosition);
      canvas.drawCircle(
        center,
        18,
        Paint()
          ..color = colorScheme.error.withValues(alpha: .16)
          ..style = PaintingStyle.fill,
      );
      return;
    }
    final points = session.points
        .map((point) => _workspaceToLocal(point.workspacePosition))
        .toList(growable: false);
    if (session.tool == WorkspaceTool.inkLasso) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colorScheme.primary
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
      return;
    }
    if (session.tool.isInkShape && points.length >= 2) {
      _paintShape(
        canvas,
        session.shapeKind ?? InkShapeKind.line,
        points.first,
        points.last,
        _paintFor(session.brush),
      );
      return;
    }
    if (points.length >= 2) {
      final preview = InkStroke(
        id: 'preview',
        surfaceId: 'preview',
        brush: session.brush,
        points: session.points,
        createdAt: session.startedAt,
        updatedAt: session.startedAt,
      );
      _paintStroke(canvas, points, _paintFor(session.brush), preview);
    }
  }

  void _paintSelection(Canvas canvas) {
    final ids = selection?.elementIds.toSet() ?? const <String>{};
    if (ids.isEmpty) return;
    final selected = elements.where((element) => ids.contains(element.id));
    Rect? combined;
    for (final element in selected) {
      final points = switch (element) {
        InkStroke(:final points) => points.map(
          (point) => _workspaceToLocal(
            _resolveAnchoredPoint(element, point.workspacePosition),
          ),
        ),
        InkShape(:final start, :final end) => [
          _workspaceToLocal(_resolveAnchoredPoint(element, start)),
          _workspaceToLocal(_resolveAnchoredPoint(element, end)),
        ],
      };
      final bounds = _offsetBounds(points);
      combined = combined == null ? bounds : combined.expandToInclude(bounds);
    }
    if (combined == null) return;
    final selectionPaint = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(combined.inflate(8), const Radius.circular(8)),
      selectionPaint,
    );
    for (final point in [
      combined.topLeft,
      combined.topRight,
      combined.bottomLeft,
      combined.bottomRight,
    ]) {
      canvas.drawCircle(point, 4, Paint()..color = colorScheme.primary);
    }
  }

  void _paintHover(Canvas canvas) {
    final current = pointer;
    if (current == null || current.isDown || !activeTool.startsInkSession) {
      return;
    }
    final viewport = registry.viewport;
    if (viewport == null) return;
    final origin = viewport.globalBounds.topLeft;
    final local = Offset(
      current.position.x - origin.x,
      current.position.y - origin.y,
    );
    canvas.drawCircle(
      local,
      activeTool == WorkspaceTool.eraser ? 18 : 4,
      Paint()
        ..color = colorScheme.primary.withValues(alpha: .7)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  Paint _paintFor(
    InkBrushStyle style, {
    Color? overrideColor,
    double widthMultiplier = 1,
  }) => Paint()
    ..color = (overrideColor ?? Color(style.color)).withValues(
      alpha: style.opacity,
    )
    ..strokeWidth = style.baseWidth * _zoom * widthMultiplier
    ..strokeCap = style.cap == InkStrokeCap.round
        ? StrokeCap.round
        : StrokeCap.square
    ..strokeJoin = style.join == InkStrokeJoin.round
        ? StrokeJoin.round
        : StrokeJoin.bevel
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true
    ..blendMode = BlendMode.srcOver;

  double get _zoom => viewport?.camera.zoom ?? 1;

  SpatialPoint _resolveAnchoredPoint(InkElement element, SpatialPoint stored) {
    final anchor = element.anchor;
    if (anchor?.targetId == null) return stored;
    final entry = registry.geometryFor(anchor!.targetId!);
    final currentBounds = entry == null
        ? null
        : _geometry.resolveRect(
            entry.globalBounds,
            from: GeometryCoordinateSpace.screen,
            to: GeometryCoordinateSpace.workspace,
          );
    return anchor.resolve(stored, currentBounds);
  }

  Offset _workspaceToLocal(SpatialPoint point) {
    final screen = _geometry.resolvePoint(
      point,
      from: GeometryCoordinateSpace.workspace,
      to: GeometryCoordinateSpace.screen,
    );
    final origin =
        registry.viewport?.globalBounds.topLeft ?? const SpatialPoint(0, 0);
    return Offset(screen.x - origin.x, screen.y - origin.y);
  }

  Rect _offsetBounds(Iterable<Offset> points) {
    final values = points.toList();
    if (values.isEmpty) return Rect.zero;
    var left = values.first.dx;
    var top = values.first.dy;
    var right = values.first.dx;
    var bottom = values.first.dy;
    for (final point in values.skip(1)) {
      left = math.min(left, point.dx);
      top = math.min(top, point.dy);
      right = math.max(right, point.dx);
      bottom = math.max(bottom, point.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  bool shouldRepaint(InkLayerPainter oldDelegate) =>
      oldDelegate.elements != elements ||
      oldDelegate.activeSession != activeSession ||
      oldDelegate.selection != selection ||
      oldDelegate.pointer != pointer ||
      oldDelegate.activeTool != activeTool ||
      oldDelegate.colorScheme != colorScheme ||
      oldDelegate.viewport != viewport ||
      oldDelegate.geometrySignature != geometrySignature;
}
