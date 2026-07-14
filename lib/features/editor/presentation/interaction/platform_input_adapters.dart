import 'dart:ui' show PointerDeviceKind;

import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent;

class PointerInputAdapter {
  const PointerInputAdapter();

  NormalizedInputEvent adapt({
    required PointerEvent event,
    required String workspaceId,
    required String pageId,
    required NormalizedInputEventType type,
    WorkspaceHitResult? hit,
  }) => NormalizedInputEvent(
    eventId: generateUuid(),
    workspaceId: workspaceId,
    pageId: pageId,
    type: type,
    deviceType: _device(event.kind),
    timestamp: DateTime.now().toUtc(),
    pointerId: event.pointer,
    globalPosition: SpatialPoint(event.position.dx, event.position.dy),
    localPosition: SpatialPoint(event.localPosition.dx, event.localPosition.dy),
    pressure: event.pressure,
    buttons: event.buttons,
    hitTarget: hit?.target,
    targetBlockId: hit?.target.blockId,
    targetRegionId: hit?.region?.id,
    isPrimary: event.down || event.kind != PointerDeviceKind.mouse,
  );

  InputDeviceType _device(PointerDeviceKind kind) => switch (kind) {
    PointerDeviceKind.touch => InputDeviceType.touch,
    PointerDeviceKind.mouse => InputDeviceType.mouse,
    PointerDeviceKind.stylus ||
    PointerDeviceKind.invertedStylus => InputDeviceType.stylus,
    PointerDeviceKind.trackpad => InputDeviceType.trackpad,
    _ => InputDeviceType.unknown,
  };
}

class GestureInputAdapter {
  const GestureInputAdapter();

  NormalizedInputEvent tap({
    required String workspaceId,
    required String pageId,
    required WorkspaceHitTarget target,
    String? regionId,
  }) => NormalizedInputEvent(
    eventId: generateUuid(),
    workspaceId: workspaceId,
    pageId: pageId,
    type: NormalizedInputEventType.tap,
    deviceType: InputDeviceType.touch,
    timestamp: DateTime.now().toUtc(),
    hitTarget: target,
    targetBlockId: target.blockId,
    targetRegionId: regionId,
  );
}

class KeyboardInputAdapter {
  const KeyboardInputAdapter();

  NormalizedInputEvent adapt({
    required KeyEvent event,
    required String workspaceId,
    required String pageId,
  }) => NormalizedInputEvent(
    eventId: generateUuid(),
    workspaceId: workspaceId,
    pageId: pageId,
    type: event is KeyDownEvent
        ? NormalizedInputEventType.keyDown
        : NormalizedInputEventType.keyUp,
    deviceType: InputDeviceType.keyboard,
    timestamp: DateTime.now().toUtc(),
    key: event.logicalKey.keyLabel,
  );
}

class AccessibilityInputAdapter {
  const AccessibilityInputAdapter();

  NormalizedInputEvent action({
    required String workspaceId,
    required String pageId,
    required WorkspaceHitTarget target,
    required String action,
  }) => NormalizedInputEvent(
    eventId: generateUuid(),
    workspaceId: workspaceId,
    pageId: pageId,
    type: NormalizedInputEventType.accessibilityAction,
    deviceType: InputDeviceType.accessibility,
    timestamp: DateTime.now().toUtc(),
    hitTarget: target,
    targetBlockId: target.blockId,
    accessibilityAction: action,
  );
}
