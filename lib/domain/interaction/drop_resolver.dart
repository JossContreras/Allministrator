import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/interaction/block_geometry_registry.dart';
import 'package:allministrator/domain/interaction/drag_session.dart';
import 'package:allministrator/domain/interaction/interaction_resolver.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';

class DropResolver {
  const DropResolver({required this.registry, this.blockInfo});

  final BlockGeometryRegistry registry;
  final BlockInteractionInfoResolver? blockInfo;

  DropTarget resolve({
    required String sourceBlockId,
    List<String> sourceBlockIds = const [],
    required SpatialPoint position,
  }) {
    final allSources = {sourceBlockId, ...sourceBlockIds};
    final invalidSource = allSources
        .map((id) => blockInfo?.call(id))
        .whereType<BlockInteractionInfo>()
        .any((source) => !source.supports(BlockCapability.movable));
    if (invalidSource) {
      return DropTarget(
        sourceBlockId: sourceBlockId,
        sourceBlockIds: sourceBlockIds,
        insertAfter: false,
        isValid: false,
        reason: 'source-not-movable',
      );
    }
    final candidates =
        registry.entries
            .where(
              (entry) =>
                  entry.blockId != sourceBlockId &&
                  !sourceBlockIds.contains(entry.blockId) &&
                  entry.isVisible,
            )
            .toList()
          ..sort((a, b) => a.layer.compareTo(b.layer));
    if (candidates.isEmpty) {
      return DropTarget(
        sourceBlockId: sourceBlockId,
        sourceBlockIds: sourceBlockIds,
        insertAfter: true,
        isValid: true,
      );
    }
    final target = candidates.reduce(
      (closest, candidate) =>
          (candidate.globalBounds.center.y - position.y).abs() <
              (closest.globalBounds.center.y - position.y).abs()
          ? candidate
          : closest,
    );
    return DropTarget(
      sourceBlockId: sourceBlockId,
      sourceBlockIds: sourceBlockIds,
      targetBlockId: target.blockId,
      insertAfter: position.y >= target.globalBounds.center.y,
      isValid: true,
    );
  }
}
