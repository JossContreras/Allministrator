import 'package:allministrator/domain/interaction/interaction_models.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';

enum DragSessionState { active, committed, cancelled, disposed }

class DropTarget {
  const DropTarget({
    required this.sourceBlockId,
    this.sourceBlockIds = const [],
    this.targetBlockId,
    required this.insertAfter,
    required this.isValid,
    this.reason,
  });

  final String sourceBlockId;
  final List<String> sourceBlockIds;
  final String? targetBlockId;
  final bool insertAfter;
  final bool isValid;
  final String? reason;
}

/// Ephemeral movement state. It is never serialized into Workspace.
class DragSession extends InteractionSession {
  DragSession({
    required super.id,
    required super.startedAt,
    required super.blockId,
    required this.pointerId,
    required this.startPosition,
    this.blockIds = const [],
    this.primaryBlockId,
    SpatialPoint? currentPosition,
    this.dropTarget,
    this.state = DragSessionState.active,
  }) : currentPosition = currentPosition ?? startPosition,
       super(type: InteractionSessionType.drag);

  final int? pointerId;
  final SpatialPoint startPosition;
  final List<String> blockIds;
  final String? primaryBlockId;
  final SpatialPoint currentPosition;
  final DropTarget? dropTarget;
  final DragSessionState state;

  SpatialPoint get delta => currentPosition - startPosition;

  DragSession copyWith({
    SpatialPoint? currentPosition,
    DropTarget? dropTarget,
    bool clearDropTarget = false,
    DragSessionState? state,
  }) => DragSession(
    id: id,
    startedAt: startedAt,
    blockId: blockId,
    pointerId: pointerId,
    startPosition: startPosition,
    blockIds: blockIds,
    primaryBlockId: primaryBlockId,
    currentPosition: currentPosition ?? this.currentPosition,
    dropTarget: clearDropTarget ? null : dropTarget ?? this.dropTarget,
    state: state ?? this.state,
  );
}
