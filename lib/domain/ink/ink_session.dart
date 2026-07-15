import 'package:allministrator/domain/ink/ink_models.dart';
import 'package:allministrator/domain/interaction/interaction_models.dart';

class InkSession extends InteractionSession {
  const InkSession({
    required super.id,
    required super.startedAt,
    required this.correlationId,
    required this.pointerId,
    required this.tool,
    required this.brush,
    required this.points,
    this.shapeKind,
    this.anchor,
    this.affectedElementIds = const [],
  }) : super(type: InteractionSessionType.ink, hasPendingChanges: true);

  final String correlationId;
  final int pointerId;
  final WorkspaceTool tool;
  final InkBrushStyle brush;
  final List<InkPoint> points;
  final InkShapeKind? shapeKind;
  final AnnotationAnchor? anchor;
  final List<String> affectedElementIds;

  InkPoint get firstPoint => points.first;
  InkPoint get currentPoint => points.last;

  InkSession copyWith({
    List<InkPoint>? points,
    List<String>? affectedElementIds,
  }) => InkSession(
    id: id,
    startedAt: startedAt,
    correlationId: correlationId,
    pointerId: pointerId,
    tool: tool,
    brush: brush,
    points: points ?? this.points,
    shapeKind: shapeKind,
    anchor: anchor,
    affectedElementIds: affectedElementIds ?? this.affectedElementIds,
  );
}
