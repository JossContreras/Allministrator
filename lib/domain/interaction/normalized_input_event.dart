import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';
import 'package:allministrator/domain/interaction/interaction_region.dart';
import 'package:allministrator/domain/interaction/workspace_hit_target.dart';

/// Neutral representation of input. It deliberately contains no Flutter types
/// so interpretation can be tested independently from a platform widget tree.
enum NormalizedInputEventType {
  pointerDown,
  pointerMove,
  pointerUp,
  pointerCancel,
  tap,
  doubleTap,
  longPressStart,
  longPressMove,
  longPressEnd,
  keyDown,
  keyUp,
  scroll,
  focusChanged,
  accessibilityAction,
  contextMenuRequest,
  scaleStart,
  scaleUpdate,
  scaleEnd,
  stylusHover,
  stylusButton,
  handwritingStroke,
}

enum InputDeviceType {
  touch,
  mouse,
  stylus,
  trackpad,
  keyboard,
  accessibility,
  unknown,
}

class InputModifiers {
  const InputModifiers({
    this.control = false,
    this.shift = false,
    this.alt = false,
    this.meta = false,
  });

  final bool control;
  final bool shift;
  final bool alt;
  final bool meta;

  bool get commandOrControl => control || meta;
}

/// Optional fields are intentionally limited to information that a particular
/// device/event cannot provide (for example pressure on a keyboard event).
class NormalizedInputEvent {
  const NormalizedInputEvent({
    required this.eventId,
    required this.workspaceId,
    required this.pageId,
    required this.type,
    required this.deviceType,
    required this.timestamp,
    this.pointerId,
    this.globalPosition,
    this.workspacePosition,
    this.localPosition,
    this.pressure,
    this.tilt,
    this.azimuth,
    this.buttons,
    this.modifiers = const InputModifiers(),
    this.scrollDelta,
    this.scaleDelta,
    this.rotationDelta,
    this.hitTarget,
    this.targetBlockId,
    this.targetRegionId,
    this.key,
    this.accessibilityAction,
    this.isPrimary = true,
    this.isSynthesized = false,
    this.metadata = const {},
  });

  final String eventId;
  final Uuid workspaceId;
  final Uuid pageId;
  final NormalizedInputEventType type;
  final InputDeviceType deviceType;
  final DateTime timestamp;
  final int? pointerId;
  final SpatialPoint? globalPosition;
  final SpatialPoint? workspacePosition;
  final SpatialPoint? localPosition;
  final double? pressure;
  final SpatialPoint? tilt;
  final double? azimuth;
  final int? buttons;
  final InputModifiers modifiers;
  final SpatialPoint? scrollDelta;
  final double? scaleDelta;
  final double? rotationDelta;
  final WorkspaceHitTarget? hitTarget;
  final Uuid? targetBlockId;
  final String? targetRegionId;
  final String? key;
  final String? accessibilityAction;
  final bool isPrimary;
  final bool isSynthesized;
  final Map<String, Object?> metadata;

  NormalizedInputEvent withHit(WorkspaceHitResult hit) => NormalizedInputEvent(
    eventId: eventId,
    workspaceId: workspaceId,
    pageId: pageId,
    type: type,
    deviceType: deviceType,
    timestamp: timestamp,
    pointerId: pointerId,
    globalPosition: globalPosition,
    workspacePosition: workspacePosition,
    localPosition: localPosition,
    pressure: pressure,
    tilt: tilt,
    azimuth: azimuth,
    buttons: buttons,
    modifiers: modifiers,
    scrollDelta: scrollDelta,
    scaleDelta: scaleDelta,
    rotationDelta: rotationDelta,
    hitTarget: hit.target,
    targetBlockId: hit.target.blockId,
    targetRegionId: hit.region?.id,
    key: key,
    accessibilityAction: accessibilityAction,
    isPrimary: isPrimary,
    isSynthesized: isSynthesized,
    metadata: metadata,
  );

  NormalizedInputEvent withWorkspacePosition(SpatialPoint position) =>
      NormalizedInputEvent(
        eventId: eventId,
        workspaceId: workspaceId,
        pageId: pageId,
        type: type,
        deviceType: deviceType,
        timestamp: timestamp,
        pointerId: pointerId,
        globalPosition: globalPosition,
        workspacePosition: position,
        localPosition: localPosition,
        pressure: pressure,
        tilt: tilt,
        azimuth: azimuth,
        buttons: buttons,
        modifiers: modifiers,
        scrollDelta: scrollDelta,
        scaleDelta: scaleDelta,
        rotationDelta: rotationDelta,
        hitTarget: hitTarget,
        targetBlockId: targetBlockId,
        targetRegionId: targetRegionId,
        key: key,
        accessibilityAction: accessibilityAction,
        isPrimary: isPrimary,
        isSynthesized: isSynthesized,
        metadata: metadata,
      );
}
