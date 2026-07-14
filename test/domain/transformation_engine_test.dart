import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resize snaps edges and emits a smart guide', () {
    final session = ResizeSession(
      id: 'resize',
      startedAt: DateTime.utc(2026),
      blockId: 'image',
      pointerId: 1,
      handle: ResizeHandle.southEast,
      startPosition: const SpatialPoint(100, 80),
      currentPosition: const SpatialPoint(100, 80),
      initialBounds: const SpatialRect.fromLTWH(0, 0, 100, 80),
      previewBounds: const SpatialRect.fromLTWH(0, 0, 100, 80),
    );
    final result = const SnapResolver().resolveResize(
      session: session,
      position: const SpatialPoint(150, 120),
      candidates: const [SpatialRect.fromLTWH(152, 125, 40, 40)],
    );

    expect(result.bounds.right, 152);
    expect(result.bounds.bottom, 125);
    expect(result.guides, hasLength(2));
  });

  test('align and distribute return deterministic deltas', () {
    const engine = TransformationEngine();
    final bounds = {
      'a': const SpatialRect.fromLTWH(0, 0, 100, 20),
      'b': const SpatialRect.fromLTWH(150, 70, 50, 20),
      'c': const SpatialRect.fromLTWH(100, 200, 100, 20),
    };
    final aligned = engine.align(bounds, BlockAlignmentAxis.right);
    expect(aligned['a'], const SpatialPoint(100, 0));
    expect(aligned['b'], const SpatialPoint(0, 0));

    final distributed = engine.distributeVertically(const [
      'a',
      'b',
      'c',
    ], bounds);
    expect(distributed['a'], const SpatialPoint(0, 0));
    expect(distributed['b'], const SpatialPoint(0, 30));
    expect(distributed['c'], const SpatialPoint(0, 0));
  });

  test('dispatcher runs one resize session and commits workspace bounds', () {
    final registry = BlockGeometryRegistry();
    final controller = WorkspaceInteractionController();
    final commands = <InteractionIntent>[];
    addTearDown(registry.dispose);
    addTearDown(controller.dispose);
    registry.updateViewport(
      const WorkspaceViewportGeometry(
        globalBounds: SpatialRect.fromLTWH(0, 0, 500, 500),
        camera: WorkspaceCamera(zoom: 2),
      ),
    );
    registry.register(
      blockId: 'image',
      workspaceId: 'workspace',
      pageId: 'page',
      globalBounds: const SpatialRect.fromLTWH(20, 20, 200, 120),
      localBounds: const SpatialRect.fromLTWH(0, 0, 100, 60),
      layer: 0,
      lastLayoutPass: registry.nextLayoutPass,
    );
    final resolver = InteractionResolver(
      blockInfo: (_) => const BlockInteractionInfo(
        capabilities: {BlockCapability.selectable, BlockCapability.resizable},
      ),
      blockBounds: (id) => registry.geometryFor(id)?.globalBounds,
    );
    final dispatcher = InputDispatcher(
      workspaceId: 'workspace',
      pageId: 'page',
      registry: registry,
      controller: controller,
      resolver: resolver,
      onCommand: (intent, _) => commands.add(intent),
    );
    addTearDown(dispatcher.dispose);

    dispatcher.dispatch(
      _pointer(
        id: 'down',
        type: NormalizedInputEventType.pointerDown,
        position: const SpatialPoint(220, 140),
        target: const ResizeHandleHitTarget(
          'image',
          handle: ResizeHandle.southEast,
        ),
      ),
    );
    expect(controller.context.activeSession, isA<ResizeSession>());
    dispatcher.dispatch(
      _pointer(
        id: 'move',
        type: NormalizedInputEventType.pointerMove,
        position: const SpatialPoint(260, 160),
      ),
    );
    dispatcher.dispatch(
      _pointer(
        id: 'up',
        type: NormalizedInputEventType.pointerUp,
        position: const SpatialPoint(260, 160),
      ),
    );

    expect(controller.context.activeSession, isNull);
    final commit = commands.single as CommitResizeIntent;
    expect(commit.bounds.width, 120);
    expect(commit.bounds.height, 70);
  });
}

NormalizedInputEvent _pointer({
  required String id,
  required NormalizedInputEventType type,
  required SpatialPoint position,
  WorkspaceHitTarget? target,
}) => NormalizedInputEvent(
  eventId: id,
  workspaceId: 'workspace',
  pageId: 'page',
  type: type,
  deviceType: InputDeviceType.mouse,
  timestamp: DateTime.utc(2026),
  pointerId: 1,
  globalPosition: position,
  hitTarget: target,
  targetBlockId: target?.blockId,
);
