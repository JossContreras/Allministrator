import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const workspaceId = 'workspace';
  const pageId = 'page';
  const blockId = 'block';

  NormalizedInputEvent event(
    NormalizedInputEventType type, {
    WorkspaceHitTarget? target,
    int? pointerId,
    String id = 'event',
  }) => NormalizedInputEvent(
    eventId: id,
    workspaceId: workspaceId,
    pageId: pageId,
    type: type,
    deviceType: InputDeviceType.touch,
    timestamp: DateTime.utc(2026),
    pointerId: pointerId,
    globalPosition: const SpatialPoint(20, 20),
    hitTarget: target,
    targetBlockId: target?.blockId,
  );

  final resolver = InteractionResolver(
    blockInfo: (_) => const BlockInteractionInfo(
      capabilities: {
        BlockCapability.selectable,
        BlockCapability.editable,
        BlockCapability.movable,
        BlockCapability.openable,
      },
    ),
  );

  test('normalized input preserves device-specific optional data', () {
    final stylus = NormalizedInputEvent(
      eventId: 'stylus',
      workspaceId: workspaceId,
      pageId: pageId,
      type: NormalizedInputEventType.stylusHover,
      deviceType: InputDeviceType.stylus,
      timestamp: DateTime.utc(2026),
      globalPosition: const SpatialPoint(1, 2),
      pressure: .7,
      tilt: const SpatialPoint(.2, .3),
      modifiers: const InputModifiers(shift: true),
    );

    expect(stylus.pressure, .7);
    expect(stylus.tilt, const SpatialPoint(.2, .3));
    expect(stylus.modifiers.shift, isTrue);
  });

  test('resolver applies central interaction priorities', () {
    final empty = resolver.resolve(
      event: event(NormalizedInputEventType.tap),
      context: const InteractionContext(),
    );
    expect(empty.intent, isA<ClearSelectionIntent>());

    final text = resolver.resolve(
      event: event(
        NormalizedInputEventType.tap,
        target: const TextRegionHitTarget(blockId, fieldId: 'text-block'),
      ),
      context: const InteractionContext(),
    );
    expect(text.intent, isA<StartEditingIntent>());
    expect(text.priority, InteractionPriority.editableRegion);

    final nativeSelection = resolver.resolve(
      event: event(
        NormalizedInputEventType.longPressStart,
        target: const TextRegionHitTarget(blockId),
      ),
      context: const InteractionContext(),
    );
    expect(nativeSelection.kind, InteractionIntentResultKind.delegatedToNative);

    final checkbox = resolver.resolve(
      event: event(
        NormalizedInputEventType.tap,
        target: const InternalControlHitTarget(blockId, controlId: 'check-a'),
      ),
      context: const InteractionContext(),
    );
    expect(checkbox.intent, isA<InternalBlockActionIntent>());
    expect(checkbox.priority, InteractionPriority.internalControl);

    final drag = resolver.resolve(
      event: event(
        NormalizedInputEventType.longPressStart,
        target: const BlockHandleHitTarget(blockId),
      ),
      context: const InteractionContext(),
    );
    expect(drag.intent, isA<BeginDragIntent>());

    final modal = resolver.resolve(
      event: event(
        NormalizedInputEventType.tap,
        target: const BlockBackgroundHitTarget(blockId),
      ),
      context: const InteractionContext(),
      modalActive: true,
    );
    expect(modal.kind, InteractionIntentResultKind.consumed);
    expect(modal.priority, InteractionPriority.modal);
  });

  test(
    'dispatcher rejects duplicates, invalid pages and invalid pointer order',
    () {
      final registry = BlockGeometryRegistry();
      final controller = WorkspaceInteractionController();
      final dispatcher = InputDispatcher(
        workspaceId: workspaceId,
        pageId: pageId,
        registry: registry,
        controller: controller,
        resolver: resolver,
      );
      addTearDown(registry.dispose);
      addTearDown(controller.dispose);
      addTearDown(dispatcher.dispose);

      final down = event(
        NormalizedInputEventType.pointerDown,
        pointerId: 1,
        id: 'down',
      );
      expect(
        dispatcher.dispatch(down).resolution.kind,
        InteractionIntentResultKind.ignored,
      );
      expect(dispatcher.dispatch(down).resolution.reason, 'duplicate-event');
      expect(
        dispatcher
            .dispatch(
              event(NormalizedInputEventType.pointerUp, pointerId: 2, id: 'up'),
            )
            .resolution
            .reason,
        'up-without-active-pointer',
      );
      final wrongPage = NormalizedInputEvent(
        eventId: 'wrong-page',
        workspaceId: workspaceId,
        pageId: 'other',
        type: NormalizedInputEventType.tap,
        deviceType: InputDeviceType.mouse,
        timestamp: DateTime.utc(2026),
      );
      expect(
        dispatcher.dispatch(wrongPage).resolution.kind,
        InteractionIntentResultKind.rejected,
      );
    },
  );

  test('overlay state is derived and cleans up when geometry disappears', () {
    final registry = BlockGeometryRegistry();
    final controller = WorkspaceInteractionController();
    final overlay = InteractionOverlayController(
      interaction: controller,
      registry: registry,
    );
    addTearDown(registry.dispose);
    addTearDown(controller.dispose);
    addTearDown(overlay.dispose);
    registry.register(
      blockId: blockId,
      workspaceId: workspaceId,
      pageId: pageId,
      globalBounds: SpatialRect.fromLTWH(0, 0, 100, 40),
      localBounds: SpatialRect.fromLTWH(0, 0, 100, 40),
      layer: 0,
      lastLayoutPass: registry.nextLayoutPass,
    );
    controller.dispatch(const SelectBlockIntent(blockId));
    expect(overlay.state.showHandle, isTrue);
    controller.dispatch(const StartEditingIntent(blockId: blockId));
    expect(overlay.state.showSelectionBorder, isFalse);
    registry.remove(blockId);
    expect(overlay.state.selectedBounds, isNull);
  });

  test('debug timeline is bounded and excludes document content', () {
    final timeline = InteractionDebugTimeline(limit: 2);
    for (var index = 0; index < 3; index++) {
      timeline.add(
        InputDispatchResult(
          event: event(NormalizedInputEventType.tap, id: 'debug-$index'),
          resolution: const InteractionIntentResult.state(
            InteractionIntentResultKind.ignored,
          ),
        ),
      );
    }
    expect(timeline.entries, hasLength(2));
    expect(
      timeline.entries.every((entry) => entry.target != 'documentText'),
      isTrue,
    );
    timeline.clear();
    expect(timeline.entries, isEmpty);
  });
}
