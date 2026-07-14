import 'package:allministrator/domain/interaction/block_geometry_registry.dart';
import 'package:allministrator/domain/interaction/drag_session.dart';
import 'package:allministrator/domain/interaction/interaction_models.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';
import 'package:allministrator/domain/interaction/marquee_selection_session.dart';
import 'package:allministrator/domain/interaction/selection_group.dart';
import 'package:allministrator/domain/interaction/workspace_interaction_controller.dart';
import 'package:allministrator/domain/interaction/transformation_engine.dart';
import 'package:flutter/foundation.dart';

class WorkspaceOverlayVisualState {
  const WorkspaceOverlayVisualState({
    this.selectedBlockId,
    this.selectedBounds,
    this.visibleBounds,
    this.handleAnchor,
    this.toolbarAnchor,
    this.showSelectionBorder = false,
    this.showSelectionHighlight = false,
    this.showHandle = false,
    this.showToolbarAnchor = false,
    this.activePointer,
    this.dragGhostBounds,
    this.placeholderY,
    this.isDragging = false,
    this.selectedBlockIds = const [],
    this.combinedSelectionBounds,
    this.marqueeBounds,
    this.resizePreviewBounds,
    this.smartGuides = const [],
  });

  final String? selectedBlockId;
  final SpatialRect? selectedBounds;
  final SpatialRect? visibleBounds;
  final SpatialPoint? handleAnchor;
  final SpatialPoint? toolbarAnchor;
  final bool showSelectionBorder;
  final bool showSelectionHighlight;
  final bool showHandle;
  final bool showToolbarAnchor;
  final InteractionPointer? activePointer;
  final SpatialRect? dragGhostBounds;
  final double? placeholderY;
  final bool isDragging;
  final List<String> selectedBlockIds;
  final SpatialRect? combinedSelectionBounds;
  final SpatialRect? marqueeBounds;
  final SpatialRect? resizePreviewBounds;
  final List<SmartGuide> smartGuides;
}

/// Derived visual state. Selection remains owned by WorkspaceInteractionController.
class InteractionOverlayController extends ChangeNotifier {
  InteractionOverlayController({
    required this.interaction,
    required this.registry,
  }) {
    interaction.addListener(_refresh);
    registry.addListener(_refresh);
    _refresh();
  }

  final WorkspaceInteractionController interaction;
  final BlockGeometryRegistry registry;
  WorkspaceOverlayVisualState _state = const WorkspaceOverlayVisualState();

  WorkspaceOverlayVisualState get state => _state;

  InteractionContext get _context => interaction.context;

  void _refresh() {
    final context = _context;
    final group = switch (context.currentSelection) {
      MultiBlockSelection(:final group) => group,
      BlockSelection(:final blockId) => SelectionGroup(
        blockIds: [blockId],
        primaryBlockId: blockId,
        anchorBlockId: blockId,
      ),
      _ => const SelectionGroup(),
    };
    final entry = context.selectedBlock == null
        ? null
        : registry.geometryFor(context.selectedBlock!);
    final isTextEditing =
        context.interactionMode == InteractionMode.textEditing;
    final drag = context.activeSession;
    final dragSession = drag is DragSession ? drag : null;
    final marqueeSession = drag is MarqueeSelectionSession ? drag : null;
    final resizeSession = drag is ResizeSession ? drag : null;
    final dragEntry = dragSession?.blockId == null
        ? null
        : registry.geometryFor(dragSession!.blockId!);
    final placeholderEntry = dragSession?.dropTarget?.targetBlockId == null
        ? null
        : registry.geometryFor(dragSession!.dropTarget!.targetBlockId!);
    _state = WorkspaceOverlayVisualState(
      selectedBlockId: entry?.blockId,
      selectedBounds: entry?.globalBounds,
      visibleBounds: registry.viewport?.visibleBounds,
      handleAnchor: entry?.handleAnchor,
      toolbarAnchor: entry?.toolbarAnchor,
      showSelectionBorder:
          entry != null &&
          !isTextEditing &&
          dragSession == null &&
          resizeSession == null,
      showSelectionHighlight:
          entry != null &&
          !isTextEditing &&
          dragSession == null &&
          resizeSession == null,
      showHandle:
          entry != null &&
          !isTextEditing &&
          dragSession == null &&
          resizeSession == null,
      showToolbarAnchor: entry != null,
      activePointer: context.currentPointer,
      isDragging: dragSession != null,
      selectedBlockIds: group.blockIds,
      combinedSelectionBounds: SelectionBoundsResolver(registry).resolve(group),
      marqueeBounds: marqueeSession?.bounds,
      resizePreviewBounds: resizeSession?.previewBounds,
      smartGuides: resizeSession?.guides ?? const [],
      dragGhostBounds:
          (dragSession == null
                  ? dragEntry?.globalBounds
                  : SelectionBoundsResolver(
                      registry,
                    ).resolve(SelectionGroup(blockIds: dragSession.blockIds)))
              ?.translate(dragSession?.delta.x ?? 0, dragSession?.delta.y ?? 0),
      placeholderY: placeholderEntry == null
          ? null
          : dragSession!.dropTarget!.insertAfter
          ? placeholderEntry.globalBounds.bottom
          : placeholderEntry.globalBounds.top,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    interaction.removeListener(_refresh);
    registry.removeListener(_refresh);
    super.dispose();
  }
}
