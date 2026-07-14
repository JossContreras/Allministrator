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
    final topLeft = resolvePoint(
      rect.topLeft,
      from: from,
      to: to,
      blockId: blockId,
    );
    return SpatialRect.fromLTWH(topLeft.x, topLeft.y, rect.width, rect.height);
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
        return point + (viewport?.scrollOffset ?? const SpatialPoint(0, 0));
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
        return point - (viewport?.scrollOffset ?? const SpatialPoint(0, 0));
      case GeometryCoordinateSpace.screen:
        final viewportPoint =
            point - (viewport?.scrollOffset ?? const SpatialPoint(0, 0));
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
  ) =>
      point -
      (viewport?.globalBounds.topLeft ?? const SpatialPoint(0, 0)) +
      (viewport?.scrollOffset ?? const SpatialPoint(0, 0));

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
