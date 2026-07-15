import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/app/theme/app_motion.dart';
import 'package:allministrator/features/editor/presentation/interaction/geometry_reporting.dart';
import 'package:allministrator/features/editor/presentation/interaction/platform_input_adapters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const bool _geometryDebugEnabled = bool.fromEnvironment(
  'WORKSPACE_GEOMETRY_DEBUG',
);

typedef WorkspaceModalBuilder =
    Widget Function(BuildContext context, String blockId);

class WorkspaceSurface extends StatelessWidget {
  const WorkspaceSurface({
    required this.workspaceId,
    required this.pageId,
    required this.registry,
    required this.interaction,
    required this.scrollController,
    required this.content,
    this.lockedBlockIds = const {},
    this.transientOverlay,
    this.modalBuilder,
    this.debugGeometry = false,
    this.keyboardInset,
    this.inputDispatcher,
    this.overlayController,
    this.viewportController,
    this.isBlockResizable,
    this.workspaceExtent,
    this.inkLayer,
    super.key,
  });

  final String workspaceId;
  final String pageId;
  final BlockGeometryRegistry registry;
  final WorkspaceInteractionController interaction;
  final ScrollController scrollController;
  final Widget content;
  final Set<String> lockedBlockIds;
  final Widget? transientOverlay;
  final WorkspaceModalBuilder? modalBuilder;
  final bool debugGeometry;
  final double? keyboardInset;
  final InputDispatcher? inputDispatcher;
  final InteractionOverlayController? overlayController;
  final WorkspaceViewportController? viewportController;
  final bool Function(String blockId)? isBlockResizable;
  final Size? workspaceExtent;
  final Widget? inkLayer;

  @override
  Widget build(BuildContext context) {
    final keyboardInset =
        this.keyboardInset ?? MediaQuery.viewInsetsOf(context).bottom;
    final visibleGlobalBottom =
        MediaQuery.sizeOf(context).height - keyboardInset;
    Widget viewportContent(WorkspaceCamera camera) => WorkspaceViewportReporter(
      registry: registry,
      scrollListenable: scrollController,
      readScrollOffset: () =>
          scrollController.hasClients ? scrollController.offset : 0,
      keyboardInset: keyboardInset,
      visibleGlobalBottom: visibleGlobalBottom,
      camera: camera,
      child: LayoutBuilder(
        builder: (_, constraints) => ClipRect(
          child: Transform.translate(
            offset: Offset(camera.translation.x, camera.translation.y),
            child: Transform.scale(
              scale: camera.zoom,
              alignment: Alignment.topLeft,
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 0,
                minHeight: 0,
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: SizedBox(
                  width:
                      workspaceExtent?.width ??
                      constraints.maxWidth / camera.zoom,
                  height:
                      workspaceExtent?.height ??
                      constraints.maxHeight / camera.zoom,
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final transformedContent = viewportController == null
        ? viewportContent(const WorkspaceCamera())
        : AnimatedBuilder(
            animation: viewportController!,
            builder: (_, _) => viewportContent(viewportController!.camera),
          );
    final layers = Stack(
      fit: StackFit.expand,
      children: [
        ContentLayer(child: transformedContent),
        ?inkLayer,
        DecorationLayer(
          registry: registry,
          interaction: interaction,
          lockedBlockIds: lockedBlockIds,
        ),
        OverlayLayer(
          registry: registry,
          interaction: interaction,
          debugGeometry: kDebugMode && (_geometryDebugEnabled || debugGeometry),
          overlayController: overlayController,
        ),
        ModalLayer(
          registry: registry,
          interaction: interaction,
          builder: modalBuilder,
        ),
      ],
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        InteractionLayer(
          registry: registry,
          interaction: interaction,
          workspaceId: workspaceId,
          pageId: pageId,
          scrollController: scrollController,
          inputDispatcher: inputDispatcher,
          viewportController: viewportController,
          isBlockResizable: isBlockResizable,
          isCanvas: workspaceExtent != null,
          child: layers,
        ),
        // Transient toolbars must be the last interactive layer. Keeping them
        // outside InteractionLayer also prevents a toolbar tap from being
        // interpreted as a tap on the document or Canvas underneath it.
        ?transientOverlay,
      ],
    );
  }
}

class ContentLayer extends StatelessWidget {
  const ContentLayer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class DecorationLayer extends StatelessWidget {
  const DecorationLayer({
    required this.registry,
    required this.interaction,
    required this.lockedBlockIds,
    super.key,
  });

  final BlockGeometryRegistry registry;
  final WorkspaceInteractionController interaction;
  final Set<String> lockedBlockIds;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: Listenable.merge([registry, interaction.blockStateRevision]),
      builder: (context, _) => CustomPaint(
        painter: _DecorationPainter(
          entries: registry.entries,
          viewport: registry.viewport,
          selectedBlockId: interaction.context.selectedBlock,
          lockedBlockIds: lockedBlockIds,
          colorScheme: Theme.of(context).colorScheme,
        ),
      ),
    ),
  );
}

class InteractionLayer extends StatelessWidget {
  const InteractionLayer({
    required this.registry,
    required this.interaction,
    required this.workspaceId,
    required this.pageId,
    required this.scrollController,
    this.inputDispatcher,
    this.viewportController,
    this.isBlockResizable,
    this.isCanvas = false,
    required this.child,
    super.key,
  });

  final BlockGeometryRegistry registry;
  final WorkspaceInteractionController interaction;
  final String workspaceId;
  final String pageId;
  final ScrollController scrollController;
  final InputDispatcher? inputDispatcher;
  final WorkspaceViewportController? viewportController;
  final bool Function(String blockId)? isBlockResizable;
  final bool isCanvas;
  final Widget child;
  static const _autoScrollPolicy = DragAutoScrollPolicy();

  @override
  Widget build(BuildContext context) => _ViewportGestureLayer(
    controller: viewportController,
    interaction: interaction,
    child: MouseRegion(
      cursor: _cursorFor(interaction.context.activeTool),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) => _updatePointer(event, isDown: true),
        onPointerMove: (event) => _updatePointer(event, isDown: true),
        onPointerUp: (event) => _updatePointer(event, isDown: false),
        onPointerCancel: (event) =>
            _dispatchPointer(event, NormalizedInputEventType.pointerCancel),
        onPointerHover: (event) =>
            _dispatchPointer(event, NormalizedInputEventType.stylusHover),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            AnimatedBuilder(
              animation: Listenable.merge([
                registry,
                interaction.blockStateRevision,
              ]),
              builder: (context, _) {
                final viewport = registry.viewport;
                if (viewport == null) return const SizedBox.shrink();
                final selectedId = interaction.context.selectedBlock;
                final selected = selectedId == null
                    ? null
                    : registry.geometryFor(selectedId);
                return Stack(
                  children: [
                    for (final entry in registry.visibleBlocks)
                      _handleTarget(context, entry, viewport),
                    if (selected != null &&
                        interaction.context.editingBlock == null &&
                        interaction.context.activeSession is! ResizeSession &&
                        (isBlockResizable?.call(selected.blockId) ?? false))
                      for (final handle in ResizeHandle.values)
                        _resizeHandleTarget(
                          context,
                          selected,
                          viewport,
                          handle,
                        ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );

  MouseCursor _cursorFor(WorkspaceTool tool) => switch (tool) {
    WorkspaceTool.hand => SystemMouseCursors.grab,
    WorkspaceTool.pen ||
    WorkspaceTool.highlighter ||
    WorkspaceTool.eraser ||
    WorkspaceTool.inkLasso ||
    WorkspaceTool.line ||
    WorkspaceTool.arrow ||
    WorkspaceTool.rectangle ||
    WorkspaceTool.ellipse => SystemMouseCursors.precise,
    _ => MouseCursor.defer,
  };

  void _updatePointer(PointerEvent event, {required bool isDown}) {
    final type = switch (event) {
      PointerDownEvent() => NormalizedInputEventType.pointerDown,
      PointerMoveEvent() => NormalizedInputEventType.pointerMove,
      PointerUpEvent() => NormalizedInputEventType.pointerUp,
      _ => NormalizedInputEventType.pointerMove,
    };
    final activeSession = interaction.context.activeSession;
    final wasTransientTransform =
        activeSession is MarqueeSelectionSession ||
        activeSession is ResizeSession ||
        activeSession is InkSession;
    final wasViewportGesture = viewportController?.isGestureActive ?? false;
    _dispatchPointer(event, type, isDown: isDown);
    if (event is PointerUpEvent &&
        !wasTransientTransform &&
        !wasViewportGesture &&
        inputDispatcher != null) {
      final point = SpatialPoint(event.position.dx, event.position.dy);
      final hit = registry.hitTest(point);
      inputDispatcher!.dispatch(
        const PointerInputAdapter().adapt(
          event: event,
          workspaceId: workspaceId,
          pageId: pageId,
          type: NormalizedInputEventType.tap,
          hit: hit,
        ),
      );
    }
  }

  void _dispatchPointer(
    PointerEvent event,
    NormalizedInputEventType type, {
    bool isDown = false,
  }) {
    final point = SpatialPoint(event.position.dx, event.position.dy);
    final hit = registry.hitTest(point);
    final dispatcher = inputDispatcher;
    if (dispatcher != null) {
      dispatcher.dispatch(
        const PointerInputAdapter().adapt(
          event: event,
          workspaceId: workspaceId,
          pageId: pageId,
          type: type,
          hit: hit,
        ),
      );
      _autoScroll(event);
      return;
    }
    interaction.dispatch(
      UpdatePointerIntent(
        InteractionPointer(
          pointerId: event.pointer,
          position: InteractionPoint(point.x, point.y),
          isDown: isDown,
          targetKind: hit.target.kind,
          blockId: hit.target.blockId,
        ),
      ),
    );
  }

  void _autoScroll(PointerEvent event) {
    if (event is! PointerMoveEvent ||
        interaction.context.activeSession is! DragSession ||
        !scrollController.hasClients) {
      return;
    }
    final viewport = registry.viewport;
    if (viewport == null) return;
    final delta = _autoScrollPolicy.deltaFor(
      event.position.dy,
      viewport.visibleBounds,
    );
    if (delta == 0) return;
    final position = scrollController.position;
    scrollController.jumpTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  Widget _handleTarget(
    BuildContext context,
    BlockGeometryEntry entry,
    WorkspaceViewportGeometry viewport,
  ) {
    final globalBounds = WorkspaceOverlayGeometry.handleBounds(entry);
    final localBounds = globalBounds.translate(
      -viewport.globalBounds.left,
      -viewport.globalBounds.top,
    );
    return Positioned(
      left: localBounds.left,
      top: localBounds.top,
      width: localBounds.width,
      height: localBounds.height,
      child: Semantics(
        button: true,
        label: 'Seleccionar bloque',
        child: InteractionRegionReporter(
          registry: registry,
          blockId: entry.blockId,
          regionId: 'block-handle',
          target: BlockHandleHitTarget(entry.blockId),
          priority: 100,
          child: GestureDetector(
            key: ValueKey('block-handle-${entry.blockId}'),
            behavior: HitTestBehavior.translucent,
            onTap: () {
              final dispatcher = inputDispatcher;
              if (dispatcher != null) {
                dispatcher.dispatch(
                  const GestureInputAdapter().tap(
                    workspaceId: workspaceId,
                    pageId: pageId,
                    target: BlockHandleHitTarget(entry.blockId),
                    regionId: 'block-handle',
                  ),
                );
              } else {
                interaction.dispatch(SelectBlockIntent(entry.blockId));
              }
            },
            onLongPressStart: (_) {
              inputDispatcher?.dispatch(
                const GestureInputAdapter().longPressStart(
                  workspaceId: workspaceId,
                  pageId: pageId,
                  target: BlockHandleHitTarget(entry.blockId),
                  regionId: 'block-handle',
                ),
              );
            },
            onPanStart: isCanvas
                ? (_) {
                    inputDispatcher?.dispatch(
                      const GestureInputAdapter().longPressStart(
                        workspaceId: workspaceId,
                        pageId: pageId,
                        target: BlockHandleHitTarget(entry.blockId),
                        regionId: 'block-handle',
                      ),
                    );
                  }
                : null,
          ),
        ),
      ),
    );
  }

  Widget _resizeHandleTarget(
    BuildContext context,
    BlockGeometryEntry entry,
    WorkspaceViewportGeometry viewport,
    ResizeHandle handle,
  ) {
    final globalBounds = WorkspaceOverlayGeometry.resizeHandleBounds(
      entry,
      handle,
    );
    final localBounds = globalBounds.translate(
      -viewport.globalBounds.left,
      -viewport.globalBounds.top,
    );
    return Positioned(
      left: localBounds.left,
      top: localBounds.top,
      width: localBounds.width,
      height: localBounds.height,
      child: Semantics(
        label: 'Redimensionar bloque',
        child: InteractionRegionReporter(
          key: ValueKey('resize-${entry.blockId}-${handle.name}'),
          registry: registry,
          blockId: entry.blockId,
          regionId: 'resize-${handle.name}',
          target: ResizeHandleHitTarget(entry.blockId, handle: handle),
          priority: 200,
          child: MouseRegion(
            cursor: handle == ResizeHandle.east
                ? SystemMouseCursors.resizeLeftRight
                : handle == ResizeHandle.south
                ? SystemMouseCursors.resizeUpDown
                : SystemMouseCursors.resizeDownRight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewportGestureLayer extends StatefulWidget {
  const _ViewportGestureLayer({
    required this.controller,
    required this.interaction,
    required this.child,
  });

  final WorkspaceViewportController? controller;
  final WorkspaceInteractionController interaction;
  final Widget child;

  @override
  State<_ViewportGestureLayer> createState() => _ViewportGestureLayerState();
}

class _ViewportGestureLayerState extends State<_ViewportGestureLayer> {
  final Map<int, Offset> _touches = {};
  Offset? _lastFocal;
  double? _lastDistance;
  int? _mousePanPointer;
  Offset? _lastMousePosition;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _pointerDown,
    onPointerMove: _pointerMove,
    onPointerUp: _pointerUp,
    onPointerCancel: _pointerUp,
    onPointerSignal: _pointerSignal,
    child: widget.child,
  );

  void _pointerDown(PointerDownEvent event) {
    final controller = widget.controller;
    if (controller == null) return;
    if (widget.interaction.context.activeTool == WorkspaceTool.hand) {
      _mousePanPointer = event.pointer;
      _lastMousePosition = event.localPosition;
      controller.beginGesture();
      return;
    }
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons == kMiddleMouseButton) {
      _mousePanPointer = event.pointer;
      _lastMousePosition = event.localPosition;
      controller.beginGesture();
      widget.interaction.dispatch(
        const CancelInteractionIntent(keepBlockSelected: true),
      );
      return;
    }
    if (event.kind != PointerDeviceKind.touch) return;
    _touches[event.pointer] = event.localPosition;
    if (_touches.length == 2) {
      controller.beginGesture();
      final points = _touches.values.toList();
      _lastFocal = Offset(
        (points[0].dx + points[1].dx) / 2,
        (points[0].dy + points[1].dy) / 2,
      );
      _lastDistance = (points[0] - points[1]).distance;
      widget.interaction.dispatch(
        const CancelInteractionIntent(keepBlockSelected: true),
      );
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    final controller = widget.controller;
    if (controller == null) return;
    if (_mousePanPointer == event.pointer && _lastMousePosition != null) {
      final delta = event.localPosition - _lastMousePosition!;
      controller.panBy(SpatialPoint(delta.dx, delta.dy));
      _lastMousePosition = event.localPosition;
      return;
    }
    if (!_touches.containsKey(event.pointer)) return;
    _touches[event.pointer] = event.localPosition;
    if (_touches.length != 2 || _lastFocal == null || _lastDistance == null) {
      return;
    }
    final points = _touches.values.toList();
    final focal = Offset(
      (points[0].dx + points[1].dx) / 2,
      (points[0].dy + points[1].dy) / 2,
    );
    final distance = (points[0] - points[1]).distance;
    final pan = focal - _lastFocal!;
    controller.panBy(SpatialPoint(pan.dx, pan.dy));
    if (_lastDistance! > 0) {
      controller.zoomBy(
        distance / _lastDistance!,
        focalPoint: SpatialPoint(focal.dx, focal.dy),
      );
    }
    _lastFocal = focal;
    _lastDistance = distance;
  }

  void _pointerUp(PointerEvent event) {
    _touches.remove(event.pointer);
    if (_touches.length < 2) {
      _lastFocal = null;
      _lastDistance = null;
    }
    if (_touches.isEmpty && _mousePanPointer == null) {
      widget.controller?.endGesture();
    }
    if (_mousePanPointer == event.pointer) {
      _mousePanPointer = null;
      _lastMousePosition = null;
      if (_touches.isEmpty) widget.controller?.endGesture();
    }
  }

  void _pointerSignal(PointerSignalEvent event) {
    final controller = widget.controller;
    if (controller == null || event is! PointerScrollEvent) return;
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final modified =
        keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
    if (!modified) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      final factor = event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1;
      controller.zoomBy(
        factor,
        focalPoint: SpatialPoint(
          event.localPosition.dx,
          event.localPosition.dy,
        ),
      );
    });
  }
}

class OverlayLayer extends StatelessWidget {
  const OverlayLayer({
    required this.registry,
    required this.interaction,
    required this.debugGeometry,
    this.overlayController,
    super.key,
  });

  final BlockGeometryRegistry registry;
  final WorkspaceInteractionController interaction;
  final bool debugGeometry;
  final InteractionOverlayController? overlayController;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      registry,
      interaction.blockStateRevision,
      ?overlayController,
    ]),
    builder: (context, _) {
      final visual = overlayController?.state;
      return Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(interaction.context.selectedBlock),
              tween: Tween(begin: 0, end: 1),
              duration: AppMotion.fast,
              curve: Curves.easeOut,
              builder: (context, progress, _) => CustomPaint(
                painter: _OverlayPainter(
                  entries: registry.entries,
                  viewport: registry.viewport,
                  selectedBlockId: visual?.showSelectionBorder == false
                      ? null
                      : visual?.selectedBlockId ??
                            interaction.context.selectedBlock,
                  colorScheme: Theme.of(context).colorScheme,
                  debugGeometry: debugGeometry,
                  selectionProgress: progress,
                  visualState: visual,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class ModalLayer extends StatelessWidget {
  const ModalLayer({
    required this.registry,
    required this.interaction,
    this.builder,
    super.key,
  });

  final BlockGeometryRegistry registry;
  final WorkspaceInteractionController interaction;
  final WorkspaceModalBuilder? builder;

  @override
  Widget build(BuildContext context) {
    if (builder == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: Listenable.merge([registry, interaction.blockStateRevision]),
      builder: (context, _) {
        if (interaction.context.activeSession is ResizeSession ||
            interaction.context.editingBlock != null) {
          return const SizedBox.shrink();
        }
        final blockId = interaction.context.selectedBlock;
        final viewport = registry.viewport;
        final entry = blockId == null ? null : registry.geometryFor(blockId);
        if (entry == null || viewport == null || !entry.isVisible) {
          return const SizedBox.shrink();
        }
        final anchor = WorkspaceOverlayGeometry.toolbarAnchor(entry);
        final local = anchor - viewport.globalBounds.topLeft;
        final placeAbove = local.y > 72;
        final desiredTop = placeAbove
            ? local.y - WorkspaceOverlayMetrics.toolbarGap
            : local.y +
                  entry.globalBounds.height +
                  WorkspaceOverlayMetrics.toolbarGap;
        final visibleBottom =
            viewport.visibleBounds.bottom - viewport.globalBounds.top;
        final maxTop =
            (visibleBottom - WorkspaceOverlayMetrics.toolbarEstimatedHeight)
                .clamp(
                  WorkspaceOverlayMetrics.surfaceEdgeInset,
                  double.infinity,
                );
        final top = desiredTop.clamp(
          WorkspaceOverlayMetrics.surfaceEdgeInset,
          maxTop,
        );
        return Stack(
          children: [
            Positioned(
              left: WorkspaceOverlayMetrics.surfaceEdgeInset,
              right: WorkspaceOverlayMetrics.surfaceEdgeInset,
              top: top,
              child: FractionalTranslation(
                translation: Offset(0, placeAbove ? -1 : 0),
                child: Align(
                  alignment: Alignment.center,
                  child: builder!(context, blockId!),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class WorkspaceOverlayMetrics {
  const WorkspaceOverlayMetrics._();

  static const double borderRadius = 10;
  static const double handleSize = 36;
  static const double handleGap = 4;
  static const double toolbarGap = 8;
  static const double toolbarEstimatedHeight = 48;
  static const double surfaceEdgeInset = 8;
  static const double resizeHandleSize = 16;
}

class WorkspaceOverlayGeometry {
  const WorkspaceOverlayGeometry._();

  static SpatialRect handleBounds(BlockGeometryEntry entry) =>
      SpatialRect.fromLTWH(
        entry.handleAnchor.x -
            WorkspaceOverlayMetrics.handleSize -
            WorkspaceOverlayMetrics.handleGap,
        entry.handleAnchor.y,
        WorkspaceOverlayMetrics.handleSize,
        WorkspaceOverlayMetrics.handleSize,
      );

  static SpatialPoint toolbarAnchor(BlockGeometryEntry entry) =>
      entry.toolbarAnchor;

  static SpatialRect resizeHandleBounds(
    BlockGeometryEntry entry,
    ResizeHandle handle,
  ) {
    final bounds = transformBounds(entry);
    final half = WorkspaceOverlayMetrics.resizeHandleSize / 2;
    final point = switch (handle) {
      ResizeHandle.east => SpatialPoint(bounds.right, bounds.center.y),
      ResizeHandle.south => SpatialPoint(bounds.center.x, bounds.bottom),
      ResizeHandle.southEast => SpatialPoint(bounds.right, bounds.bottom),
    };
    return SpatialRect.fromLTWH(
      point.x - half,
      point.y - half,
      WorkspaceOverlayMetrics.resizeHandleSize,
      WorkspaceOverlayMetrics.resizeHandleSize,
    );
  }

  static SpatialRect transformBounds(BlockGeometryEntry entry) =>
      entry.regions['image']?.globalBounds ?? entry.globalBounds;
}

class _DecorationPainter extends CustomPainter {
  const _DecorationPainter({
    required this.entries,
    required this.viewport,
    required this.selectedBlockId,
    required this.lockedBlockIds,
    required this.colorScheme,
  });

  final List<BlockGeometryEntry> entries;
  final WorkspaceViewportGeometry? viewport;
  final String? selectedBlockId;
  final Set<String> lockedBlockIds;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = this.viewport;
    if (viewport == null) return;
    final origin = viewport.globalBounds.topLeft;
    for (final entry in entries) {
      if (!entry.isVisible) continue;
      final rect = _toRect(entry.globalBounds, origin);
      if (entry.blockId == selectedBlockId) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect,
            const Radius.circular(WorkspaceOverlayMetrics.borderRadius),
          ),
          Paint()..color = colorScheme.primaryContainer.withValues(alpha: 0.14),
        );
      }
      if (lockedBlockIds.contains(entry.blockId)) {
        canvas.drawCircle(
          Offset(rect.right - 8, rect.top + 8),
          4,
          Paint()..color = colorScheme.tertiary,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DecorationPainter oldDelegate) => true;
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({
    required this.entries,
    required this.viewport,
    required this.selectedBlockId,
    required this.colorScheme,
    required this.debugGeometry,
    required this.selectionProgress,
    this.visualState,
  });

  final List<BlockGeometryEntry> entries;
  final WorkspaceViewportGeometry? viewport;
  final String? selectedBlockId;
  final ColorScheme colorScheme;
  final bool debugGeometry;
  final double selectionProgress;
  final WorkspaceOverlayVisualState? visualState;

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = this.viewport;
    if (viewport == null) return;
    final origin = viewport.globalBounds.topLeft;
    for (final entry in entries) {
      if (!entry.isVisible) continue;
      final rect = _toRect(entry.globalBounds, origin);
      if (entry.blockId == selectedBlockId) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect,
            const Radius.circular(WorkspaceOverlayMetrics.borderRadius),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = colorScheme.primary.withValues(alpha: selectionProgress),
        );
        final handle = _toRect(
          WorkspaceOverlayGeometry.handleBounds(entry),
          origin,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(handle, const Radius.circular(8)),
          Paint()
            ..color = colorScheme.surfaceContainerHighest.withValues(
              alpha: selectionProgress,
            ),
        );
        final linePaint = Paint()
          ..color = colorScheme.primary.withValues(alpha: selectionProgress)
          ..strokeWidth = 1.5;
        for (final dx in [-3.0, 3.0]) {
          canvas.drawLine(
            Offset(handle.center.dx + dx, handle.center.dy - 6),
            Offset(handle.center.dx + dx, handle.center.dy + 6),
            linePaint,
          );
        }
      }
      if (debugGeometry) _paintDebug(canvas, entry, origin);
    }
    final visual = visualState;
    if (visual?.dragGhostBounds case final ghost?) {
      final rect = _toRect(ghost, origin);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        Paint()..color = colorScheme.primaryContainer.withValues(alpha: 0.55),
      );
    }
    if (visual?.placeholderY case final y?) {
      final localY = y - origin.y;
      canvas.drawLine(
        Offset(WorkspaceOverlayMetrics.surfaceEdgeInset, localY),
        Offset(size.width - WorkspaceOverlayMetrics.surfaceEdgeInset, localY),
        Paint()
          ..color = colorScheme.primary
          ..strokeWidth = 3,
      );
    }
    if (visual?.combinedSelectionBounds case final bounds?) {
      final rect = _toRect(bounds, origin);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = colorScheme.primary.withValues(alpha: 0.8),
      );
    }
    if (visual?.marqueeBounds case final marquee?) {
      final rect = _toRect(marquee, origin);
      canvas.drawRect(
        rect,
        Paint()..color = colorScheme.primary.withValues(alpha: 0.12),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = colorScheme.primary,
      );
    }
    if (visual?.resizePreviewBounds case final preview?) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          _toRect(preview, origin),
          const Radius.circular(WorkspaceOverlayMetrics.borderRadius),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colorScheme.primary,
      );
    }
    for (final guide in visual?.smartGuides ?? const <SmartGuide>[]) {
      final paint = Paint()
        ..color = colorScheme.tertiary
        ..strokeWidth = 1;
      if (guide.axis == SmartGuideAxis.vertical) {
        final x = guide.position - origin.x;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      } else {
        final y = guide.position - origin.y;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  void _paintDebug(
    Canvas canvas,
    BlockGeometryEntry entry,
    SpatialPoint origin,
  ) {
    canvas.drawRect(
      _toRect(entry.globalBounds, origin),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.cyan,
    );
    canvas.drawRect(
      _toRect(entry.visibleBounds, origin),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.greenAccent,
    );
    for (final region in entry.regions.values) {
      canvas.drawRect(
        _toRect(region.globalBounds, origin),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.orangeAccent,
      );
    }
    final anchor = WorkspaceOverlayGeometry.toolbarAnchor(entry) - origin;
    canvas.drawCircle(
      Offset(anchor.x, anchor.y),
      4,
      Paint()..color = Colors.purpleAccent,
    );
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) => true;
}

Rect _toRect(SpatialRect rect, SpatialPoint origin) => Rect.fromLTRB(
  rect.left - origin.x,
  rect.top - origin.y,
  rect.right - origin.x,
  rect.bottom - origin.y,
);
