import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/interaction/drag_session.dart';
import 'package:allministrator/domain/interaction/interaction_models.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';
import 'package:allministrator/domain/interaction/transformation_engine.dart';
import 'package:allministrator/domain/ink/ink_models.dart';
import 'package:allministrator/domain/ink/ink_session.dart';

abstract class InteractionIntent {
  const InteractionIntent();
}

class SelectBlockIntent extends InteractionIntent {
  const SelectBlockIntent(this.blockId);

  final Uuid blockId;
}

class AddBlockToSelectionIntent extends InteractionIntent {
  const AddBlockToSelectionIntent(this.blockId);
  final Uuid blockId;
}

class RemoveBlockFromSelectionIntent extends InteractionIntent {
  const RemoveBlockFromSelectionIntent(this.blockId);
  final Uuid blockId;
}

class ToggleBlockSelectionIntent extends InteractionIntent {
  const ToggleBlockSelectionIntent(this.blockId);
  final Uuid blockId;
}

class SelectRangeIntent extends InteractionIntent {
  const SelectRangeIntent(this.blockId, {required this.visualOrder});
  final Uuid blockId;
  final List<Uuid> visualOrder;
}

class BeginMarqueeSelectionIntent extends InteractionIntent {
  const BeginMarqueeSelectionIntent(this.position);
  final InteractionPoint position;
}

class UpdateMarqueeSelectionIntent extends InteractionIntent {
  const UpdateMarqueeSelectionIntent({
    required this.position,
    required this.candidateIds,
  });
  final InteractionPoint position;
  final List<Uuid> candidateIds;
}

class CommitMarqueeSelectionIntent extends InteractionIntent {
  const CommitMarqueeSelectionIntent();
}

class CancelMarqueeSelectionIntent extends InteractionIntent {
  const CancelMarqueeSelectionIntent();
}

class DeleteSelectionIntent extends InteractionIntent {
  const DeleteSelectionIntent();
}

class CopySelectionIntent extends InteractionIntent {
  const CopySelectionIntent();
}

class ClearSelectionIntent extends InteractionIntent {
  const ClearSelectionIntent({
    this.reason = InteractionCancellationReason.explicit,
  });

  final InteractionCancellationReason reason;
}

class SelectInkElementsIntent extends InteractionIntent {
  const SelectInkElementsIntent(this.elementIds);

  final List<Uuid> elementIds;
}

class StartEditingIntent extends InteractionIntent {
  const StartEditingIntent({
    required this.blockId,
    this.selection,
    this.focusTargetId,
    this.selectBlock = true,
  });

  final Uuid blockId;
  final WorkspaceSelection? selection;
  final String? focusTargetId;
  final bool selectBlock;
}

class FinishEditingIntent extends InteractionIntent {
  const FinishEditingIntent({this.keepBlockSelected = true});

  final bool keepBlockSelected;
}

class CancelInteractionIntent extends InteractionIntent {
  const CancelInteractionIntent({
    this.reason = InteractionCancellationReason.explicit,
    this.keepBlockSelected = false,
  });

  final InteractionCancellationReason reason;
  final bool keepBlockSelected;
}

class OpenContextMenuIntent extends InteractionIntent {
  const OpenContextMenuIntent({required this.blockId, this.anchor});

  final Uuid blockId;
  final InteractionPoint? anchor;
}

class UpdateTextSelectionIntent extends InteractionIntent {
  const UpdateTextSelectionIntent(this.selection);

  final TextSelectionState selection;
}

class UpdatePointerIntent extends InteractionIntent {
  const UpdatePointerIntent(this.pointer);

  final InteractionPointer pointer;
}

class ClearPointerIntent extends InteractionIntent {
  const ClearPointerIntent();
}

class BeginDragIntent extends InteractionIntent {
  const BeginDragIntent(this.blockId);

  final Uuid blockId;
}

class UpdateDragIntent extends InteractionIntent {
  const UpdateDragIntent({required this.position, this.dropTarget});

  final InteractionPoint position;
  final DropTarget? dropTarget;
}

class CommitDragIntent extends InteractionIntent {
  const CommitDragIntent(this.dropTarget);

  final DropTarget dropTarget;
}

class CommitCanvasDragIntent extends InteractionIntent {
  const CommitCanvasDragIntent({required this.blockIds, required this.delta});

  final List<Uuid> blockIds;
  final SpatialPoint delta;
}

class ResizeIntent extends InteractionIntent {
  const ResizeIntent(this.blockId);

  final Uuid blockId;
}

class BeginResizeIntent extends InteractionIntent {
  const BeginResizeIntent({
    required this.blockId,
    required this.handle,
    required this.position,
    required this.initialBounds,
  });

  final Uuid blockId;
  final ResizeHandle handle;
  final InteractionPoint position;
  final SpatialRect initialBounds;
}

class UpdateResizeIntent extends InteractionIntent {
  const UpdateResizeIntent({
    required this.position,
    required this.previewBounds,
    this.guides = const [],
  });

  final InteractionPoint position;
  final SpatialRect previewBounds;
  final List<SmartGuide> guides;
}

class CommitResizeIntent extends InteractionIntent {
  const CommitResizeIntent({required this.blockId, required this.bounds});

  final Uuid blockId;
  final SpatialRect bounds;
}

class CancelResizeIntent extends InteractionIntent {
  const CancelResizeIntent();
}

class AlignSelectionIntent extends InteractionIntent {
  const AlignSelectionIntent(this.alignment);

  final BlockAlignmentAxis alignment;
}

class DistributeSelectionIntent extends InteractionIntent {
  const DistributeSelectionIntent();
}

class RotateIntent extends InteractionIntent {
  const RotateIntent(this.blockId);

  final Uuid blockId;
}

class StartHandwritingIntent extends InteractionIntent {
  const StartHandwritingIntent();
}

class BeginInkIntent extends InteractionIntent {
  const BeginInkIntent({
    required this.correlationId,
    required this.pointerId,
    required this.tool,
    required this.point,
    required this.brush,
    this.shapeKind,
    this.anchor,
  });

  final String correlationId;
  final int pointerId;
  final WorkspaceTool tool;
  final InkPoint point;
  final InkBrushStyle brush;
  final InkShapeKind? shapeKind;
  final AnnotationAnchor? anchor;
}

class UpdateInkIntent extends InteractionIntent {
  const UpdateInkIntent({
    required this.point,
    this.affectedElementIds = const [],
  });

  final InkPoint point;
  final List<String> affectedElementIds;
}

class CommitInkIntent extends InteractionIntent {
  const CommitInkIntent(this.session);

  final InkSession session;
}

class CancelInkIntent extends InteractionIntent {
  const CancelInkIntent();
}

class PanViewportIntent extends InteractionIntent {
  const PanViewportIntent(this.delta);

  final InteractionPoint delta;
}

class ZoomViewportIntent extends InteractionIntent {
  const ZoomViewportIntent(this.scale);

  final double scale;
}
