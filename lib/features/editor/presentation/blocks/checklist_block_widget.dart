import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/app/theme/app_motion.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_frame.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_render_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChecklistBlockWidget extends StatefulWidget {
  const ChecklistBlockWidget({required this.renderContext, super.key});

  final BlockRenderContext renderContext;

  @override
  State<ChecklistBlockWidget> createState() => _ChecklistBlockWidgetState();
}

class _ChecklistBlockWidgetState extends State<ChecklistBlockWidget> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  late ChecklistBlock _current;

  ChecklistBlock get block => _current;

  @override
  void initState() {
    super.initState();
    _current = widget.renderContext.block as ChecklistBlock;
    _syncEditors();
  }

  @override
  void didUpdateWidget(covariant ChecklistBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.renderContext.block as ChecklistBlock;
    if (incoming.version != _current.version) _current = incoming;
    _syncEditors();
  }

  void _syncEditors() {
    final ids = block.items.map((item) => item.id).toSet();
    for (final item in block.items) {
      final controller = _controllers.putIfAbsent(
        item.id,
        () => TextEditingController(text: item.text),
      );
      if (!controller.selection.isValid && controller.text != item.text) {
        controller.text = item.text;
      }
      _focusNodes.putIfAbsent(item.id, () {
        final targetId = _focusTargetId(item.id);
        final node = FocusNode(debugLabel: targetId);
        node.addListener(() {
          widget.renderContext.interaction.focusCoordinator.reportFocusChange(
            targetId,
            hasFocus: node.hasFocus,
          );
        });
        widget.renderContext.interaction.focusCoordinator.registerTarget(
          targetId: targetId,
          blockId: block.id,
          requestFocus: node.requestFocus,
          releaseFocus: node.unfocus,
        );
        return node;
      });
    }
    for (final id
        in _controllers.keys.where((id) => !ids.contains(id)).toList()) {
      _controllers.remove(id)?.dispose();
      widget.renderContext.interaction.focusCoordinator.unregisterTarget(
        _focusTargetId(id),
      );
      _focusNodes.remove(id)?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => BlockFrame(
    block: block,
    geometryRegistry: widget.renderContext.geometryRegistry,
    workspaceId: widget.renderContext.session.workspace.id,
    pageId: widget.renderContext.session.page.id,
    visualLayer: widget.renderContext.visualLayer,
    child: Column(
      children: [
        for (var index = 0; index < block.items.length; index++)
          _item(context, block.items[index], index),
      ],
    ),
  );

  Widget _item(BuildContext context, BlockChecklistItem item, int index) =>
      Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _controllers[item.id]!.text.isEmpty &&
              block.items.length > 1) {
            _removeItem(index);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            widget.renderContext.region(
              id: 'checkbox-${item.id}',
              target: InternalControlHitTarget(
                block.id,
                controlId: 'checkbox-${item.id}',
              ),
              priority: 30,
              child: AnimatedSwitcher(
                duration: AppMotion.fast,
                child: Checkbox(
                  key: ValueKey(item.isChecked),
                  value: item.isChecked,
                  onChanged: widget.renderContext.readOnly || block.isLocked
                      ? null
                      : (value) {
                          final currentItem = block.items[index];
                          _replaceItem(
                            index,
                            currentItem.copyWith(isChecked: value ?? false),
                            kind: 'toggleChecklistItem',
                          );
                        },
                ),
              ),
            ),
            Expanded(
              child: widget.renderContext.region(
                id: 'item-text-${item.id}',
                target: TextRegionHitTarget(block.id, fieldId: item.id),
                priority: 20,
                child: TextField(
                  controller: _controllers[item.id],
                  focusNode: _focusNodes[item.id],
                  readOnly: widget.renderContext.readOnly || block.isLocked,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Elemento',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                  ),
                  style: TextStyle(
                    decoration: item.isChecked
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  onTap: () => widget.renderContext.interaction.dispatch(
                    StartEditingIntent(
                      blockId: block.id,
                      focusTargetId: _focusTargetId(item.id),
                      selectBlock: false,
                    ),
                  ),
                  onChanged: (text) => _replaceItem(
                    index,
                    item.copyWith(text: text),
                    kind: 'editChecklistItem',
                    mergeable: true,
                  ),
                  onSubmitted: (_) => _addItem(index),
                ),
              ),
            ),
          ],
        ),
      );

  void _replaceItem(
    int index,
    BlockChecklistItem item, {
    required String kind,
    bool mergeable = false,
  }) {
    final items = [...block.items]..[index] = item;
    _current = block.copyWith(items: items);
    widget.renderContext.onChanged(_current, kind: kind, mergeable: mergeable);
    if (mounted) setState(() {});
  }

  void _addItem(int afterIndex) {
    final item = BlockChecklistItem(id: generateUuid(), text: '');
    final items = [...block.items]..insert(afterIndex + 1, item);
    _current = block.copyWith(items: items);
    widget.renderContext.onChanged(
      _current,
      kind: 'addChecklistItem',
      refreshPresentation: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.renderContext.interaction.dispatch(
        StartEditingIntent(
          blockId: block.id,
          focusTargetId: _focusTargetId(item.id),
          selectBlock: false,
        ),
      );
    });
  }

  void _removeItem(int index) {
    final removed = block.items[index];
    final items = [...block.items]..removeAt(index);
    _current = block.copyWith(items: items);
    widget.renderContext.onChanged(
      _current,
      kind: 'removeChecklistItem',
      refreshPresentation: true,
    );
    final target = items[(index - 1).clamp(0, items.length - 1)].id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.renderContext.interaction.dispatch(
        StartEditingIntent(
          blockId: block.id,
          focusTargetId: _focusTargetId(target),
          selectBlock: false,
        ),
      );
      _controllers.remove(removed.id)?.dispose();
      widget.renderContext.interaction.focusCoordinator.unregisterTarget(
        _focusTargetId(removed.id),
      );
      _focusNodes.remove(removed.id)?.dispose();
    });
  }

  String _focusTargetId(String itemId) => 'checklist-${block.id}-$itemId';

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    for (final id in _focusNodes.keys) {
      widget.renderContext.interaction.focusCoordinator.unregisterTarget(
        _focusTargetId(id),
      );
    }
    super.dispose();
  }
}
