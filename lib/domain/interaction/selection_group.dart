import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/interaction/block_geometry_registry.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';

/// Immutable authoritative block selection. Geometry remains runtime-only.
class SelectionGroup {
  const SelectionGroup({
    this.blockIds = const [],
    this.primaryBlockId,
    this.anchorBlockId,
    this.isTemporary = false,
  });

  final List<String> blockIds;
  final String? primaryBlockId;
  final String? anchorBlockId;
  final bool isTemporary;

  bool get isEmpty => blockIds.isEmpty;
  bool get isSingle => blockIds.length == 1;
  bool get isMultiple => blockIds.length > 1;
  int get count => blockIds.length;
  bool contains(String id) => blockIds.contains(id);

  SelectionGroup normalized() {
    final ids = <String>[];
    for (final id in blockIds) {
      if (!ids.contains(id)) ids.add(id);
    }
    final primary = ids.contains(primaryBlockId)
        ? primaryBlockId
        : ids.isEmpty
        ? null
        : ids.last;
    final anchor = ids.contains(anchorBlockId) ? anchorBlockId : primary;
    return SelectionGroup(
      blockIds: ids,
      primaryBlockId: primary,
      anchorBlockId: anchor,
      isTemporary: isTemporary,
    );
  }

  SelectionGroup copyWith({
    List<String>? blockIds,
    Object? primaryBlockId = _selectionUnset,
    Object? anchorBlockId = _selectionUnset,
    bool? isTemporary,
  }) => SelectionGroup(
    blockIds: blockIds ?? this.blockIds,
    primaryBlockId: identical(primaryBlockId, _selectionUnset)
        ? this.primaryBlockId
        : primaryBlockId as String?,
    anchorBlockId: identical(anchorBlockId, _selectionUnset)
        ? this.anchorBlockId
        : anchorBlockId as String?,
    isTemporary: isTemporary ?? this.isTemporary,
  ).normalized();

  SelectionGroup add(String id, {bool asPrimary = true}) => copyWith(
    blockIds: [...blockIds, id],
    primaryBlockId: asPrimary ? id : primaryBlockId,
    anchorBlockId: anchorBlockId ?? id,
  );

  SelectionGroup remove(String id) => copyWith(
    blockIds: blockIds.where((candidate) => candidate != id).toList(),
    primaryBlockId: primaryBlockId == id ? null : primaryBlockId,
    anchorBlockId: anchorBlockId == id ? null : anchorBlockId,
  );

  Set<BlockCapability> commonCapabilities(Iterable<BaseBlock> blocks) {
    final selected = blocks.where((block) => contains(block.id)).toList();
    if (selected.isEmpty) return const {};
    return selected.skip(1).fold<Set<BlockCapability>>(
      {...selected.first.capabilities},
      (common, block) => common.intersection(block.capabilities),
    );
  }
}

const Object _selectionUnset = Object();

class SelectionBoundsResolver {
  const SelectionBoundsResolver(this.registry);

  final BlockGeometryRegistry registry;

  SpatialRect? resolve(SelectionGroup group) {
    final entries = group.blockIds
        .map(registry.geometryFor)
        .whereType<BlockGeometryEntry>()
        .toList();
    if (entries.isEmpty) return null;
    return SpatialRect.fromLTRB(
      entries.map((entry) => entry.globalBounds.left).reduce(_min),
      entries.map((entry) => entry.globalBounds.top).reduce(_min),
      entries.map((entry) => entry.globalBounds.right).reduce(_max),
      entries.map((entry) => entry.globalBounds.bottom).reduce(_max),
    );
  }

  List<String> intersecting(SpatialRect marquee, {double minimumRatio = .2}) =>
      registry.visibleBlocks
          .where((entry) {
            final intersection = entry.globalBounds.intersect(marquee);
            final area = entry.globalBounds.width * entry.globalBounds.height;
            return area > 0 &&
                !intersection.isEmpty &&
                (intersection.width * intersection.height) / area >= minimumRatio;
          })
          .map((entry) => entry.blockId)
          .toList();

  static double _min(double a, double b) => a < b ? a : b;
  static double _max(double a, double b) => a > b ? a : b;
}
