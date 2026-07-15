import 'dart:collection';
import 'dart:math' as math;

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
import 'package:allministrator/domain/interaction/viewport_engine.dart';
import 'package:allministrator/domain/ink/ink_models.dart';
import 'package:allministrator/domain/ink/ink_session.dart';

typedef InteractionCommandSink =
    void Function(InteractionIntent intent, NormalizedInputEvent event);
typedef InputDispatchObserver = void Function(InputDispatchResult result);
typedef InkHitTestResolver =
    List<String> Function(SpatialPoint position, double workspaceRadius);
typedef InkLassoResolver = List<String> Function(List<SpatialPoint> polygon);
typedef WorkspaceInputBlocker = bool Function(SpatialPoint globalPosition);

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
    this.isCanvasMode,
    this.camera,
    this.snapResolver = const SnapResolver(),
    this.inkHitTest,
    this.inkLasso,
    this.inputBlocker,
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
  final bool Function()? isCanvasMode;
  final WorkspaceCamera Function()? camera;
  final SnapResolver snapResolver;
  final InkHitTestResolver? inkHitTest;
  final InkLassoResolver? inkLasso;
  final WorkspaceInputBlocker? inputBlocker;
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
      final event = _withWorkspacePosition(_withResolvedHit(input));
      final activeSession = controller.context.activeSession;
      if (activeSession == null &&
          event.globalPosition != null &&
          _canBeginFrom(event.type) &&
          (inputBlocker?.call(event.globalPosition!) ?? false)) {
        return _publish(
          event,
          const InteractionIntentResult.state(
            InteractionIntentResultKind.consumed,
            reason: 'overlay-control-captured-input',
            priority: InteractionPriority.modal,
          ),
        );
      }
      if (activeSession is InkSession &&
          event.type == NormalizedInputEventType.pointerDown &&
          event.pointerId != activeSession.pointerId) {
        return _publish(
          event,
          const InteractionIntentResult.state(
            InteractionIntentResultKind.rejected,
            reason: 'second-pointer-during-ink',
          ),
        );
      }
      _trackPointer(event);
      if (activeSession is InkSession &&
          event.pointerId == activeSession.pointerId &&
          event.type == NormalizedInputEventType.pointerMove &&
          event.workspacePosition != null) {
        final point = _inkPoint(event, activeSession);
        final affected = _affectedInkElements(activeSession, point);
        controller.dispatch(
          UpdateInkIntent(point: point, affectedElementIds: affected),
        );
        return _publish(
          event,
          const InteractionIntentResult.state(
            InteractionIntentResultKind.consumed,
            reason: 'ink-update',
          ),
        );
      }
      if (activeSession is InkSession &&
          event.pointerId == activeSession.pointerId &&
          event.type == NormalizedInputEventType.pointerUp) {
        if (event.workspacePosition != null) {
          final point = _inkPoint(event, activeSession);
          controller.dispatch(
            UpdateInkIntent(
              point: point,
              affectedElementIds: _affectedInkElements(activeSession, point),
            ),
          );
        }
        var committed = controller.context.activeSession is InkSession
            ? controller.context.activeSession! as InkSession
            : activeSession;
        if (committed.tool == WorkspaceTool.inkLasso) {
          committed = committed.copyWith(
            affectedElementIds:
                inkLasso?.call(
                  committed.points
                      .map((point) => point.workspacePosition)
                      .toList(growable: false),
                ) ??
                const [],
          );
        }
        final intent = CommitInkIntent(committed);
        controller.dispatch(intent);
        onCommand?.call(intent, event);
        return _publish(event, InteractionIntentResult.intent(intent));
      }
      if (activeSession is InkSession &&
          event.pointerId == activeSession.pointerId &&
          event.type == NormalizedInputEventType.pointerCancel) {
        controller.dispatch(const CancelInkIntent());
        return _publish(
          event,
          const InteractionIntentResult.state(
            InteractionIntentResultKind.cancelled,
            reason: 'ink-cancel',
          ),
        );
      }
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
        final target = (isCanvasMode?.call() ?? false)
            ? null
            : dropResolver?.resolve(
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
        if (isCanvasMode?.call() ?? false) {
          final zoom = camera?.call().zoom ?? 1;
          final delta = activeSession.delta;
          final intent = CommitCanvasDragIntent(
            blockIds: activeSession.blockIds,
            delta: SpatialPoint(delta.x / zoom, delta.y / zoom),
          );
          controller.dispatch(intent);
          onCommand?.call(intent, event);
          return _publish(event, InteractionIntentResult.intent(intent));
        }
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

  NormalizedInputEvent _withWorkspacePosition(NormalizedInputEvent event) {
    if (event.workspacePosition != null || event.globalPosition == null) {
      return event;
    }
    final workspacePosition = GeometryResolver(registry).resolvePoint(
      event.globalPosition!,
      from: GeometryCoordinateSpace.screen,
      to: GeometryCoordinateSpace.workspace,
    );
    return event.withWorkspacePosition(workspacePosition);
  }

  InkPoint _inkPoint(NormalizedInputEvent event, InkSession session) {
    final elapsed = event.timestamp.difference(session.startedAt);
    final pressure = event.pressure;
    final position = event.modifiers.shift && session.tool.isInkShape
        ? _constrainShapePoint(
            session.tool,
            session.firstPoint.workspacePosition,
            event.workspacePosition!,
          )
        : event.workspacePosition!;
    return InkPoint(
      workspacePosition: position,
      timestamp: elapsed.isNegative ? Duration.zero : elapsed,
      pressure: pressure != null && pressure.isFinite
          ? pressure.clamp(0, 1).toDouble()
          : null,
      tiltX: event.tilt?.x,
      tiltY: event.tilt?.y,
      azimuth: event.azimuth,
      isCoalesced: event.metadata['coalesced'] == true,
      isPredicted: event.metadata['predicted'] == true,
    );
  }

  SpatialPoint _constrainShapePoint(
    WorkspaceTool tool,
    SpatialPoint start,
    SpatialPoint current,
  ) {
    final dx = current.x - start.x;
    final dy = current.y - start.y;
    if (tool == WorkspaceTool.rectangle || tool == WorkspaceTool.ellipse) {
      final edge = math.max(dx.abs(), dy.abs());
      return SpatialPoint(
        start.x + (dx < 0 ? -edge : edge),
        start.y + (dy < 0 ? -edge : edge),
      );
    }
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance == 0) return current;
    final angle = math.atan2(dy, dx);
    final snapped = (angle / (math.pi / 4)).round() * (math.pi / 4);
    return SpatialPoint(
      start.x + math.cos(snapped) * distance,
      start.y + math.sin(snapped) * distance,
    );
  }

  List<String> _affectedInkElements(InkSession session, InkPoint point) {
    if (session.tool != WorkspaceTool.eraser) {
      return session.affectedElementIds;
    }
    final radius = 18 / (camera?.call().zoom ?? 1);
    return {
      ...session.affectedElementIds,
      ...?inkHitTest?.call(point.workspacePosition, radius),
    }.toList(growable: false);
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
          SelectInkElementsIntent() ||
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
      case BeginInkIntent() || UpdateInkIntent() || CancelInkIntent():
        controller.dispatch(intent);
      case CommitInkIntent():
        controller.dispatch(intent);
        onCommand?.call(intent, event);
      case CommitDragIntent() || CommitCanvasDragIntent():
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

  bool _canBeginFrom(NormalizedInputEventType type) => switch (type) {
    NormalizedInputEventType.pointerDown ||
    NormalizedInputEventType.tap ||
    NormalizedInputEventType.doubleTap ||
    NormalizedInputEventType.longPressStart => true,
    _ => false,
  };

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
