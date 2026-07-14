import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const workspace = 'workspace';
  const page = 'page';
  const source = 'source';
  const target = 'target';

  BlockGeometryRegistry registryWithBlocks() {
    final registry = BlockGeometryRegistry();
    registry.updateViewport(
      const WorkspaceViewportGeometry(
        globalBounds: SpatialRect.fromLTWH(0, 0, 400, 600),
      ),
    );
    registry.register(
      blockId: source,
      workspaceId: workspace,
      pageId: page,
      globalBounds: SpatialRect.fromLTWH(0, 20, 300, 60),
      localBounds: SpatialRect.fromLTWH(0, 20, 300, 60),
      layer: 0,
      lastLayoutPass: registry.nextLayoutPass,
    );
    registry.register(
      blockId: target,
      workspaceId: workspace,
      pageId: page,
      globalBounds: SpatialRect.fromLTWH(0, 120, 300, 60),
      localBounds: SpatialRect.fromLTWH(0, 120, 300, 60),
      layer: 1,
      lastLayoutPass: registry.nextLayoutPass,
    );
    return registry;
  }

  const movable = BlockInteractionInfo(
    capabilities: {BlockCapability.selectable, BlockCapability.movable},
  );

  test(
    'drag session starts, updates and cancels without Workspace mutation',
    () {
      final controller = WorkspaceInteractionController();
      addTearDown(controller.dispose);
      controller.dispatch(
        const UpdatePointerIntent(
          InteractionPointer(
            pointerId: 7,
            position: InteractionPoint(10, 30),
            isDown: true,
            blockId: source,
          ),
        ),
      );
      controller.dispatch(const BeginDragIntent(source));
      expect(controller.context.activeSession, isA<DragSession>());
      controller.dispatch(
        const UpdateDragIntent(
          position: InteractionPoint(20, 140),
          dropTarget: DropTarget(
            sourceBlockId: source,
            targetBlockId: target,
            insertAfter: true,
            isValid: true,
          ),
        ),
      );
      final drag = controller.context.activeSession! as DragSession;
      expect(drag.delta, const SpatialPoint(10, 110));
      controller.dispatch(
        const CancelInteractionIntent(
          reason: InteractionCancellationReason.escape,
          keepBlockSelected: true,
        ),
      );
      expect(controller.context.activeSession, isNull);
      expect(controller.context.selectedBlock, source);
    },
  );

  test('drag session carries a selected group in stable order', () {
    final controller = WorkspaceInteractionController();
    addTearDown(controller.dispose);
    controller.dispatch(const SelectBlockIntent('a'));
    controller.dispatch(const AddBlockToSelectionIntent('c'));
    controller.dispatch(
      const UpdatePointerIntent(
        InteractionPointer(
          pointerId: 9,
          position: InteractionPoint(0, 0),
          isDown: true,
        ),
      ),
    );
    controller.dispatch(const BeginDragIntent('c'));
    final drag = controller.context.activeSession! as DragSession;
    expect(drag.blockIds, ['a', 'c']);
    expect(drag.primaryBlockId, 'c');
  });

  test(
    'drop resolver yields before or after targets from runtime geometry',
    () {
      final registry = registryWithBlocks();
      addTearDown(registry.dispose);
      final resolver = DropResolver(
        registry: registry,
        blockInfo: (_) => movable,
      );
      expect(
        resolver
            .resolve(
              sourceBlockId: source,
              position: const SpatialPoint(20, 125),
            )
            .insertAfter,
        isFalse,
      );
      expect(
        resolver
            .resolve(
              sourceBlockId: source,
              position: const SpatialPoint(20, 170),
            )
            .insertAfter,
        isTrue,
      );
    },
  );

  test('auto scroll policy only activates near viewport edges', () {
    const policy = DragAutoScrollPolicy();
    const viewport = SpatialRect.fromLTWH(0, 100, 300, 400);
    expect(policy.deltaFor(110, viewport), lessThan(0));
    expect(policy.deltaFor(300, viewport), 0);
    expect(policy.deltaFor(490, viewport), greaterThan(0));
  });

  test('dispatcher commits a valid drop once and cancels invalid drops', () {
    final registry = registryWithBlocks();
    final controller = WorkspaceInteractionController();
    final commands = <InteractionIntent>[];
    final dispatcher = InputDispatcher(
      workspaceId: workspace,
      pageId: page,
      registry: registry,
      controller: controller,
      resolver: InteractionResolver(blockInfo: (_) => movable),
      dropResolver: DropResolver(registry: registry, blockInfo: (_) => movable),
      onCommand: (intent, _) => commands.add(intent),
    );
    addTearDown(registry.dispose);
    addTearDown(controller.dispose);
    addTearDown(dispatcher.dispose);

    dispatcher.dispatch(
      _pointer(NormalizedInputEventType.pointerDown, 'down', 1, 20, 30),
    );
    controller.dispatch(const BeginDragIntent(source));
    dispatcher.dispatch(
      _pointer(NormalizedInputEventType.pointerUp, 'up', 1, 20, 170),
    );
    expect(commands.single, isA<CommitDragIntent>());
    expect(controller.context.activeSession, isNull);

    dispatcher.dispatch(
      _pointer(NormalizedInputEventType.pointerDown, 'down-2', 2, 20, 30),
    );
    controller.dispatch(const BeginDragIntent(source));
    dispatcher.dispatch(
      _pointer(NormalizedInputEventType.pointerCancel, 'cancel', 2, 20, 30),
    );
    expect(controller.context.activeSession, isNull);
  });
}

NormalizedInputEvent _pointer(
  NormalizedInputEventType type,
  String id,
  int pointer,
  double x,
  double y,
) => NormalizedInputEvent(
  eventId: id,
  workspaceId: 'workspace',
  pageId: 'page',
  type: type,
  deviceType: InputDeviceType.touch,
  timestamp: DateTime.utc(2026),
  pointerId: pointer,
  globalPosition: SpatialPoint(x, y),
);
