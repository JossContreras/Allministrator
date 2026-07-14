import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkspaceInteractionController', () {
    test('keeps selected, focused and editing blocks independent', () {
      var requested = 0;
      var released = 0;
      final controller = WorkspaceInteractionController();
      controller.focusCoordinator.registerTarget(
        targetId: 'text-target',
        blockId: 'text',
        requestFocus: () => requested++,
        releaseFocus: () => released++,
      );

      controller.dispatch(const SelectBlockIntent('image'));
      expect(controller.context.selectedBlock, 'image');
      expect(controller.context.focusedBlock, isNull);
      expect(controller.context.editingBlock, isNull);
      expect(controller.context.interactionMode, InteractionMode.blockSelected);

      controller.dispatch(
        const StartEditingIntent(
          blockId: 'text',
          focusTargetId: 'text-target',
          selection: TextSelectionState(
            blockId: 'text',
            baseOffset: 3,
            extentOffset: 3,
          ),
        ),
      );
      expect(controller.context.selectedBlock, 'text');
      expect(controller.context.focusedBlock, 'text');
      expect(controller.context.editingBlock, 'text');
      expect(controller.context.interactionMode, InteractionMode.textEditing);
      expect(controller.context.currentSelection, isA<TextSelectionState>());
      expect(requested, 1);

      controller.dispatch(const FinishEditingIntent());
      expect(controller.context.selectedBlock, 'text');
      expect(controller.context.focusedBlock, isNull);
      expect(controller.context.editingBlock, isNull);
      expect(controller.context.interactionMode, InteractionMode.blockSelected);
      expect(released, 1);
    });

    test('updates text selection only for the active editing block', () {
      final controller = WorkspaceInteractionController()
        ..dispatch(const StartEditingIntent(blockId: 'text'));
      controller.dispatch(
        const UpdateTextSelectionIntent(
          TextSelectionState(blockId: 'other', baseOffset: 1, extentOffset: 2),
        ),
      );
      expect(
        (controller.context.currentSelection as BlockSelection).blockId,
        'text',
      );

      controller.dispatch(
        const UpdateTextSelectionIntent(
          TextSelectionState(blockId: 'text', baseOffset: 2, extentOffset: 5),
        ),
      );
      final selection =
          controller.context.currentSelection as TextSelectionState;
      expect(selection.baseOffset, 2);
      expect(selection.extentOffset, 5);
    });

    test('context menu and cancellation leave a consistent idle state', () {
      final controller = WorkspaceInteractionController();
      controller.dispatch(
        const OpenContextMenuIntent(
          blockId: 'image',
          anchor: InteractionPoint(10, 20),
        ),
      );
      expect(controller.context.interactionMode, InteractionMode.contextMenu);
      expect(controller.context.overlayState.isVisible, isTrue);
      expect(controller.context.activeSession, isNotNull);

      controller.dispatch(
        const CancelInteractionIntent(
          reason: InteractionCancellationReason.escape,
        ),
      );
      expect(controller.context.interactionMode, InteractionMode.idle);
      expect(controller.context.currentSelection, isA<NoSelection>());
      expect(controller.context.selectedBlock, isNull);
      expect(controller.context.focusedBlock, isNull);
      expect(controller.context.editingBlock, isNull);
      expect(controller.context.activeSession, isNull);
      expect(controller.context.overlayState.isVisible, isFalse);
    });

    test('focus loss uses the cancellation path and retains selection', () {
      final controller = WorkspaceInteractionController();
      controller.focusCoordinator.registerTarget(
        targetId: 'text-target',
        blockId: 'text',
        requestFocus: () {},
        releaseFocus: () {},
      );
      controller.dispatch(
        const StartEditingIntent(
          blockId: 'text',
          focusTargetId: 'text-target',
          selection: TextSelectionState(
            blockId: 'text',
            baseOffset: 4,
            extentOffset: 4,
          ),
        ),
      );
      controller.focusCoordinator.reportFocusChange(
        'text-target',
        hasFocus: false,
      );

      expect(controller.context.interactionMode, InteractionMode.blockSelected);
      expect(controller.context.selectedBlock, 'text');
      expect(controller.context.editingBlock, isNull);
      expect(controller.context.currentSelection, isA<TextSelectionState>());
    });

    test('prepared intents do not activate future interaction modes', () {
      final unhandled = <InteractionIntent>[];
      final controller = WorkspaceInteractionController(
        onUnhandledIntent: unhandled.add,
      );
      controller.dispatch(const BeginDragIntent('block'));
      controller.dispatch(const ResizeIntent('block'));
      controller.dispatch(const RotateIntent('block'));
      controller.dispatch(const StartHandwritingIntent());
      controller.dispatch(const PanViewportIntent(InteractionPoint(1, 2)));
      controller.dispatch(const ZoomViewportIntent(2));

      expect(unhandled, hasLength(6));
      expect(controller.context.interactionMode, InteractionMode.idle);
    });

    test('cell editing can focus without selecting its entire block', () {
      final controller = WorkspaceInteractionController()
        ..dispatch(
          const StartEditingIntent(blockId: 'table', selectBlock: false),
        );
      expect(controller.context.selectedBlock, isNull);
      expect(controller.context.focusedBlock, 'table');
      expect(controller.context.editingBlock, 'table');
      expect(controller.context.currentSelection, isA<NoSelection>());
    });

    test('selection invalidates only the previous and next block', () {
      final controller = WorkspaceInteractionController();
      var firstChanges = 0;
      var secondChanges = 0;
      var untouchedChanges = 0;
      controller.blockListenable('first').addListener(() => firstChanges++);
      controller.blockListenable('second').addListener(() => secondChanges++);
      controller
          .blockListenable('untouched')
          .addListener(() => untouchedChanges++);

      controller.dispatch(const SelectBlockIntent('first'));
      controller.dispatch(const SelectBlockIntent('second'));

      expect(firstChanges, 2);
      expect(secondChanges, 1);
      expect(untouchedChanges, 0);
    });
  });
}
