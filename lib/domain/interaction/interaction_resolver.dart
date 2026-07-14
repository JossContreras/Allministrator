import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/interaction/interaction_commands.dart';
import 'package:allministrator/domain/interaction/interaction_intent_result.dart';
import 'package:allministrator/domain/interaction/interaction_intents.dart';
import 'package:allministrator/domain/interaction/interaction_models.dart';
import 'package:allministrator/domain/interaction/normalized_input_event.dart';
import 'package:allministrator/domain/interaction/workspace_hit_target.dart';

typedef BlockInteractionInfoResolver =
    BlockInteractionInfo? Function(String blockId);

class BlockInteractionInfo {
  const BlockInteractionInfo({
    required this.capabilities,
    this.isLocked = false,
  });

  final Set<BlockCapability> capabilities;
  final bool isLocked;

  bool supports(BlockCapability capability) =>
      !isLocked && capabilities.contains(capability);
}

/// Converts neutral input plus current context into an intention. It contains
/// no Workspace mutation and can therefore be exhaustively unit tested.
class InteractionResolver {
  const InteractionResolver({this.blockInfo});

  final BlockInteractionInfoResolver? blockInfo;

  InteractionIntentResult resolve({
    required NormalizedInputEvent event,
    required InteractionContext context,
    bool modalActive = false,
  }) {
    final target = event.hitTarget ?? const EmptyAreaHitTarget();
    if (modalActive) {
      if (_isEscape(event)) {
        return const InteractionIntentResult.intent(
          CancelInteractionIntent(
            reason: InteractionCancellationReason.escape,
            keepBlockSelected: true,
          ),
          priority: InteractionPriority.modal,
        );
      }
      return InteractionIntentResult.state(
        InteractionIntentResultKind.consumed,
        reason: 'modal-active',
        priority: InteractionPriority.modal,
        target: target,
      );
    }
    if (_isEscape(event)) {
      return const InteractionIntentResult.intent(
        CancelInteractionIntent(reason: InteractionCancellationReason.escape),
        priority: InteractionPriority.viewport,
      );
    }
    if (event.type == NormalizedInputEventType.pointerCancel) {
      return const InteractionIntentResult.intent(
        CancelInteractionIntent(reason: InteractionCancellationReason.explicit),
        priority: InteractionPriority.viewport,
      );
    }
    if (event.type == NormalizedInputEventType.longPressStart &&
        target is BlockHandleHitTarget) {
      return _allowed(
        target.blockId!,
        BlockCapability.movable,
        BeginDragIntent(target.blockId!),
        InteractionPriority.handle,
        target,
      );
    }
    if (target is InternalControlHitTarget && _isActivation(event)) {
      return InteractionIntentResult.intent(
        InternalBlockActionIntent(
          blockId: target.blockId!,
          actionId: target.controlId,
        ),
        priority: InteractionPriority.internalControl,
        target: target,
      );
    }
    if (target is AttachmentActionHitTarget && _isActivation(event)) {
      if (target.actionId == 'open') {
        return _allowed(
          target.blockId!,
          BlockCapability.openable,
          OpenAttachmentIntent(target.blockId!),
          InteractionPriority.internalControl,
          target,
        );
      }
      return InteractionIntentResult.state(
        InteractionIntentResultKind.consumed,
        priority: InteractionPriority.internalControl,
        target: target,
      );
    }
    if (target is TableCellHitTarget && _isActivation(event)) {
      return _allowed(
        target.blockId!,
        BlockCapability.editable,
        StartEditingIntent(
          blockId: target.blockId!,
          focusTargetId: 'table-cell-${target.blockId}-${target.cellId}',
          selectBlock: false,
        ),
        InteractionPriority.internalControl,
        target,
      );
    }
    if (target is TextRegionHitTarget) {
      if (event.type == NormalizedInputEventType.longPressStart) {
        return InteractionIntentResult.state(
          InteractionIntentResultKind.delegatedToNative,
          reason: 'native-text-selection',
          priority: InteractionPriority.nativeText,
          target: target,
        );
      }
      if (_isActivation(event)) {
        return _allowed(
          target.blockId!,
          BlockCapability.editable,
          StartEditingIntent(
            blockId: target.blockId!,
            focusTargetId: target.fieldId,
          ),
          InteractionPriority.editableRegion,
          target,
        );
      }
    }
    if (target is CustomRegionHitTarget &&
        target.name == 'code-copy' &&
        _isActivation(event)) {
      return InteractionIntentResult.intent(
        CopyCodeIntent(target.blockId!),
        priority: InteractionPriority.internalControl,
        target: target,
      );
    }
    if (target is EmptyAreaHitTarget && _isActivation(event)) {
      return const InteractionIntentResult.intent(
        ClearSelectionIntent(reason: InteractionCancellationReason.outsideTap),
        priority: InteractionPriority.emptyArea,
      );
    }
    if ((target is BlockHandleHitTarget ||
            target is BlockBackgroundHitTarget ||
            target is BlockContentHitTarget ||
            target is CustomRegionHitTarget) &&
        _isActivation(event) &&
        target.blockId != null) {
      return _allowed(
        target.blockId!,
        BlockCapability.selectable,
        SelectBlockIntent(target.blockId!),
        target is BlockHandleHitTarget
            ? InteractionPriority.handle
            : InteractionPriority.blockRegion,
        target,
      );
    }
    return InteractionIntentResult.state(
      InteractionIntentResultKind.ignored,
      reason: 'no-rule',
      target: target,
    );
  }

  InteractionIntentResult _allowed(
    String blockId,
    BlockCapability capability,
    InteractionIntent intent,
    InteractionPriority priority,
    WorkspaceHitTarget target,
  ) {
    final info = blockInfo?.call(blockId);
    if (info != null && !info.supports(capability)) {
      return InteractionIntentResult.state(
        InteractionIntentResultKind.rejected,
        reason: info.isLocked ? 'block-locked' : 'capability-missing',
        priority: priority,
        target: target,
      );
    }
    return InteractionIntentResult.intent(
      intent,
      priority: priority,
      target: target,
    );
  }

  bool _isActivation(NormalizedInputEvent event) =>
      event.type == NormalizedInputEventType.tap ||
      event.type == NormalizedInputEventType.doubleTap ||
      event.type == NormalizedInputEventType.accessibilityAction;

  bool _isEscape(NormalizedInputEvent event) =>
      event.type == NormalizedInputEventType.keyDown && event.key == 'Escape';
}
