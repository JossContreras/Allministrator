import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/interaction/interaction_region.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';
import 'package:allministrator/domain/interaction/workspace_hit_target.dart';
import 'package:flutter/foundation.dart';

class BlockGeometryEntry {
  const BlockGeometryEntry({
    required this.blockId,
    required this.workspaceId,
    required this.pageId,
    required this.globalBounds,
    required this.localBounds,
    required this.visibleBounds,
    required this.layer,
    required this.isVisible,
    required this.lastLayoutPass,
    required this.lastUpdated,
    required this.handleAnchor,
    required this.toolbarAnchor,
    this.regions = const {},
  });

  final Uuid blockId;
  final Uuid workspaceId;
  final Uuid pageId;
  final SpatialRect globalBounds;
  final SpatialRect localBounds;
  final SpatialRect visibleBounds;
  final int layer;
  final bool isVisible;
  final int lastLayoutPass;
  final DateTime lastUpdated;
  final SpatialPoint handleAnchor;
  final SpatialPoint toolbarAnchor;
  final Map<String, InteractionRegion> regions;

  BlockGeometryEntry copyWith({
    SpatialRect? globalBounds,
    SpatialRect? localBounds,
    SpatialRect? visibleBounds,
    int? layer,
    bool? isVisible,
    int? lastLayoutPass,
    DateTime? lastUpdated,
    SpatialPoint? handleAnchor,
    SpatialPoint? toolbarAnchor,
    Map<String, InteractionRegion>? regions,
  }) => BlockGeometryEntry(
    blockId: blockId,
    workspaceId: workspaceId,
    pageId: pageId,
    globalBounds: globalBounds ?? this.globalBounds,
    localBounds: localBounds ?? this.localBounds,
    visibleBounds: visibleBounds ?? this.visibleBounds,
    layer: layer ?? this.layer,
    isVisible: isVisible ?? this.isVisible,
    lastLayoutPass: lastLayoutPass ?? this.lastLayoutPass,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    handleAnchor: handleAnchor ?? this.handleAnchor,
    toolbarAnchor: toolbarAnchor ?? this.toolbarAnchor,
    regions: regions ?? this.regions,
  );
}

class WorkspaceViewportGeometry {
  const WorkspaceViewportGeometry({
    required this.globalBounds,
    this.scrollOffset = const SpatialPoint(0, 0),
    this.keyboardInset = 0,
    this.visibleGlobalBottom,
  });

  final SpatialRect globalBounds;
  final SpatialPoint scrollOffset;
  final double keyboardInset;
  final double? visibleGlobalBottom;

  SpatialRect get visibleBounds => SpatialRect.fromLTRB(
    globalBounds.left,
    globalBounds.top,
    globalBounds.right,
    visibleGlobalBottom == null
        ? globalBounds.bottom - keyboardInset
        : globalBounds.bottom.clamp(globalBounds.top, visibleGlobalBottom!),
  );
}

class BlockGeometryRegistry extends ChangeNotifier {
  final Map<Uuid, BlockGeometryEntry> _entries = {};
  WorkspaceViewportGeometry? _viewport;
  int _layoutPass = 0;
  bool _disposed = false;

  WorkspaceViewportGeometry? get viewport => _viewport;
  List<BlockGeometryEntry> get entries => List.unmodifiable(_entries.values);
  int get nextLayoutPass => ++_layoutPass;

  BlockGeometryEntry? geometryFor(Uuid blockId) => _entries[blockId];

  List<BlockGeometryEntry> get visibleBlocks =>
      _entries.values
          .where((entry) => entry.isVisible && !entry.visibleBounds.isEmpty)
          .toList(growable: false)
        ..sort((a, b) => a.layer.compareTo(b.layer));

  void updateViewport(WorkspaceViewportGeometry viewport) {
    if (_viewport?.globalBounds == viewport.globalBounds &&
        _viewport?.scrollOffset == viewport.scrollOffset &&
        _viewport?.keyboardInset == viewport.keyboardInset &&
        _viewport?.visibleGlobalBottom == viewport.visibleGlobalBottom) {
      return;
    }
    final previousViewport = _viewport;
    _viewport = viewport;
    final dx = previousViewport == null
        ? 0.0
        : viewport.globalBounds.left -
              previousViewport.globalBounds.left -
              (viewport.scrollOffset.x - previousViewport.scrollOffset.x);
    final dy = previousViewport == null
        ? 0.0
        : viewport.globalBounds.top -
              previousViewport.globalBounds.top -
              (viewport.scrollOffset.y - previousViewport.scrollOffset.y);
    final now = DateTime.now().toUtc();
    for (final entry in _entries.values.toList()) {
      final globalBounds = entry.globalBounds.translate(dx, dy);
      final visible = globalBounds.intersect(viewport.visibleBounds);
      _entries[entry.blockId] = entry.copyWith(
        globalBounds: globalBounds,
        visibleBounds: visible,
        isVisible: !visible.isEmpty,
        lastUpdated: now,
        handleAnchor: entry.handleAnchor + SpatialPoint(dx, dy),
        toolbarAnchor: entry.toolbarAnchor + SpatialPoint(dx, dy),
        regions: {
          for (final region in entry.regions.values)
            region.id: region.copyWith(
              globalBounds: region.globalBounds.translate(dx, dy),
            ),
        },
      );
    }
    notifyListeners();
  }

  void register({
    required Uuid blockId,
    required Uuid workspaceId,
    required Uuid pageId,
    required SpatialRect globalBounds,
    required SpatialRect localBounds,
    required int layer,
    required int lastLayoutPass,
  }) {
    final visibleBounds = _viewport == null
        ? globalBounds
        : globalBounds.intersect(_viewport!.visibleBounds);
    final previous = _entries[blockId];
    final isVisible = !visibleBounds.isEmpty;
    if (previous != null &&
        previous.workspaceId == workspaceId &&
        previous.pageId == pageId &&
        previous.globalBounds == globalBounds &&
        previous.localBounds == localBounds &&
        previous.visibleBounds == visibleBounds &&
        previous.layer == layer &&
        previous.isVisible == isVisible) {
      if (previous.lastLayoutPass != lastLayoutPass) {
        _entries[blockId] = previous.copyWith(lastLayoutPass: lastLayoutPass);
      }
      return;
    }
    _entries[blockId] = BlockGeometryEntry(
      blockId: blockId,
      workspaceId: workspaceId,
      pageId: pageId,
      globalBounds: globalBounds,
      localBounds: localBounds,
      visibleBounds: visibleBounds,
      layer: layer,
      isVisible: isVisible,
      lastLayoutPass: lastLayoutPass,
      lastUpdated: DateTime.now().toUtc(),
      handleAnchor: globalBounds.topLeft,
      toolbarAnchor: SpatialPoint(globalBounds.center.x, globalBounds.top),
      regions: previous?.regions ?? const {},
    );
    notifyListeners();
  }

  void updateRegion(InteractionRegion region) {
    final entry = _entries[region.blockId];
    if (entry == null) return;
    final previous = entry.regions[region.id];
    if (previous?.globalBounds == region.globalBounds &&
        previous?.localBounds == region.localBounds &&
        previous?.isEnabled == region.isEnabled &&
        previous?.priority == region.priority &&
        previous != null &&
        equivalentHitTargets(previous.target, region.target)) {
      return;
    }
    _entries[region.blockId] = entry.copyWith(
      regions: {...entry.regions, region.id: region},
      lastUpdated: DateTime.now().toUtc(),
    );
    notifyListeners();
  }

  void removeRegion(Uuid blockId, String regionId) {
    final entry = _entries[blockId];
    if (entry == null || !entry.regions.containsKey(regionId)) return;
    final regions = {...entry.regions}..remove(regionId);
    _entries[blockId] = entry.copyWith(
      regions: regions,
      lastUpdated: DateTime.now().toUtc(),
    );
    notifyListeners();
  }

  bool remove(Uuid blockId) {
    final removed = _entries.remove(blockId) != null;
    if (removed) notifyListeners();
    return removed;
  }

  void removeIfLayoutPass(Uuid blockId, int layoutPass) {
    if (_disposed) return;
    final entry = _entries[blockId];
    if (entry == null || entry.lastLayoutPass != layoutPass) return;
    remove(blockId);
  }

  void removeRegionIfUnchanged(
    Uuid blockId,
    String regionId,
    InteractionRegion? expected,
  ) {
    if (_disposed) return;
    if (expected == null) return;
    final current = _entries[blockId]?.regions[regionId];
    if (!identical(current, expected)) return;
    removeRegion(blockId, regionId);
  }

  void retainOnly(Set<Uuid> blockIds) {
    final removed = _entries.keys
        .where((blockId) => !blockIds.contains(blockId))
        .toList();
    if (removed.isEmpty) return;
    for (final blockId in removed) {
      _entries.remove(blockId);
    }
    notifyListeners();
  }

  BlockGeometryEntry? blockAt(SpatialPoint globalPosition) {
    final matches =
        _entries.values
            .where(
              (entry) =>
                  entry.isVisible &&
                  entry.globalBounds.contains(globalPosition),
            )
            .toList()
          ..sort((a, b) => b.layer.compareTo(a.layer));
    return matches.firstOrNull;
  }

  WorkspaceHitResult hitTest(SpatialPoint globalPosition) {
    final candidateRegions = <InteractionRegion>[];
    for (final entry in _entries.values) {
      if (!entry.isVisible) continue;
      candidateRegions.addAll(
        entry.regions.values.where(
          (region) =>
              region.isEnabled && region.globalBounds.contains(globalPosition),
        ),
      );
    }
    candidateRegions.sort((a, b) {
      final layerA = _entries[a.blockId]?.layer ?? 0;
      final layerB = _entries[b.blockId]?.layer ?? 0;
      final layerOrder = layerB.compareTo(layerA);
      return layerOrder != 0 ? layerOrder : b.priority.compareTo(a.priority);
    });
    final region = candidateRegions.firstOrNull;
    if (region != null) {
      return WorkspaceHitResult(
        target: region.target,
        globalPosition: globalPosition,
        region: region,
      );
    }
    final block = blockAt(globalPosition);
    if (block != null) {
      return WorkspaceHitResult(
        target: BlockBackgroundHitTarget(block.blockId),
        globalPosition: globalPosition,
      );
    }
    return WorkspaceHitResult(
      target: const EmptyAreaHitTarget(),
      globalPosition: globalPosition,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _entries.clear();
    super.dispose();
  }
}
