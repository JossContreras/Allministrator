import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/interaction/block_geometry_registry.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';

enum GeometryCoordinateSpace { blockLocal, workspace, viewport, screen }

class GeometryResolver {
  const GeometryResolver(this.registry);

  final BlockGeometryRegistry registry;

  SpatialPoint resolvePoint(
    SpatialPoint point, {
    required GeometryCoordinateSpace from,
    required GeometryCoordinateSpace to,
    Uuid? blockId,
  }) {
    if (from == to) return point;
    final workspacePoint = _toWorkspace(point, from, blockId);
    return _fromWorkspace(workspacePoint, to, blockId);
  }

  SpatialRect resolveRect(
    SpatialRect rect, {
    required GeometryCoordinateSpace from,
    required GeometryCoordinateSpace to,
    Uuid? blockId,
  }) {
    final first = resolvePoint(
      rect.topLeft,
      from: from,
      to: to,
      blockId: blockId,
    );
    final second = resolvePoint(
      SpatialPoint(rect.right, rect.bottom),
      from: from,
      to: to,
      blockId: blockId,
    );
    final left = first.x < second.x ? first.x : second.x;
    final top = first.y < second.y ? first.y : second.y;
    final right = first.x > second.x ? first.x : second.x;
    final bottom = first.y > second.y ? first.y : second.y;
    return SpatialRect.fromLTRB(left, top, right, bottom);
  }

  SpatialPoint _toWorkspace(
    SpatialPoint point,
    GeometryCoordinateSpace from,
    Uuid? blockId,
  ) {
    final viewport = registry.viewport;
    switch (from) {
      case GeometryCoordinateSpace.workspace:
        return point;
      case GeometryCoordinateSpace.blockLocal:
        final block = _requireBlock(blockId);
        final screen = point + block.globalBounds.topLeft;
        return _screenToWorkspace(screen, viewport);
      case GeometryCoordinateSpace.viewport:
        return (viewport?.camera.viewportToWorkspace(point) ?? point) +
            (viewport?.scrollOffset ?? const SpatialPoint(0, 0));
      case GeometryCoordinateSpace.screen:
        return _screenToWorkspace(point, viewport);
    }
  }

  SpatialPoint _fromWorkspace(
    SpatialPoint point,
    GeometryCoordinateSpace to,
    Uuid? blockId,
  ) {
    final viewport = registry.viewport;
    switch (to) {
      case GeometryCoordinateSpace.workspace:
        return point;
      case GeometryCoordinateSpace.viewport:
        final logical =
            point - (viewport?.scrollOffset ?? const SpatialPoint(0, 0));
        return viewport?.camera.workspaceToViewport(logical) ?? logical;
      case GeometryCoordinateSpace.screen:
        final logical =
            point - (viewport?.scrollOffset ?? const SpatialPoint(0, 0));
        final viewportPoint =
            viewport?.camera.workspaceToViewport(logical) ?? logical;
        return viewportPoint +
            (viewport?.globalBounds.topLeft ?? const SpatialPoint(0, 0));
      case GeometryCoordinateSpace.blockLocal:
        final block = _requireBlock(blockId);
        final screen = _fromWorkspace(
          point,
          GeometryCoordinateSpace.screen,
          blockId,
        );
        return screen - block.globalBounds.topLeft;
    }
  }

  SpatialPoint _screenToWorkspace(
    SpatialPoint point,
    WorkspaceViewportGeometry? viewport,
  ) {
    if (viewport == null) return point;
    final viewportPoint = point - viewport.globalBounds.topLeft;
    return viewport.camera.viewportToWorkspace(viewportPoint) +
        viewport.scrollOffset;
  }

  BlockGeometryEntry _requireBlock(Uuid? blockId) {
    final block = blockId == null ? null : registry.geometryFor(blockId);
    if (block == null) {
      throw StateError(
        'Block geometry is required for block-local conversion.',
      );
    }
    return block;
  }
}
