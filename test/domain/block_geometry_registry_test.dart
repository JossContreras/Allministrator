import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BlockGeometryRegistry', () {
    test('registers, updates and avoids duplicate layout notifications', () {
      final registry = BlockGeometryRegistry();
      var notifications = 0;
      registry.addListener(() => notifications++);
      registry.updateViewport(
        const WorkspaceViewportGeometry(
          globalBounds: SpatialRect.fromLTWH(0, 0, 400, 600),
        ),
      );
      registry.register(
        blockId: 'block',
        workspaceId: 'workspace',
        pageId: 'page',
        globalBounds: const SpatialRect.fromLTWH(20, 40, 200, 80),
        localBounds: const SpatialRect.fromLTWH(0, 0, 200, 80),
        layer: 1,
        lastLayoutPass: registry.nextLayoutPass,
      );
      final afterRegistration = notifications;

      registry.register(
        blockId: 'block',
        workspaceId: 'workspace',
        pageId: 'page',
        globalBounds: const SpatialRect.fromLTWH(20, 40, 200, 80),
        localBounds: const SpatialRect.fromLTWH(0, 0, 200, 80),
        layer: 1,
        lastLayoutPass: registry.nextLayoutPass,
      );

      expect(notifications, afterRegistration);
      final entry = registry.geometryFor('block')!;
      expect(entry.workspaceId, 'workspace');
      expect(entry.pageId, 'page');
      expect(entry.visibleBounds, entry.globalBounds);
      expect(entry.isVisible, isTrue);
    });

    test('updates visible bounds for viewport, scroll and rotation', () {
      final registry = BlockGeometryRegistry();
      registry.updateViewport(
        const WorkspaceViewportGeometry(
          globalBounds: SpatialRect.fromLTWH(0, 0, 300, 200),
        ),
      );
      registry.register(
        blockId: 'block',
        workspaceId: 'workspace',
        pageId: 'page',
        globalBounds: const SpatialRect.fromLTWH(20, 150, 200, 100),
        localBounds: const SpatialRect.fromLTWH(0, 0, 200, 100),
        layer: 0,
        lastLayoutPass: registry.nextLayoutPass,
      );
      expect(registry.geometryFor('block')!.visibleBounds.height, 50);

      registry.updateViewport(
        const WorkspaceViewportGeometry(
          globalBounds: SpatialRect.fromLTWH(0, 0, 200, 300),
          scrollOffset: SpatialPoint(0, 40),
          keyboardInset: 80,
        ),
      );
      final rotated = registry.geometryFor('block')!;
      expect(rotated.visibleBounds.width, 180);
      expect(rotated.visibleBounds.height, 100);
      expect(registry.viewport!.scrollOffset.y, 40);
    });

    test('hit testing prioritizes real regions and top layers', () {
      final registry = BlockGeometryRegistry();
      registry.updateViewport(
        const WorkspaceViewportGeometry(
          globalBounds: SpatialRect.fromLTWH(0, 0, 500, 500),
        ),
      );
      for (final data in [('back', 0), ('front', 2)]) {
        registry.register(
          blockId: data.$1,
          workspaceId: 'workspace',
          pageId: 'page',
          globalBounds: const SpatialRect.fromLTWH(20, 20, 200, 100),
          localBounds: const SpatialRect.fromLTWH(0, 0, 200, 100),
          layer: data.$2,
          lastLayoutPass: registry.nextLayoutPass,
        );
      }
      registry.updateRegion(
        const InteractionRegion(
          id: 'cell',
          blockId: 'front',
          target: TableCellHitTarget(
            'front',
            cellId: 'cell-1',
            rowIndex: 0,
            columnIndex: 0,
          ),
          globalBounds: SpatialRect.fromLTWH(30, 30, 80, 40),
          localBounds: SpatialRect.fromLTWH(10, 10, 80, 40),
          priority: 20,
        ),
      );

      final cell = registry.hitTest(const SpatialPoint(40, 40));
      expect(cell.target, isA<TableCellHitTarget>());
      expect(cell.target.blockId, 'front');
      final background = registry.hitTest(const SpatialPoint(200, 100));
      expect(background.target, isA<BlockBackgroundHitTarget>());
      expect(background.target.blockId, 'front');
      expect(
        registry.hitTest(const SpatialPoint(480, 480)).target,
        isA<EmptyAreaHitTarget>(),
      );
    });

    test('removes deleted blocks and stale regions', () {
      final registry = BlockGeometryRegistry();
      for (final blockId in ['keep', 'remove']) {
        registry.register(
          blockId: blockId,
          workspaceId: 'workspace',
          pageId: 'page',
          globalBounds: const SpatialRect.fromLTWH(0, 0, 20, 20),
          localBounds: const SpatialRect.fromLTWH(0, 0, 20, 20),
          layer: 0,
          lastLayoutPass: registry.nextLayoutPass,
        );
      }
      registry.retainOnly({'keep'});
      expect(registry.geometryFor('keep'), isNotNull);
      expect(registry.geometryFor('remove'), isNull);
      expect(registry.entries, hasLength(1));
    });
  });

  test('GeometryResolver transforms block, workspace, viewport and screen', () {
    final registry = BlockGeometryRegistry();
    registry.updateViewport(
      const WorkspaceViewportGeometry(
        globalBounds: SpatialRect.fromLTWH(10, 20, 300, 400),
        scrollOffset: SpatialPoint(0, 50),
      ),
    );
    registry.register(
      blockId: 'block',
      workspaceId: 'workspace',
      pageId: 'page',
      globalBounds: const SpatialRect.fromLTWH(30, 70, 100, 40),
      localBounds: const SpatialRect.fromLTWH(0, 0, 100, 40),
      layer: 0,
      lastLayoutPass: registry.nextLayoutPass,
    );
    final resolver = GeometryResolver(registry);

    final workspace = resolver.resolvePoint(
      const SpatialPoint(5, 5),
      from: GeometryCoordinateSpace.blockLocal,
      to: GeometryCoordinateSpace.workspace,
      blockId: 'block',
    );
    expect(workspace, const SpatialPoint(25, 105));
    expect(
      resolver.resolvePoint(
        workspace,
        from: GeometryCoordinateSpace.workspace,
        to: GeometryCoordinateSpace.screen,
      ),
      const SpatialPoint(35, 75),
    );
    expect(
      resolver.resolvePoint(
        workspace,
        from: GeometryCoordinateSpace.workspace,
        to: GeometryCoordinateSpace.blockLocal,
        blockId: 'block',
      ),
      const SpatialPoint(5, 5),
    );
  });
}
