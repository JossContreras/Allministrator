import 'package:allministrator/domain/interaction/interaction_models.dart';
import 'package:allministrator/domain/interaction/selection_group.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';

class MarqueeSelectionSession extends InteractionSession {
  MarqueeSelectionSession({
    required super.id,
    required super.startedAt,
    required this.pointerId,
    required this.startPosition,
    required this.initialGroup,
    SpatialPoint? currentPosition,
    this.candidateIds = const [],
  }) : currentPosition = currentPosition ?? startPosition,
       super(type: InteractionSessionType.selection);

  final int pointerId;
  final SpatialPoint startPosition;
  final SpatialPoint currentPosition;
  final SelectionGroup initialGroup;
  final List<String> candidateIds;

  SpatialRect get bounds => SpatialRect.fromLTRB(
    startPosition.x < currentPosition.x ? startPosition.x : currentPosition.x,
    startPosition.y < currentPosition.y ? startPosition.y : currentPosition.y,
    startPosition.x > currentPosition.x ? startPosition.x : currentPosition.x,
    startPosition.y > currentPosition.y ? startPosition.y : currentPosition.y,
  );

  MarqueeSelectionSession copyWith({
    SpatialPoint? currentPosition,
    List<String>? candidateIds,
  }) => MarqueeSelectionSession(
    id: id,
    startedAt: startedAt,
    pointerId: pointerId,
    startPosition: startPosition,
    currentPosition: currentPosition ?? this.currentPosition,
    initialGroup: initialGroup,
    candidateIds: candidateIds ?? this.candidateIds,
  );
}
