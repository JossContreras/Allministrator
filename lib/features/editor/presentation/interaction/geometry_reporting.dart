import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class WorkspaceViewportReporter extends SingleChildRenderObjectWidget {
  const WorkspaceViewportReporter({
    required this.registry,
    required this.scrollListenable,
    required this.readScrollOffset,
    required this.keyboardInset,
    required this.visibleGlobalBottom,
    required super.child,
    super.key,
  });

  final BlockGeometryRegistry registry;
  final Listenable scrollListenable;
  final double Function() readScrollOffset;
  final double keyboardInset;
  final double visibleGlobalBottom;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderWorkspaceViewportReporter(
        registry: registry,
        scrollListenable: scrollListenable,
        readScrollOffset: readScrollOffset,
        keyboardInset: keyboardInset,
        visibleGlobalBottom: visibleGlobalBottom,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderWorkspaceViewportReporter renderObject,
  ) {
    renderObject
      ..registry = registry
      ..scrollListenable = scrollListenable
      ..readScrollOffset = readScrollOffset
      ..keyboardInset = keyboardInset
      ..visibleGlobalBottom = visibleGlobalBottom;
  }
}

class RenderWorkspaceViewportReporter extends RenderProxyBox {
  RenderWorkspaceViewportReporter({
    required BlockGeometryRegistry registry,
    required Listenable scrollListenable,
    required double Function() readScrollOffset,
    required double keyboardInset,
    required double visibleGlobalBottom,
  }) : _registry = registry,
       _scrollListenable = scrollListenable,
       _readScrollOffset = readScrollOffset,
       _keyboardInset = keyboardInset,
       _visibleGlobalBottom = visibleGlobalBottom;

  BlockGeometryRegistry _registry;
  Listenable _scrollListenable;
  double Function() _readScrollOffset;
  double _keyboardInset;
  double _visibleGlobalBottom;
  bool _reportScheduled = false;

  set registry(BlockGeometryRegistry value) {
    if (identical(_registry, value)) return;
    _registry = value;
    markNeedsPaint();
  }

  set scrollListenable(Listenable value) {
    if (identical(_scrollListenable, value)) return;
    if (attached) _scrollListenable.removeListener(_handleViewportChanged);
    _scrollListenable = value;
    if (attached) _scrollListenable.addListener(_handleViewportChanged);
  }

  set readScrollOffset(double Function() value) => _readScrollOffset = value;

  set keyboardInset(double value) {
    if (_keyboardInset == value) return;
    _keyboardInset = value;
    markNeedsPaint();
  }

  set visibleGlobalBottom(double value) {
    if (_visibleGlobalBottom == value) return;
    _visibleGlobalBottom = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scrollListenable.addListener(_handleViewportChanged);
  }

  @override
  void detach() {
    _scrollListenable.removeListener(_handleViewportChanged);
    super.detach();
  }

  void _handleViewportChanged() {
    markNeedsPaint();
    _scheduleReport();
  }

  @override
  void performLayout() {
    super.performLayout();
    _scheduleReport();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    _scheduleReport();
  }

  void _scheduleReport() {
    if (_reportScheduled || !attached || !hasSize) return;
    _reportScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (!attached || !hasSize) return;
      final origin = localToGlobal(Offset.zero);
      _registry.updateViewport(
        WorkspaceViewportGeometry(
          globalBounds: SpatialRect.fromLTWH(
            origin.dx,
            origin.dy,
            size.width,
            size.height,
          ),
          scrollOffset: SpatialPoint(0, _readScrollOffset()),
          keyboardInset: _keyboardInset,
          visibleGlobalBottom: _visibleGlobalBottom,
        ),
      );
    });
  }
}

class BlockGeometryReporter extends SingleChildRenderObjectWidget {
  const BlockGeometryReporter({
    required this.registry,
    required this.blockId,
    required this.workspaceId,
    required this.pageId,
    required this.layer,
    required super.child,
    super.key,
  });

  final BlockGeometryRegistry registry;
  final String blockId;
  final String workspaceId;
  final String pageId;
  final int layer;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderBlockGeometryReporter(
        registry: registry,
        blockId: blockId,
        workspaceId: workspaceId,
        pageId: pageId,
        layer: layer,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderBlockGeometryReporter renderObject,
  ) {
    renderObject
      ..registry = registry
      ..blockId = blockId
      ..workspaceId = workspaceId
      ..pageId = pageId
      ..blockLayer = layer;
  }
}

class RenderBlockGeometryReporter extends RenderProxyBox {
  RenderBlockGeometryReporter({
    required BlockGeometryRegistry registry,
    required String blockId,
    required String workspaceId,
    required String pageId,
    required int layer,
  }) : _registry = registry,
       _blockId = blockId,
       _workspaceId = workspaceId,
       _pageId = pageId,
       _layer = layer;

  BlockGeometryRegistry _registry;
  String _blockId;
  String _workspaceId;
  String _pageId;
  int _layer;
  bool _reportScheduled = false;

  set registry(BlockGeometryRegistry value) {
    if (identical(_registry, value)) return;
    _scheduleBlockRemoval();
    _registry = value;
    markNeedsPaint();
  }

  set blockId(String value) {
    if (_blockId == value) return;
    _scheduleBlockRemoval();
    _blockId = value;
    markNeedsPaint();
  }

  set workspaceId(String value) {
    if (_workspaceId == value) return;
    _workspaceId = value;
    markNeedsPaint();
  }

  set pageId(String value) {
    if (_pageId == value) return;
    _pageId = value;
    markNeedsPaint();
  }

  set blockLayer(int value) {
    if (_layer == value) return;
    _layer = value;
    markNeedsPaint();
  }

  @override
  void performLayout() {
    super.performLayout();
    _scheduleReport();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    _scheduleReport();
  }

  void _scheduleReport() {
    if (_reportScheduled || !attached || !hasSize) return;
    _reportScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (!attached || !hasSize) return;
      final origin = localToGlobal(Offset.zero);
      _registry.register(
        blockId: _blockId,
        workspaceId: _workspaceId,
        pageId: _pageId,
        globalBounds: SpatialRect.fromLTWH(
          origin.dx,
          origin.dy,
          size.width,
          size.height,
        ),
        localBounds: SpatialRect.fromLTWH(0, 0, size.width, size.height),
        layer: _layer,
        lastLayoutPass: _registry.nextLayoutPass,
      );
    });
  }

  @override
  void detach() {
    _scheduleBlockRemoval();
    super.detach();
  }

  void _scheduleBlockRemoval() {
    final registry = _registry;
    final blockId = _blockId;
    final layoutPass = registry.geometryFor(blockId)?.lastLayoutPass;
    if (layoutPass != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        registry.removeIfLayoutPass(blockId, layoutPass);
      });
    }
  }
}

class InteractionRegionReporter extends SingleChildRenderObjectWidget {
  const InteractionRegionReporter({
    required this.registry,
    required this.blockId,
    required this.regionId,
    required this.target,
    required super.child,
    this.priority = 0,
    super.key,
  });

  final BlockGeometryRegistry registry;
  final String blockId;
  final String regionId;
  final WorkspaceHitTarget target;
  final int priority;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderInteractionRegionReporter(
        registry: registry,
        blockId: blockId,
        regionId: regionId,
        target: target,
        priority: priority,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderInteractionRegionReporter renderObject,
  ) {
    renderObject
      ..registry = registry
      ..blockId = blockId
      ..regionId = regionId
      ..target = target
      ..priority = priority;
  }
}

class RenderInteractionRegionReporter extends RenderProxyBox {
  RenderInteractionRegionReporter({
    required BlockGeometryRegistry registry,
    required String blockId,
    required String regionId,
    required WorkspaceHitTarget target,
    required int priority,
  }) : _registry = registry,
       _blockId = blockId,
       _regionId = regionId,
       _target = target,
       _priority = priority;

  BlockGeometryRegistry _registry;
  String _blockId;
  String _regionId;
  WorkspaceHitTarget _target;
  int _priority;
  bool _reportScheduled = false;

  set registry(BlockGeometryRegistry value) {
    if (identical(_registry, value)) return;
    _scheduleRegionRemoval();
    _registry = value;
    markNeedsPaint();
  }

  set blockId(String value) {
    if (_blockId == value) return;
    _scheduleRegionRemoval();
    _blockId = value;
    markNeedsPaint();
  }

  set regionId(String value) {
    if (_regionId == value) return;
    _scheduleRegionRemoval();
    _regionId = value;
    markNeedsPaint();
  }

  set target(WorkspaceHitTarget value) {
    if (equivalentHitTargets(_target, value)) {
      _target = value;
      return;
    }
    _target = value;
    markNeedsPaint();
  }

  set priority(int value) {
    if (_priority == value) return;
    _priority = value;
    markNeedsPaint();
  }

  @override
  void performLayout() {
    super.performLayout();
    _scheduleReport();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    _scheduleReport();
  }

  void _scheduleReport() {
    if (_reportScheduled || !attached || !hasSize) return;
    _reportScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (!attached || !hasSize) return;
      final block = _registry.geometryFor(_blockId);
      if (block == null) {
        _scheduleReport();
        return;
      }
      final origin = localToGlobal(Offset.zero);
      final globalBounds = SpatialRect.fromLTWH(
        origin.dx,
        origin.dy,
        size.width,
        size.height,
      );
      _registry.updateRegion(
        InteractionRegion(
          id: _regionId,
          blockId: _blockId,
          target: _target,
          globalBounds: globalBounds,
          localBounds: globalBounds.translate(
            -block.globalBounds.left,
            -block.globalBounds.top,
          ),
          priority: _priority,
        ),
      );
    });
  }

  @override
  void detach() {
    _scheduleRegionRemoval();
    super.detach();
  }

  void _scheduleRegionRemoval() {
    final registry = _registry;
    final blockId = _blockId;
    final regionId = _regionId;
    final expected = registry.geometryFor(blockId)?.regions[regionId];
    SchedulerBinding.instance.addPostFrameCallback((_) {
      registry.removeRegionIfUnchanged(blockId, regionId, expected);
    });
  }
}
