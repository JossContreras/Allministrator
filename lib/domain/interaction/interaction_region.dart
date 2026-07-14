import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';
import 'package:allministrator/domain/interaction/workspace_hit_target.dart';

class InteractionRegion {
  const InteractionRegion({
    required this.id,
    required this.blockId,
    required this.target,
    required this.globalBounds,
    required this.localBounds,
    this.priority = 0,
    this.isEnabled = true,
  });

  final String id;
  final Uuid blockId;
  final WorkspaceHitTarget target;
  final SpatialRect globalBounds;
  final SpatialRect localBounds;
  final int priority;
  final bool isEnabled;

  InteractionRegion copyWith({
    SpatialRect? globalBounds,
    SpatialRect? localBounds,
    bool? isEnabled,
  }) => InteractionRegion(
    id: id,
    blockId: blockId,
    target: target,
    globalBounds: globalBounds ?? this.globalBounds,
    localBounds: localBounds ?? this.localBounds,
    priority: priority,
    isEnabled: isEnabled ?? this.isEnabled,
  );
}

class WorkspaceHitResult {
  const WorkspaceHitResult({
    required this.target,
    required this.globalPosition,
    this.region,
  });

  final WorkspaceHitTarget target;
  final SpatialPoint globalPosition;
  final InteractionRegion? region;
}
