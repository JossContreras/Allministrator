import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/app/theme/app_radius.dart';
import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/editing/workspace_editor_session.dart';
import 'package:allministrator/domain/entities/canvas_layout.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_registry.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_render_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CanvasBlockView extends StatelessWidget {
  const CanvasBlockView({
    required this.session,
    required this.registry,
    required this.interaction,
    required this.geometryRegistry,
    required this.onChanged,
    required this.resolveAttachmentPath,
    required this.onReplaceImage,
    required this.onReplaceAttachment,
    required this.onOpenAttachment,
    required this.viewportController,
    this.inputDispatcher,
    this.header,
    this.onInsertRequested,
    this.extent = const Size(4800, 3600),
    super.key,
  });

  final WorkspaceEditorSession session;
  final BlockRegistry registry;
  final WorkspaceInteractionController interaction;
  final BlockGeometryRegistry geometryRegistry;
  final BlockChangedCallback onChanged;
  final String? Function(String attachmentId) resolveAttachmentPath;
  final Future<void> Function(ImageBlock block) onReplaceImage;
  final Future<void> Function(AttachmentBlock block) onReplaceAttachment;
  final Future<void> Function(AttachmentBlock block) onOpenAttachment;
  final WorkspaceViewportController viewportController;
  final InputDispatcher? inputDispatcher;
  final Widget? header;
  final ValueChanged<Offset>? onInsertRequested;
  final Size extent;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      session.presentationRevision,
      viewportController,
    ]),
    builder: (context, _) {
      final page = session.page;
      final layout =
          (page.canvasLayout ?? CanvasLayoutState.forBlocks(session.blocks))
              .normalizedFor(session.blocks);
      final blocks = {
        for (final block in session.blocks.where((item) => item.isVisible))
          block.id: block,
      };
      final placements =
          layout.placements
              .where((placement) => blocks.containsKey(placement.blockId))
              .where(
                (placement) =>
                    placement.bounds().overlaps(_visibleBounds(context)),
              )
              .toList()
            ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.delete): () =>
              _dispatchDelete('Delete'),
          const SingleActivator(LogicalKeyboardKey.escape): _dispatchEscape,
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _dispatchOutsideTap,
          onLongPressStart: onInsertRequested == null
              ? null
              : (details) {
                  final point = SpatialPoint(
                    details.localPosition.dx,
                    details.localPosition.dy,
                  );
                  final hitsBlock = layout.placements.any(
                    (placement) => placement.bounds().contains(point),
                  );
                  final hitsHeader =
                      header != null &&
                      const SpatialRect.fromLTWH(
                        72,
                        32,
                        720,
                        150,
                      ).contains(point);
                  if (!hitsBlock && !hitsHeader) {
                    onInsertRequested!(details.localPosition);
                  }
                },
          child: SizedBox.fromSize(
            size: extent,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (layout.showGrid)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _CanvasGridPainter(
                          spacing: layout.gridSize,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                for (final frame in layout.frames)
                  Positioned(
                    left: frame.x,
                    top: frame.y,
                    width: frame.width,
                    height: frame.height,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              frame.title,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CanvasConnectorPainter(
                        layout: layout,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                if (header != null)
                  Positioned(left: 72, top: 32, width: 720, child: header!),
                for (final placement in placements)
                  Positioned(
                    key: ValueKey('canvas-${placement.blockId}'),
                    left: placement.x,
                    top: placement.y,
                    width: placement.width ?? 360,
                    height: blocks[placement.blockId] is ImageBlock
                        ? placement.height
                        : null,
                    child: AnimatedBuilder(
                      animation: interaction.blockListenable(placement.blockId),
                      builder: (context, _) {
                        final source = blocks[placement.blockId]!;
                        final renderBlock = source.copyWithCommon(
                          geometry: source.geometry.copyWith(x: 0, y: 0),
                        );
                        return registry.renderEditable(
                          BlockRenderContext(
                            block: renderBlock,
                            session: session,
                            interaction: interaction,
                            geometryRegistry: geometryRegistry,
                            visualLayer: placement.zIndex,
                            onChanged: onChanged,
                            resolveAttachmentPath: resolveAttachmentPath,
                            onReplaceImage: onReplaceImage,
                            onReplaceAttachment: onReplaceAttachment,
                            onOpenAttachment: onOpenAttachment,
                            inputDispatcher: inputDispatcher,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  SpatialRect _visibleBounds(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final visible = viewportController.camera.viewportToWorkspaceRect(
      SpatialRect.fromLTWH(0, 0, size.width, size.height),
    );
    const overscan = 320.0;
    return SpatialRect.fromLTRB(
      visible.left - overscan,
      visible.top - overscan,
      visible.right + overscan,
      visible.bottom + overscan,
    );
  }

  void _dispatchDelete(String key) {
    inputDispatcher?.dispatch(
      NormalizedInputEvent(
        eventId: generateUuid(),
        workspaceId: session.workspace.id,
        pageId: session.page.id,
        type: NormalizedInputEventType.keyDown,
        deviceType: InputDeviceType.keyboard,
        timestamp: DateTime.now().toUtc(),
        key: key,
      ),
    );
  }

  void _dispatchEscape() => interaction.dispatch(
    const CancelInteractionIntent(reason: InteractionCancellationReason.escape),
  );

  void _dispatchOutsideTap() {
    if (interaction.context.activeSession is MarqueeSelectionSession) return;
    interaction.dispatch(
      const CancelInteractionIntent(
        reason: InteractionCancellationReason.outsideTap,
      ),
    );
  }
}

class _CanvasGridPainter extends CustomPainter {
  const _CanvasGridPainter({required this.spacing, required this.color});

  final double spacing;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .45)
      ..strokeWidth = .75;
    for (var x = 0.0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_CanvasGridPainter oldDelegate) =>
      oldDelegate.spacing != spacing || oldDelegate.color != color;
}

class _CanvasConnectorPainter extends CustomPainter {
  const _CanvasConnectorPainter({required this.layout, required this.color});

  final CanvasLayoutState layout;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .75)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final connector in layout.connectors) {
      final source = layout.placementFor(connector.sourceBlockId);
      final target = layout.placementFor(connector.targetBlockId);
      if (source == null || target == null) continue;
      final start = source.bounds().center;
      final end = target.bounds().center;
      canvas.drawLine(Offset(start.x, start.y), Offset(end.x, end.y), paint);
      final direction = Offset(end.x - start.x, end.y - start.y);
      if (direction.distance < 12) continue;
      final unit = direction / direction.distance;
      final normal = Offset(-unit.dy, unit.dx);
      final tip = Offset(end.x, end.y);
      final base = tip - unit * 12;
      canvas.drawLine(tip, base + normal * 5, paint);
      canvas.drawLine(tip, base - normal * 5, paint);
    }
  }

  @override
  bool shouldRepaint(_CanvasConnectorPainter oldDelegate) =>
      oldDelegate.layout != layout || oldDelegate.color != color;
}
