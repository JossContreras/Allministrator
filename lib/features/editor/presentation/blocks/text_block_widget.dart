import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_frame.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_render_context.dart';
import 'package:flutter/material.dart';

class TextBlockWidget extends StatefulWidget {
  const TextBlockWidget({required this.renderContext, super.key});

  final BlockRenderContext renderContext;

  @override
  State<TextBlockWidget> createState() => _TextBlockWidgetState();
}

class _TextBlockWidgetState extends State<TextBlockWidget> {
  late final _RichBlockEditingController _controller;
  late final FocusNode _focusNode;
  bool _applyingExternalValue = false;

  TextBlock get _block => widget.renderContext.block as TextBlock;

  @override
  void initState() {
    super.initState();
    _controller = _RichBlockEditingController(_block);
    final stored =
        widget.renderContext.session.selectionFor(_block.id) ??
        _block.selection;
    if (stored != null) {
      _controller.selection = TextSelection(
        baseOffset: stored.baseOffset.clamp(0, _controller.text.length),
        extentOffset: stored.extentOffset.clamp(0, _controller.text.length),
      );
    }
    _controller.addListener(_handleControllerChanged);
    _focusNode = FocusNode(debugLabel: 'text-block-${_block.id}')
      ..addListener(_handleFocusChanged);
    _requestFocusIfNeeded();
  }

  @override
  void didUpdateWidget(covariant TextBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = _block;
    if (incoming.plainText != _controller.text ||
        incoming.version != _controller.block.version) {
      _applyingExternalValue = true;
      final selection =
          widget.renderContext.session.selectionFor(incoming.id) ??
          incoming.selection;
      _controller.setExternalBlock(incoming, selection: selection);
      _applyingExternalValue = false;
    } else {
      _controller.block = incoming;
    }
    _requestFocusIfNeeded();
  }

  void _requestFocusIfNeeded() {
    if (!widget.renderContext.isEditing || widget.renderContext.readOnly) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focusNode.hasFocus) return;
      _focusNode.requestFocus();
    });
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      widget.renderContext.session.beginEditing(_block.id);
    }
    if (mounted) setState(() {});
  }

  void _handleControllerChanged() {
    if (_applyingExternalValue) return;
    final selection = BlockTextSelection(
      baseOffset: _controller.selection.baseOffset.clamp(
        0,
        _controller.text.length,
      ),
      extentOffset: _controller.selection.extentOffset.clamp(
        0,
        _controller.text.length,
      ),
    );
    widget.renderContext.session.updateTextSelection(_block.id, selection);
    if (_controller.text == _controller.block.plainText) return;
    final updated = _controller.block
        .withPlainText(_controller.text)
        .copyWith(selection: selection);
    _controller.block = updated;
    widget.renderContext.onChanged(updated, kind: 'editText', mergeable: true);
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = widget.renderContext.readOnly || _block.isLocked;
    return BlockFrame(
      block: _block,
      session: widget.renderContext.session,
      readOnly: widget.renderContext.readOnly,
      compact: true,
      onTap: () {
        widget.renderContext.session.beginEditing(_block.id);
        if (!readOnly) _focusNode.requestFocus();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            readOnly: readOnly,
            minLines: 1,
            maxLines: null,
            textAlign: _textAlign(),
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Escribe aquí…',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            ),
          ),
          if (widget.renderContext.isSelected &&
              widget.renderContext.session.canMergeTextWithNext(_block.id))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    widget.renderContext.session.mergeTextWithNext(_block.id),
                icon: const Icon(Icons.merge_type),
                label: const Text('Fusionar con el siguiente texto'),
              ),
            ),
        ],
      ),
    );
  }

  TextAlign _textAlign() {
    final alignment = widget.renderContext.isSelected
        ? widget.renderContext.session.currentParagraphAlignment
        : _block.paragraphs.first.attributes.alignment;
    return switch (alignment) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      'justify' => TextAlign.justify,
      _ => TextAlign.left,
    };
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }
}

class _RichBlockEditingController extends TextEditingController {
  _RichBlockEditingController(this.block) : super(text: block.plainText);

  TextBlock block;

  void setExternalBlock(TextBlock value, {BlockTextSelection? selection}) {
    block = value;
    final fallback = this.selection.isValid
        ? this.selection
        : const TextSelection.collapsed(offset: 0);
    final desired = selection == null
        ? fallback
        : TextSelection(
            baseOffset: selection.baseOffset,
            extentOffset: selection.extentOffset,
          );
    this.value = TextEditingValue(
      text: value.plainText,
      selection: TextSelection(
        baseOffset: desired.baseOffset.clamp(0, value.plainText.length),
        extentOffset: desired.extentOffset.clamp(0, value.plainText.length),
      ),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final children = <InlineSpan>[];
    for (var index = 0; index < block.paragraphs.length; index++) {
      final paragraph = block.paragraphs[index];
      children.add(_paragraphSpan(paragraph, base));
      if (index < block.paragraphs.length - 1) {
        children.add(TextSpan(text: '\n', style: base));
      }
    }
    return TextSpan(style: base, children: children);
  }

  TextSpan _paragraphSpan(BlockParagraph paragraph, TextStyle base) {
    final boundaries = <int>{0, paragraph.text.length};
    for (final mark in paragraph.spans) {
      boundaries
        ..add(mark.start.clamp(0, paragraph.text.length))
        ..add(mark.end.clamp(0, paragraph.text.length));
    }
    final sorted = boundaries.toList()..sort();
    return TextSpan(
      children: [
        for (var index = 0; index < sorted.length - 1; index++)
          _segment(paragraph, base, sorted[index], sorted[index + 1]),
      ],
    );
  }

  TextSpan _segment(
    BlockParagraph paragraph,
    TextStyle base,
    int start,
    int end,
  ) {
    final attributes = <String, Object?>{};
    for (final mark in paragraph.spans) {
      if (mark.start <= start && mark.end >= end) {
        attributes.addAll(mark.attributes);
      }
    }
    return TextSpan(
      text: paragraph.text.substring(start, end),
      style: base.copyWith(
        fontWeight: attributes['bold'] == true ? FontWeight.bold : null,
        fontStyle: attributes['italic'] == true ? FontStyle.italic : null,
        decoration: TextDecoration.combine([
          if (attributes['underline'] == true) TextDecoration.underline,
          if (attributes['strikethrough'] == true) TextDecoration.lineThrough,
        ]),
        color: attributes['color'] is int
            ? Color(attributes['color']! as int)
            : null,
        backgroundColor: attributes['highlight'] is int
            ? Color(attributes['highlight']! as int)
            : null,
        fontSize: attributes['fontSize'] is num
            ? (attributes['fontSize']! as num).toDouble()
            : null,
        fontFamily: attributes['fontFamily'] as String?,
      ),
    );
  }
}
