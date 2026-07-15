import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'selection group is immutable, ordered and chooses deterministic primary',
    () {
      const empty = SelectionGroup();
      final group = empty.add('a').add('b').add('a').normalized();
      expect(empty.isEmpty, isTrue);
      expect(group.blockIds, ['a', 'b']);
      expect(group.primaryBlockId, 'a');
      expect(group.anchorBlockId, 'a');
      final reduced = group.remove('a');
      expect(reduced.primaryBlockId, 'b');
      expect(reduced.anchorBlockId, 'b');
    },
  );

  test(
    'controller supports add, toggle and visual ranges with one source of truth',
    () {
      final controller = WorkspaceInteractionController();
      addTearDown(controller.dispose);
      controller.dispatch(const SelectBlockIntent('b'));
      controller.dispatch(const AddBlockToSelectionIntent('c'));
      controller.dispatch(const ToggleBlockSelectionIntent('a'));
      expect(
        (controller.context.currentSelection as MultiBlockSelection)
            .group
            .blockIds,
        ['b', 'c', 'a'],
      );
      controller.dispatch(
        const SelectRangeIntent('d', visualOrder: ['a', 'b', 'c', 'd']),
      );
      final range = controller.context.currentSelection as MultiBlockSelection;
      expect(range.group.blockIds, ['b', 'c', 'd']);
      expect(range.group.primaryBlockId, 'd');
      expect(range.group.anchorBlockId, 'b');
    },
  );

  test(
    'resolver maps Ctrl/Cmd and Shift block activation to selection intents',
    () {
      final resolver = InteractionResolver(
        blockInfo: (_) => const BlockInteractionInfo(
          capabilities: {BlockCapability.selectable},
        ),
        visualOrder: () => const ['a', 'b', 'c'],
      );
      NormalizedInputEvent input(InputModifiers modifiers) =>
          NormalizedInputEvent(
            eventId: modifiers.shift ? 'shift' : 'command',
            workspaceId: 'workspace',
            pageId: 'page',
            type: NormalizedInputEventType.tap,
            deviceType: InputDeviceType.mouse,
            timestamp: DateTime.utc(2026),
            modifiers: modifiers,
            hitTarget: const BlockBackgroundHitTarget('c'),
          );
      expect(
        resolver
            .resolve(
              event: input(const InputModifiers(control: true)),
              context: const InteractionContext(),
            )
            .intent,
        isA<ToggleBlockSelectionIntent>(),
      );
      expect(
        resolver
            .resolve(
              event: input(const InputModifiers(shift: true)),
              context: const InteractionContext(),
            )
            .intent,
        isA<SelectRangeIntent>(),
      );
    },
  );

  test('marquee bounds select only blocks with a meaningful intersection', () {
    final registry = BlockGeometryRegistry();
    addTearDown(registry.dispose);
    registry.updateViewport(
      const WorkspaceViewportGeometry(
        globalBounds: SpatialRect.fromLTWH(0, 0, 400, 400),
      ),
    );
    for (final entry in [('a', 0.0), ('b', 100.0), ('c', 200.0)]) {
      registry.register(
        blockId: entry.$1,
        workspaceId: 'workspace',
        pageId: 'page',
        globalBounds: SpatialRect.fromLTWH(0, entry.$2, 200, 80),
        localBounds: SpatialRect.fromLTWH(0, entry.$2, 200, 80),
        layer: entry.$2.toInt(),
        lastLayoutPass: registry.nextLayoutPass,
      );
    }
    final resolver = SelectionBoundsResolver(registry);
    expect(resolver.intersecting(const SpatialRect.fromLTWH(0, 20, 200, 130)), [
      'a',
      'b',
    ]);
    expect(
      resolver.resolve(const SelectionGroup(blockIds: ['a', 'c'])),
      const SpatialRect.fromLTRB(0, 0, 200, 280),
    );
  });

  test(
    'marquee commits temporary candidates without persistence side effects',
    () {
      final controller = WorkspaceInteractionController();
      addTearDown(controller.dispose);
      controller.dispatch(
        const UpdatePointerIntent(
          InteractionPointer(
            pointerId: 1,
            position: InteractionPoint(0, 0),
            isDown: true,
          ),
        ),
      );
      controller.dispatch(
        const BeginMarqueeSelectionIntent(InteractionPoint(0, 0)),
      );
      controller.dispatch(
        const UpdateMarqueeSelectionIntent(
          position: InteractionPoint(100, 100),
          candidateIds: ['a', 'b'],
        ),
      );
      expect(
        (controller.context.currentSelection as MultiBlockSelection)
            .group
            .isTemporary,
        isTrue,
      );
      controller.dispatch(const CommitMarqueeSelectionIntent());
      final committed =
          controller.context.currentSelection as MultiBlockSelection;
      expect(committed.group.blockIds, ['a', 'b']);
      expect(committed.group.isTemporary, isFalse);
    },
  );

  test('marquee only starts when its explicit mode is enabled', () {
    var enabled = false;
    final resolver = InteractionResolver(canStartMarquee: () => enabled);
    final event = NormalizedInputEvent(
      eventId: 'pointer-down',
      workspaceId: 'workspace',
      pageId: 'page',
      type: NormalizedInputEventType.pointerDown,
      deviceType: InputDeviceType.touch,
      timestamp: DateTime.utc(2026),
      pointerId: 1,
      globalPosition: const SpatialPoint(20, 30),
      hitTarget: const EmptyAreaHitTarget(),
    );

    expect(
      resolver.resolve(event: event, context: const InteractionContext()).kind,
      InteractionIntentResultKind.ignored,
    );
    enabled = true;
    expect(
      resolver
          .resolve(event: event, context: const InteractionContext())
          .intent,
      isA<BeginMarqueeSelectionIntent>(),
    );
  });

  test(
    'Delete delegates to text editing and targets blocks outside editing',
    () {
      final event = NormalizedInputEvent(
        eventId: 'delete',
        workspaceId: 'workspace',
        pageId: 'page',
        type: NormalizedInputEventType.keyDown,
        deviceType: InputDeviceType.keyboard,
        timestamp: DateTime.utc(2026),
        key: 'Delete',
      );
      const resolver = InteractionResolver();
      expect(
        resolver
            .resolve(
              event: event,
              context: InteractionContext(
                selectedBlock: 'text',
                editingBlock: 'text',
                currentSelection: BlockSelection('text'),
              ),
            )
            .kind,
        InteractionIntentResultKind.delegatedToNative,
      );
      expect(
        resolver
            .resolve(
              event: event,
              context: InteractionContext(
                selectedBlock: 'block',
                currentSelection: BlockSelection('block'),
              ),
            )
            .intent,
        isA<DeleteSelectionIntent>(),
      );
    },
  );
}
