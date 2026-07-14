import 'dart:collection';

import 'package:allministrator/domain/interaction/block_geometry_registry.dart';
import 'package:allministrator/domain/interaction/drag_session.dart';
import 'package:allministrator/domain/interaction/drop_resolver.dart';
import 'package:allministrator/domain/interaction/marquee_selection_session.dart';
import 'package:allministrator/domain/interaction/selection_group.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';
import 'package:allministrator/domain/interaction/interaction_intent_result.dart';
import 'package:allministrator/domain/interaction/interaction_intents.dart';
import 'package:allministrator/domain/interaction/interaction_models.dart';
import 'package:allministrator/domain/interaction/interaction_resolver.dart';
import 'package:allministrator/domain/interaction/normalized_input_event.dart';
import 'package:allministrator/domain/interaction/workspace_interaction_controller.dart';
import 'package:allministrator/domain/interaction/geometry_resolver.dart';
import 'package:allministrator/domain/interaction/transformation_engine.dart';

typedef InteractionCommandSink =
    void Function(InteractionIntent intent, NormalizedInputEvent event);
typedef InputDispatchObserver = void Function(InputDispatchResult result);

class InputDispatcher {
  InputDispatcher({
    required this.workspaceId,
    required this.pageId,
    required this.registry,
    required this.controller,
    required this.resolver,
    this.onCommand,
    this.onResult,
    this.isModalActive,
    this.dropResolver,
    this.snapResolver = const SnapResolver(),
    this.maxRememberedEvents = 100,
  });

  final String workspaceId;
  final String pageId;
  final BlockGeometryRegistry registry;
  final WorkspaceInteractionController controller;
  final InteractionResolver resolver;
  final InteractionCommandSink? onCommand;
  final InputDispatchObserver? onResult;
  final bool Function()? isModalActive;
  final DropResolver? dropResolver;
  final SnapResolver snapResolver;
  final int maxRememberedEvents;
  final Queue<String> _eventIds = Queue();
  final Set<String> _seenIds = {};
  final Map<int, DateTime> _activePointers = {};
  bool _dispatching = false;
  bool _disposed = false;

  InputDispatchResult dispatch(NormalizedInputEvent input) {
    final result = _validate(input);
    if (result != null) return _publish(input, result);
    if (_dispatching) {
      return _publish(
        input,
        const InteractionIntentResult.state(
          InteractionIntentResultKind.ignored,
          reason: 'reentrant',
        ),
      );
    }
    _dispatching = true;
    try {
      final event = _withResolvedHit(input);
      final activeSession = controller.context.activeSession;
      _trackPointer(event);
      if (activeSession is ResizeSession &&
          event.globalPosition != null &&
          event.type == NormalizedInputEventType.pointerMove) {
        final resolution = snapResolver.resolveResize(
          session: activeSession,
          position: event.globalPosition!,
          candidates: registry.visibleBlocks
              .where((entry) => entry.blockId != activeSession.blockId)
              .map((entry) => entry.globalBounds),
        );
        controller.dispatch(
          UpdateResizeIntent(
            position: InteractionPoint(
              event.globalPosition!.x,
              event.globalPosition!.y,
            ),
            previewBounds: resolution.bounds,
            guides: resolution.guides,
          ),
        );
        return _publish(
          event,
          const InteractionIntentResult.state(
            InteractionIntentResultKind.consumed,
            reason: 'resize-update',
          ),
        );
      }
      if (activeSession is ResizeSession &&
          event.type == NormalizedInputEventType.pointerUp) {
        final workspaceBounds = GeometryResolver(registry).resolveRect(
          activeSession.previewBounds,
          from: GeometryCoordinateSpace.screen,
          to: GeometryCoordinateSpace.workspace,
        );
        final intent = CommitResizeIntent(
          blockId: activeSession.blockId!,
          bounds: workspaceBounds,
        );
        controller.dispatch(intent);
        onCommand?.call(intent, event);
        return _publish(event, InteractionIntentResult.intent(intent));
      }
      if (activeSession is ResizeSession &&
          event.type == NormalizedInputEventType.pointerCancel) {
        controller.dispatch(const CancelResizeIntent());
        return _publish(
          event,
          const InteractionIntentResult.state(
            InteractionIntentResultKind.cancelled,
            reason: 'resize-cancel',
          ),
        );
      }
      if (activeSession is DragSession &&
          event.globalPosition != null &&
          event.type == NormalizedInputEventType.pointerMove) {
        final target = dropResolver?.resolve(
          sourceBlockId: activeSession.blockId!,
          sourceBlockIds: activeSession.blockIds,
          position: event.globalPosition!,
        );
        controller.dispatch(
          UpdateDragIntent(
            position: InteractionPoint(
              event.globalPosition!.x,
              event.globalPosition!.y,
            ),
            dropTarget: target,
          ),
        );
      }
      if (activeSession is MarqueeSelectionSession &&
          event.globalPosition != null &&
          event.type == NormalizedInputEventType.pointerMove) {
        final position = SpatialPoint(
          event.globalPosition!.x,
          event.globalPosition!.y,
        );
        final candidates = SelectionBoundsResolver(registry).intersecting(
          activeSession.copyWith(currentPosition: position).bounds,
        );
        controller.dispatch(
          UpdateMarqueeSelectionIntent(
            position: InteractionPoint(position.x, position.y),
            candidateIds: candidates,
          ),
        );
        return _publish(
          event,
          const InteractionIntentResult.state(
            InteractionIntentResultKind.consumed,
            reason: 'marquee-update',
          ),
        );
      }
      if (activeSession is MarqueeSelectionSession &&
          event.type == NormalizedInputEventType.pointerUp) {
        controller.dispatch(const CommitMarqueeSelectionIntent());
        return _publish(
          event,
          const InteractionIntentResult.state(
            InteractionIntentResultKind.consumed,
            reason: 'marquee-commit',
          ),
        );
      }
      if (activeSession is MarqueeSelectionSession &&
          event.type == NormalizedInputEventType.pointerCancel) {
        controller.dispatch(const CancelMarqueeSelectionIntent());
        return _publish(
          event,
          const InteractionIntentResult.state(
            InteractionIntentResultKind.cancelled,
            reason: 'marquee-cancel',
          ),
        );
      }
      if (activeSession is DragSession &&
          event.globalPosition != null &&
          event.type == NormalizedInputEventType.pointerUp) {
        final target = dropResolver?.resolve(
          sourceBlockId: activeSession.blockId!,
          sourceBlockIds: activeSession.blockIds,
          position: event.globalPosition!,
        );
        if (target == null || !target.isValid) {
          controller.dispatch(
            const CancelInteractionIntent(
              reason: InteractionCancellationReason.explicit,
              keepBlockSelected: true,
            ),
          );
          return _publish(
            event,
            InteractionIntentResult.state(
              InteractionIntentResultKind.cancelled,
              reason: target?.reason ?? 'invalid-drop',
            ),
          );
        }
        final intent = CommitDragIntent(target);
        controller.dispatch(intent);
        onCommand?.call(intent, event);
        return _publish(event, InteractionIntentResult.intent(intent));
      }
      final resolution = resolver.resolve(
        event: event,
        context: controller.context,
        modalActive: isModalActive?.call() ?? false,
      );
      if (resolution.intent != null) _execute(resolution.intent!, event);
      return _publish(event, resolution);
    } finally {
      _dispatching = false;
    }
  }

  void cancelPointer(int pointerId) {
    if (_disposed || !_activePointers.containsKey(pointerId)) return;
    _activePointers.remove(pointerId);
    controller.dispatch(const ClearPointerIntent());
  }

  void cancelActiveInput() {
    if (_disposed) return;
    _activePointers.clear();
    controller.dispatch(const ClearPointerIntent());
  }

  InteractionIntentResult? _validate(NormalizedInputEvent event) {
    if (_disposed) {
      return const InteractionIntentResult.state(
        InteractionIntentResultKind.ignored,
        reason: 'dispatcher-disposed',
      );
    }
    if (event.workspaceId != workspaceId || event.pageId != pageId) {
      return const InteractionIntentResult.state(
        InteractionIntentResultKind.rejected,
        reason: 'workspace-or-page-mismatch',
      );
    }
    if (_seenIds.contains(event.eventId)) {
      return const InteractionIntentResult.state(
        InteractionIntentResultKind.ignored,
        reason: 'duplicate-event',
      );
    }
    _remember(event.eventId);
    final pointerId = event.pointerId;
    if (event.type == NormalizedInputEventType.pointerMove &&
        (pointerId == null || !_activePointers.containsKey(pointerId))) {
      return const InteractionIntentResult.state(
        InteractionIntentResultKind.ignored,
        reason: 'move-without-active-pointer',
      );
    }
    if (event.type == NormalizedInputEventType.pointerUp &&
        (pointerId == null || !_activePointers.containsKey(pointerId))) {
      return const InteractionIntentResult.state(
        InteractionIntentResultKind.ignored,
        reason: 'up-without-active-pointer',
      );
    }
    return null;
  }

  NormalizedInputEvent _withResolvedHit(NormalizedInputEvent event) {
    if (event.hitTarget != null || event.globalPosition == null) return event;
    return event.withHit(registry.hitTest(event.globalPosition!));
  }

  void _trackPointer(NormalizedInputEvent event) {
    final id = event.pointerId;
    if (id == null) return;
    if (event.type == NormalizedInputEventType.pointerDown) {
      _activePointers[id] = event.timestamp;
    } else if (event.type == NormalizedInputEventType.pointerUp ||
        event.type == NormalizedInputEventType.pointerCancel) {
      _activePointers.remove(id);
    }
    if (event.globalPosition != null) {
      controller.dispatch(
        UpdatePointerIntent(
          InteractionPointer(
            pointerId: id,
            position: InteractionPoint(
              event.globalPosition!.x,
              event.globalPosition!.y,
            ),
            isDown: _activePointers.containsKey(id),
            targetKind:
                event.hitTarget?.kind ??
                registry.hitTest(event.globalPosition!).target.kind,
            blockId: event.targetBlockId ?? event.hitTarget?.blockId,
          ),
        ),
      );
    }
  }

  void _execute(InteractionIntent intent, NormalizedInputEvent event) {
    switch (intent) {
      case SelectBlockIntent() ||
          AddBlockToSelectionIntent() ||
          RemoveBlockFromSelectionIntent() ||
          ToggleBlockSelectionIntent() ||
          SelectRangeIntent() ||
          BeginMarqueeSelectionIntent() ||
          UpdateMarqueeSelectionIntent() ||
          CommitMarqueeSelectionIntent() ||
          CancelMarqueeSelectionIntent() ||
          ClearSelectionIntent() ||
          StartEditingIntent() ||
          FinishEditingIntent() ||
          CancelInteractionIntent() ||
          OpenContextMenuIntent() ||
          UpdateTextSelectionIntent() ||
          UpdatePointerIntent() ||
          ClearPointerIntent():
        controller.dispatch(intent);
      case BeginDragIntent() || UpdateDragIntent():
        controller.dispatch(intent);
      case CommitDragIntent():
        controller.dispatch(intent);
        onCommand?.call(intent, event);
      case DeleteSelectionIntent():
        onCommand?.call(intent, event);
      case BeginResizeIntent() || UpdateResizeIntent() || CancelResizeIntent():
        controller.dispatch(intent);
      case CommitResizeIntent():
        controller.dispatch(intent);
        onCommand?.call(intent, event);
      case AlignSelectionIntent() || DistributeSelectionIntent():
        onCommand?.call(intent, event);
      default:
        onCommand?.call(intent, event);
    }
  }

  void _remember(String id) {
    _seenIds.add(id);
    _eventIds.addLast(id);
    while (_eventIds.length > maxRememberedEvents) {
      _seenIds.remove(_eventIds.removeFirst());
    }
  }

  InputDispatchResult _publish(
    NormalizedInputEvent event,
    InteractionIntentResult resolution,
  ) {
    final result = InputDispatchResult(
      event: event,
      resolution: resolution,
      correlationId: event.eventId,
    );
    onResult?.call(result);
    return result;
  }

  void dispose() {
    _disposed = true;
    _eventIds.clear();
    _seenIds.clear();
    _activePointers.clear();
  }
}
