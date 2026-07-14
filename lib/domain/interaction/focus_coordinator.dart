import 'package:allministrator/core/shared/identifiers.dart';

typedef FocusAction = void Function();
typedef FocusStateChanged = void Function(Uuid? blockId);

class FocusCoordinator {
  FocusCoordinator({required FocusStateChanged onFocusedBlockChanged})
    : _onFocusedBlockChanged = onFocusedBlockChanged;

  final FocusStateChanged _onFocusedBlockChanged;
  final Map<String, _FocusTarget> _targets = {};
  String? _focusedTargetId;

  Uuid? get focusedBlockId =>
      _focusedTargetId == null ? null : _targets[_focusedTargetId]?.blockId;

  void registerTarget({
    required String targetId,
    required Uuid blockId,
    required FocusAction requestFocus,
    required FocusAction releaseFocus,
  }) {
    _targets[targetId] = _FocusTarget(
      blockId: blockId,
      requestFocus: requestFocus,
      releaseFocus: releaseFocus,
    );
  }

  void unregisterTarget(String targetId) {
    final wasFocused = _focusedTargetId == targetId;
    _targets.remove(targetId);
    if (wasFocused) {
      _focusedTargetId = null;
      _onFocusedBlockChanged(null);
    }
  }

  bool requestFocus(Uuid blockId, {String? targetId}) {
    final resolvedId =
        targetId != null && _targets[targetId]?.blockId == blockId
        ? targetId
        : _targets.entries
              .where((entry) => entry.value.blockId == blockId)
              .map((entry) => entry.key)
              .firstOrNull;
    if (resolvedId == null) return false;
    if (_focusedTargetId != resolvedId) {
      _targets[_focusedTargetId]?.releaseFocus();
      _focusedTargetId = resolvedId;
    }
    _targets[resolvedId]?.requestFocus();
    _onFocusedBlockChanged(blockId);
    return true;
  }

  void reportFocusChange(String targetId, {required bool hasFocus}) {
    final target = _targets[targetId];
    if (target == null) return;
    if (hasFocus) {
      _focusedTargetId = targetId;
      _onFocusedBlockChanged(target.blockId);
    } else if (_focusedTargetId == targetId) {
      _focusedTargetId = null;
      _onFocusedBlockChanged(null);
    }
  }

  void clearFocus() {
    final targetId = _focusedTargetId;
    _focusedTargetId = null;
    _targets[targetId]?.releaseFocus();
    _onFocusedBlockChanged(null);
  }

  void dispose() {
    _targets.clear();
    _focusedTargetId = null;
  }
}

class _FocusTarget {
  const _FocusTarget({
    required this.blockId,
    required this.requestFocus,
    required this.releaseFocus,
  });

  final Uuid blockId;
  final FocusAction requestFocus;
  final FocusAction releaseFocus;
}
