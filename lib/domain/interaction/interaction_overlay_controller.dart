import 'package:allministrator/domain/interaction/block_geometry_registry.dart';
import 'package:allministrator/domain/interaction/interaction_models.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';
import 'package:allministrator/domain/interaction/workspace_interaction_controller.dart';
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
    final entry = context.selectedBlock == null
        ? null
        : registry.geometryFor(context.selectedBlock!);
    final isTextEditing =
        context.interactionMode == InteractionMode.textEditing;
    _state = WorkspaceOverlayVisualState(
      selectedBlockId: entry?.blockId,
      selectedBounds: entry?.globalBounds,
      visibleBounds: registry.viewport?.visibleBounds,
      handleAnchor: entry?.handleAnchor,
      toolbarAnchor: entry?.toolbarAnchor,
      showSelectionBorder: entry != null && !isTextEditing,
      showSelectionHighlight: entry != null && !isTextEditing,
      showHandle: entry != null && !isTextEditing,
      showToolbarAnchor: entry != null,
      activePointer: context.currentPointer,
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
