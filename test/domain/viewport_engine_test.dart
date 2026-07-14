import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('camera keeps the focal workspace point stable and clamps zoom', () {
    final controller = WorkspaceViewportController(minZoom: .5, maxZoom: 2);
    addTearDown(controller.dispose);

    controller.setZoom(2, focalPoint: const SpatialPoint(100, 80));
    expect(controller.camera.zoom, 2);
    expect(
      controller.camera.workspaceToViewport(const SpatialPoint(100, 80)),
      const SpatialPoint(100, 80),
    );

    controller.panBy(const SpatialPoint(10, -5));
    expect(controller.camera.translation, const SpatialPoint(-90, -85));
    controller.setZoom(10, focalPoint: const SpatialPoint(0, 0));
    expect(controller.camera.zoom, 2);
  });

  test('geometry resolver accounts for camera, scroll and screen origin', () {
    final registry = BlockGeometryRegistry();
    addTearDown(registry.dispose);
    registry.updateViewport(
      const WorkspaceViewportGeometry(
        globalBounds: SpatialRect.fromLTWH(10, 20, 400, 500),
        scrollOffset: SpatialPoint(0, 50),
        camera: WorkspaceCamera(zoom: 2, translation: SpatialPoint(5, 10)),
      ),
    );
    final resolver = GeometryResolver(registry);
    const workspace = SpatialPoint(25, 105);
    final screen = resolver.resolvePoint(
      workspace,
      from: GeometryCoordinateSpace.workspace,
      to: GeometryCoordinateSpace.screen,
    );
    expect(screen, const SpatialPoint(65, 140));
    expect(
      resolver.resolvePoint(
        screen,
        from: GeometryCoordinateSpace.screen,
        to: GeometryCoordinateSpace.workspace,
      ),
      workspace,
    );
    expect(
      resolver
          .resolveRect(
            const SpatialRect.fromLTWH(0, 50, 100, 40),
            from: GeometryCoordinateSpace.workspace,
            to: GeometryCoordinateSpace.screen,
          )
          .width,
      200,
    );
  });

  test('registry transforms entries when camera changes', () {
    final registry = BlockGeometryRegistry();
    addTearDown(registry.dispose);
    registry.updateViewport(
      const WorkspaceViewportGeometry(
        globalBounds: SpatialRect.fromLTWH(0, 0, 400, 400),
      ),
    );
    registry.register(
      blockId: 'block',
      workspaceId: 'workspace',
      pageId: 'page',
      globalBounds: const SpatialRect.fromLTWH(20, 30, 100, 40),
      localBounds: const SpatialRect.fromLTWH(0, 0, 100, 40),
      layer: 0,
      lastLayoutPass: registry.nextLayoutPass,
    );
    registry.updateViewport(
      const WorkspaceViewportGeometry(
        globalBounds: SpatialRect.fromLTWH(0, 0, 400, 400),
        camera: WorkspaceCamera(zoom: 2),
      ),
    );
    expect(
      registry.geometryFor('block')!.globalBounds,
      const SpatialRect.fromLTWH(40, 60, 200, 80),
    );
  });

  test('marquee and drop resolution consume transformed registry geometry', () {
    final registry = BlockGeometryRegistry();
    addTearDown(registry.dispose);
    registry.updateViewport(
      const WorkspaceViewportGeometry(
        globalBounds: SpatialRect.fromLTWH(0, 0, 500, 500),
      ),
    );
    for (final entry in [
      ('a', const SpatialRect.fromLTWH(10, 20, 100, 40)),
      ('b', const SpatialRect.fromLTWH(10, 100, 100, 40)),
    ]) {
      registry.register(
        blockId: entry.$1,
        workspaceId: 'workspace',
        pageId: 'page',
        globalBounds: entry.$2,
        localBounds: const SpatialRect.fromLTWH(0, 0, 100, 40),
        layer: 0,
        lastLayoutPass: registry.nextLayoutPass,
      );
    }
    registry.updateViewport(
      const WorkspaceViewportGeometry(
        globalBounds: SpatialRect.fromLTWH(0, 0, 500, 500),
        camera: WorkspaceCamera(zoom: 2),
      ),
    );

    expect(
      SelectionBoundsResolver(
        registry,
      ).intersecting(const SpatialRect.fromLTWH(15, 35, 220, 90)),
      ['a'],
    );
    final target =
        DropResolver(
          registry: registry,
          blockInfo: (_) => const BlockInteractionInfo(
            capabilities: {BlockCapability.movable},
          ),
        ).resolve(
          sourceBlockId: 'a',
          position: registry.geometryFor('b')!.globalBounds.center,
        );
    expect(target.targetBlockId, 'b');
    expect(target.isValid, isTrue);
  });
}
