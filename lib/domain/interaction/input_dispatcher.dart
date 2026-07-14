import 'dart:collection';

import 'package:allministrator/domain/interaction/block_geometry_registry.dart';
import 'package:allministrator/domain/interaction/interaction_intent_result.dart';
import 'package:allministrator/domain/interaction/interaction_intents.dart';
import 'package:allministrator/domain/interaction/interaction_models.dart';
import 'package:allministrator/domain/interaction/interaction_resolver.dart';
import 'package:allministrator/domain/interaction/normalized_input_event.dart';
import 'package:allministrator/domain/interaction/workspace_interaction_controller.dart';

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
      _trackPointer(event);
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
          ClearSelectionIntent() ||
          StartEditingIntent() ||
          FinishEditingIntent() ||
          CancelInteractionIntent() ||
          OpenContextMenuIntent() ||
          UpdateTextSelectionIntent() ||
          UpdatePointerIntent() ||
          ClearPointerIntent():
        controller.dispatch(intent);
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
