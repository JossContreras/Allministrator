import 'package:allministrator/core/shared/identifiers.dart';

enum WorkspaceHitTargetKind {
  emptyArea,
  blockBackground,
  blockContent,
  blockHandle,
  textRegion,
  internalControl,
  tableCell,
  attachmentAction,
  customRegion,
  resizeHandle,
  rotateHandle,
  canvasRegion,
  lassoRegion,
}

sealed class WorkspaceHitTarget {
  const WorkspaceHitTarget(this.kind, {this.blockId});

  final WorkspaceHitTargetKind kind;
  final Uuid? blockId;
}

class EmptyAreaHitTarget extends WorkspaceHitTarget {
  const EmptyAreaHitTarget() : super(WorkspaceHitTargetKind.emptyArea);
}

class BlockBackgroundHitTarget extends WorkspaceHitTarget {
  const BlockBackgroundHitTarget(Uuid blockId)
    : super(WorkspaceHitTargetKind.blockBackground, blockId: blockId);
}

class BlockContentHitTarget extends WorkspaceHitTarget {
  const BlockContentHitTarget(Uuid blockId)
    : super(WorkspaceHitTargetKind.blockContent, blockId: blockId);
}

class BlockHandleHitTarget extends WorkspaceHitTarget {
  const BlockHandleHitTarget(Uuid blockId)
    : super(WorkspaceHitTargetKind.blockHandle, blockId: blockId);
}

class TextRegionHitTarget extends WorkspaceHitTarget {
  const TextRegionHitTarget(Uuid blockId, {this.fieldId})
    : super(WorkspaceHitTargetKind.textRegion, blockId: blockId);

  final String? fieldId;
}

class InternalControlHitTarget extends WorkspaceHitTarget {
  const InternalControlHitTarget(Uuid blockId, {required this.controlId})
    : super(WorkspaceHitTargetKind.internalControl, blockId: blockId);

  final String controlId;
}

class TableCellHitTarget extends WorkspaceHitTarget {
  const TableCellHitTarget(
    Uuid blockId, {
    required this.cellId,
    required this.rowIndex,
    required this.columnIndex,
  }) : super(WorkspaceHitTargetKind.tableCell, blockId: blockId);

  final Uuid cellId;
  final int rowIndex;
  final int columnIndex;
}

class AttachmentActionHitTarget extends WorkspaceHitTarget {
  const AttachmentActionHitTarget(Uuid blockId, {required this.actionId})
    : super(WorkspaceHitTargetKind.attachmentAction, blockId: blockId);

  final String actionId;
}

class CustomRegionHitTarget extends WorkspaceHitTarget {
  const CustomRegionHitTarget(Uuid blockId, {required this.name})
    : super(WorkspaceHitTargetKind.customRegion, blockId: blockId);

  final String name;
}

class ResizeHandleHitTarget extends WorkspaceHitTarget {
  const ResizeHandleHitTarget(Uuid blockId)
    : super(WorkspaceHitTargetKind.resizeHandle, blockId: blockId);
}

class RotateHandleHitTarget extends WorkspaceHitTarget {
  const RotateHandleHitTarget(Uuid blockId)
    : super(WorkspaceHitTargetKind.rotateHandle, blockId: blockId);
}

class CanvasRegionHitTarget extends WorkspaceHitTarget {
  const CanvasRegionHitTarget() : super(WorkspaceHitTargetKind.canvasRegion);
}

class LassoRegionHitTarget extends WorkspaceHitTarget {
  const LassoRegionHitTarget() : super(WorkspaceHitTargetKind.lassoRegion);
}

bool equivalentHitTargets(WorkspaceHitTarget first, WorkspaceHitTarget second) {
  if (first.kind != second.kind || first.blockId != second.blockId) {
    return false;
  }
  return switch ((first, second)) {
    (TextRegionHitTarget a, TextRegionHitTarget b) => a.fieldId == b.fieldId,
    (InternalControlHitTarget a, InternalControlHitTarget b) =>
      a.controlId == b.controlId,
    (TableCellHitTarget a, TableCellHitTarget b) =>
      a.cellId == b.cellId &&
          a.rowIndex == b.rowIndex &&
          a.columnIndex == b.columnIndex,
    (AttachmentActionHitTarget a, AttachmentActionHitTarget b) =>
      a.actionId == b.actionId,
    (CustomRegionHitTarget a, CustomRegionHitTarget b) => a.name == b.name,
    _ => first.runtimeType == second.runtimeType,
  };
}
