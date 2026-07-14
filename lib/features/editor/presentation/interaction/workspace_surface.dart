import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/features/editor/presentation/interaction/geometry_reporting.dart';
import 'package:allministrator/features/editor/presentation/interaction/platform_input_adapters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final keyboardInset =
        this.keyboardInset ?? MediaQuery.viewInsetsOf(context).bottom;
    final visibleGlobalBottom =
        MediaQuery.sizeOf(context).height - keyboardInset;
    final layers = Stack(
      fit: StackFit.expand,
      children: [
        ContentLayer(
          child: WorkspaceViewportReporter(
            registry: registry,
            scrollListenable: scrollController,
            readScrollOffset: () =>
                scrollController.hasClients ? scrollController.offset : 0,
            keyboardInset: keyboardInset,
            visibleGlobalBottom: visibleGlobalBottom,
            child: content,
          ),
        ),
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
          transientOverlay: transientOverlay,
        ),
        ModalLayer(
          registry: registry,
          interaction: interaction,
          builder: modalBuilder,
        ),
      ],
    );
    return InteractionLayer(
      registry: registry,
      interaction: interaction,
      workspaceId: workspaceId,
      pageId: pageId,
      scrollController: scrollController,
      inputDispatcher: inputDispatcher,
      child: layers,
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
    required this.child,
    super.key,
  });

  final BlockGeometryRegistry registry;
  final WorkspaceInteractionController interaction;
  final String workspaceId;
  final String pageId;
  final ScrollController scrollController;
  final InputDispatcher? inputDispatcher;
  final Widget child;
  static const _autoScrollPolicy = DragAutoScrollPolicy();

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) => _updatePointer(event, isDown: true),
    onPointerMove: (event) => _updatePointer(event, isDown: true),
    onPointerUp: (event) => _updatePointer(event, isDown: false),
    onPointerCancel: (event) =>
        _dispatchPointer(event, NormalizedInputEventType.pointerCancel),
    child: Stack(
      fit: StackFit.expand,
      children: [
        child,
        AnimatedBuilder(
          animation: registry,
          builder: (context, _) {
            final viewport = registry.viewport;
            if (viewport == null) return const SizedBox.shrink();
            return Stack(
              children: [
                for (final entry in registry.visibleBlocks)
                  _handleTarget(context, entry, viewport),
              ],
            );
          },
        ),
      ],
    ),
  );

  void _updatePointer(PointerEvent event, {required bool isDown}) {
    final type = switch (event) {
      PointerDownEvent() => NormalizedInputEventType.pointerDown,
      PointerMoveEvent() => NormalizedInputEventType.pointerMove,
      PointerUpEvent() => NormalizedInputEventType.pointerUp,
      _ => NormalizedInputEventType.pointerMove,
    };
    final wasMarquee = interaction.context.activeSession is MarqueeSelectionSession;
    _dispatchPointer(event, type, isDown: isDown);
    if (event is PointerUpEvent && !wasMarquee && inputDispatcher != null) {
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
          ),
        ),
      ),
    );
  }
}

class OverlayLayer extends StatelessWidget {
  const OverlayLayer({
    required this.registry,
    required this.interaction,
    required this.debugGeometry,
    this.overlayController,
    this.transientOverlay,
    super.key,
  });

  final BlockGeometryRegistry registry;
  final WorkspaceInteractionController interaction;
  final bool debugGeometry;
  final InteractionOverlayController? overlayController;
  final Widget? transientOverlay;

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
              duration: const Duration(milliseconds: 140),
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
          ?transientOverlay,
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
