import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/interaction/interaction_commands.dart';
import 'package:allministrator/domain/interaction/interaction_intent_result.dart';
import 'package:allministrator/domain/interaction/interaction_intents.dart';
import 'package:allministrator/domain/interaction/interaction_models.dart';
import 'package:allministrator/domain/interaction/normalized_input_event.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';
import 'package:allministrator/domain/interaction/workspace_hit_target.dart';
import 'package:allministrator/domain/ink/ink_models.dart';

typedef BlockInteractionInfoResolver =
    BlockInteractionInfo? Function(String blockId);
typedef VisualBlockOrderResolver = List<String> Function();
typedef BlockBoundsResolver = SpatialRect? Function(String blockId);
typedef MarqueeActivationResolver = bool Function();
typedef InkBrushResolver = InkBrushStyle Function(WorkspaceTool tool);
typedef InkAnchorResolver =
    AnnotationAnchor? Function(NormalizedInputEvent event);

class BlockInteractionInfo {
  const BlockInteractionInfo({
    required this.capabilities,
    this.isLocked = false,
  });

  final Set<BlockCapability> capabilities;
  final bool isLocked;

  /// A locked block is still selectable.  Selection is how the user reaches
  /// its contextual actions (most importantly, unlock and delete); only
  /// mutations are disabled while it is locked.
  bool supports(BlockCapability capability) =>
      capabilities.contains(capability) &&
      (!isLocked || capability == BlockCapability.selectable);
}

/// Converts neutral input plus current context into an intention. It contains
/// no Workspace mutation and can therefore be exhaustively unit tested.
class InteractionResolver {
  const InteractionResolver({
    this.blockInfo,
    this.visualOrder,
    this.blockBounds,
    this.canStartMarquee,
    this.inkBrush,
    this.inkAnchor,
  });

  final BlockInteractionInfoResolver? blockInfo;
  final VisualBlockOrderResolver? visualOrder;
  final BlockBoundsResolver? blockBounds;
  final MarqueeActivationResolver? canStartMarquee;
  final InkBrushResolver? inkBrush;
  final InkAnchorResolver? inkAnchor;

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
    if (_isDelete(event)) {
      if (context.editingBlock != null) {
        return const InteractionIntentResult.state(
          InteractionIntentResultKind.delegatedToNative,
          reason: 'native-text-delete',
          priority: InteractionPriority.nativeText,
        );
      }
      if (_hasSelection(context)) {
        return const InteractionIntentResult.intent(
          DeleteSelectionIntent(),
          priority: InteractionPriority.viewport,
        );
      }
    }
    if (event.type == NormalizedInputEventType.pointerCancel) {
      return const InteractionIntentResult.intent(
        CancelInteractionIntent(reason: InteractionCancellationReason.explicit),
        priority: InteractionPriority.viewport,
      );
    }
    if (event.type == NormalizedInputEventType.pointerDown &&
        context.activeTool.startsInkSession &&
        context.activeSession == null &&
        event.workspacePosition != null &&
        event.pointerId != null) {
      final pressure = event.pressure;
      return InteractionIntentResult.intent(
        BeginInkIntent(
          correlationId: event.eventId,
          pointerId: event.pointerId!,
          tool: context.activeTool,
          point: InkPoint(
            workspacePosition: event.workspacePosition!,
            timestamp: Duration.zero,
            pressure: pressure != null && pressure.isFinite
                ? pressure.clamp(0, 1).toDouble()
                : null,
            tiltX: event.tilt?.x,
            tiltY: event.tilt?.y,
            azimuth: event.azimuth,
            isCoalesced: event.metadata['coalesced'] == true,
            isPredicted: event.metadata['predicted'] == true,
          ),
          brush:
              inkBrush?.call(context.activeTool) ??
              _defaultInkBrush(context.activeTool),
          shapeKind: _shapeKind(context.activeTool),
          anchor: inkAnchor?.call(event),
        ),
        priority: InteractionPriority.viewport,
        target: target,
      );
    }
    if (context.activeTool.startsInkSession &&
        (_isActivation(event) ||
            event.type == NormalizedInputEventType.longPressStart ||
            event.type == NormalizedInputEventType.longPressMove ||
            event.type == NormalizedInputEventType.longPressEnd)) {
      return InteractionIntentResult.state(
        InteractionIntentResultKind.consumed,
        reason: 'explicit-ink-tool-owns-activation',
        priority: InteractionPriority.viewport,
        target: target,
      );
    }
    if (event.type == NormalizedInputEventType.longPressStart &&
        target is BlockHandleHitTarget) {
      if (context.activeTool != WorkspaceTool.selection ||
          context.activeSession != null) {
        return InteractionIntentResult.state(
          InteractionIntentResultKind.rejected,
          reason: 'drag-session-or-tool-incompatible',
          priority: InteractionPriority.handle,
          target: target,
        );
      }
      return _allowed(
        target.blockId!,
        BlockCapability.movable,
        BeginDragIntent(target.blockId!),
        InteractionPriority.handle,
        target,
      );
    }
    if (event.type == NormalizedInputEventType.pointerDown &&
        target is ResizeHandleHitTarget &&
        event.globalPosition != null &&
        context.activeSession == null) {
      final bounds = blockBounds?.call(target.blockId!);
      if (bounds == null) {
        return InteractionIntentResult.state(
          InteractionIntentResultKind.rejected,
          reason: 'resize-geometry-missing',
          priority: InteractionPriority.handle,
          target: target,
        );
      }
      return _allowed(
        target.blockId!,
        BlockCapability.resizable,
        BeginResizeIntent(
          blockId: target.blockId!,
          handle: target.handle,
          position: InteractionPoint(
            event.globalPosition!.x,
            event.globalPosition!.y,
          ),
          initialBounds: bounds,
        ),
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
    if (target is EmptyAreaHitTarget &&
        event.type == NormalizedInputEventType.pointerDown &&
        context.activeTool == WorkspaceTool.selection &&
        (canStartMarquee?.call() ?? true) &&
        context.editingBlock == null &&
        context.activeSession == null &&
        event.globalPosition != null) {
      return InteractionIntentResult.intent(
        BeginMarqueeSelectionIntent(
          InteractionPoint(event.globalPosition!.x, event.globalPosition!.y),
        ),
        priority: InteractionPriority.viewport,
        target: target,
      );
    }
    if ((target is BlockHandleHitTarget ||
            target is BlockBackgroundHitTarget ||
            target is BlockContentHitTarget ||
            target is CustomRegionHitTarget) &&
        _isActivation(event) &&
        target.blockId != null) {
      final intent = event.modifiers.commandOrControl
          ? ToggleBlockSelectionIntent(target.blockId!)
          : event.modifiers.shift
          ? SelectRangeIntent(
              target.blockId!,
              visualOrder: visualOrder?.call() ?? [target.blockId!],
            )
          : SelectBlockIntent(target.blockId!);
      return _allowed(
        target.blockId!,
        BlockCapability.selectable,
        intent,
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

  bool _isDelete(NormalizedInputEvent event) =>
      event.type == NormalizedInputEventType.keyDown &&
      (event.key == 'Delete' || event.key == 'Backspace');

  List<String> _selectedBlockIds(InteractionContext context) =>
      switch (context.currentSelection) {
        MultiBlockSelection(:final group) => group.blockIds,
        BlockSelection(:final blockId) => [blockId],
        _ => const [],
      };

  bool _hasSelection(InteractionContext context) =>
      _selectedBlockIds(context).isNotEmpty ||
      switch (context.currentSelection) {
        InkSelection(:final elementIds) => elementIds.isNotEmpty,
        _ => false,
      };

  InkBrushStyle _defaultInkBrush(WorkspaceTool tool) => switch (tool) {
    WorkspaceTool.highlighter => InkBrushStyle.highlighter(),
    WorkspaceTool.line ||
    WorkspaceTool.arrow ||
    WorkspaceTool.rectangle ||
    WorkspaceTool.ellipse => InkBrushStyle.shape(),
    _ => InkBrushStyle.pen(),
  };

  InkShapeKind? _shapeKind(WorkspaceTool tool) => switch (tool) {
    WorkspaceTool.line => InkShapeKind.line,
    WorkspaceTool.arrow => InkShapeKind.arrow,
    WorkspaceTool.rectangle => InkShapeKind.rectangle,
    WorkspaceTool.ellipse => InkShapeKind.ellipse,
    _ => null,
  };
}
