import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/blocks/blocks.dart';
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
      _focusNodes.putIfAbsent(
        item.id,
        () => FocusNode(debugLabel: 'checklist-${item.id}'),
      );
    }
    for (final id
        in _controllers.keys.where((id) => !ids.contains(id)).toList()) {
      _controllers.remove(id)?.dispose();
      _focusNodes.remove(id)?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => BlockFrame(
    block: block,
    session: widget.renderContext.session,
    readOnly: widget.renderContext.readOnly,
    onTap: () => widget.renderContext.session.selectBlock(block.id),
    child: Column(
      children: [
        for (var index = 0; index < block.items.length; index++)
          _item(context, block.items[index], index),
        if (widget.renderContext.isSelected && !widget.renderContext.readOnly)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addItem(block.items.length - 1),
              icon: const Icon(Icons.add),
              label: const Text('Agregar elemento'),
            ),
          ),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
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
            Expanded(
              child: TextField(
                controller: _controllers[item.id],
                focusNode: _focusNodes[item.id],
                readOnly: widget.renderContext.readOnly || block.isLocked,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Elemento',
                  isDense: true,
                ),
                style: TextStyle(
                  decoration: item.isChecked
                      ? TextDecoration.lineThrough
                      : null,
                ),
                onTap: () =>
                    widget.renderContext.session.beginEditing(block.id),
                onChanged: (text) => _replaceItem(
                  index,
                  item.copyWith(text: text),
                  kind: 'editChecklistItem',
                  mergeable: true,
                ),
                onSubmitted: (_) => _addItem(index),
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
      _focusNodes[item.id]?.requestFocus();
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
      _focusNodes[target]?.requestFocus();
      _controllers.remove(removed.id)?.dispose();
      _focusNodes.remove(removed.id)?.dispose();
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }
}
