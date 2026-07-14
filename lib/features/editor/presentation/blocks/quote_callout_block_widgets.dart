import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_frame.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_render_context.dart';
import 'package:flutter/material.dart';

class QuoteBlockWidget extends StatefulWidget {
  const QuoteBlockWidget({required this.renderContext, super.key});
  final BlockRenderContext renderContext;

  @override
  State<QuoteBlockWidget> createState() => _QuoteBlockWidgetState();
}

class _QuoteBlockWidgetState extends State<QuoteBlockWidget> {
  late final TextEditingController _textController;
  late final TextEditingController _citationController;
  late final FocusNode _textFocus;
  late final FocusNode _citationFocus;
  late QuoteBlock _current;
  bool _external = false;

  QuoteBlock get block => _current;

  @override
  void initState() {
    super.initState();
    _current = widget.renderContext.block as QuoteBlock;
    _textController = TextEditingController(text: block.text)
      ..addListener(_changed);
    _citationController = TextEditingController(text: block.citation)
      ..addListener(_changed);
    _textFocus = _createFocusNode('quote-text-${block.id}');
    _citationFocus = _createFocusNode('quote-citation-${block.id}');
  }

  @override
  void didUpdateWidget(covariant QuoteBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.renderContext.block as QuoteBlock;
    if (incoming.version != _current.version) _current = incoming;
    _external = true;
    if (_textController.text != block.text) _textController.text = block.text;
    if (_citationController.text != (block.citation ?? '')) {
      _citationController.text = block.citation ?? '';
    }
    _external = false;
  }

  void _changed() {
    if (_external) return;
    _current = block.copyWith(
      text: _textController.text,
      citation: _citationController.text,
      clearCitation: _citationController.text.trim().isEmpty,
    );
    widget.renderContext.onChanged(
      _current,
      kind: 'editQuote',
      mergeable: true,
    );
  }

  @override
  Widget build(BuildContext context) => BlockFrame(
    block: block,
    geometryRegistry: widget.renderContext.geometryRegistry,
    workspaceId: widget.renderContext.session.workspace.id,
    pageId: widget.renderContext.session.page.id,
    visualLayer: widget.renderContext.visualLayer,
    child: Container(
      padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _textController,
            focusNode: _textFocus,
            readOnly: widget.renderContext.readOnly || block.isLocked,
            minLines: 1,
            maxLines: null,
            style: const TextStyle(fontStyle: FontStyle.italic),
            onTap: () => _startEditing('quote-text-${block.id}'),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Escribe una cita…',
            ),
          ),
          TextField(
            controller: _citationController,
            focusNode: _citationFocus,
            readOnly: widget.renderContext.readOnly || block.isLocked,
            onTap: () => _startEditing('quote-citation-${block.id}'),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Autor o fuente opcional',
              prefixText: '— ',
            ),
          ),
        ],
      ),
    ),
  );

  FocusNode _createFocusNode(String targetId) {
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
  }

  void _startEditing(String targetId) {
    widget.renderContext.interaction.dispatch(
      StartEditingIntent(blockId: block.id, focusTargetId: targetId),
    );
  }

  @override
  void dispose() {
    widget.renderContext.interaction.focusCoordinator
      ..unregisterTarget('quote-text-${block.id}')
      ..unregisterTarget('quote-citation-${block.id}');
    _textController
      ..removeListener(_changed)
      ..dispose();
    _citationController
      ..removeListener(_changed)
      ..dispose();
    _textFocus.dispose();
    _citationFocus.dispose();
    super.dispose();
  }
}

class CalloutBlockWidget extends StatefulWidget {
  const CalloutBlockWidget({required this.renderContext, super.key});
  final BlockRenderContext renderContext;

  @override
  State<CalloutBlockWidget> createState() => _CalloutBlockWidgetState();
}

class _CalloutBlockWidgetState extends State<CalloutBlockWidget> {
  late final TextEditingController _titleController;
  late final TextEditingController _textController;
  late final FocusNode _titleFocus;
  late final FocusNode _textFocus;
  late CalloutBlock _current;
  bool _external = false;

  CalloutBlock get block => _current;

  @override
  void initState() {
    super.initState();
    _current = widget.renderContext.block as CalloutBlock;
    _titleController = TextEditingController(text: block.title)
      ..addListener(_changed);
    _textController = TextEditingController(text: block.text)
      ..addListener(_changed);
    _titleFocus = _createFocusNode('callout-title-${block.id}');
    _textFocus = _createFocusNode('callout-text-${block.id}');
  }

  @override
  void didUpdateWidget(covariant CalloutBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.renderContext.block as CalloutBlock;
    if (incoming.version != _current.version) _current = incoming;
    _external = true;
    if (_titleController.text != (block.title ?? '')) {
      _titleController.text = block.title ?? '';
    }
    if (_textController.text != block.text) _textController.text = block.text;
    _external = false;
  }

  void _changed() {
    if (_external) return;
    _current = block.copyWith(
      title: _titleController.text,
      clearTitle: _titleController.text.trim().isEmpty,
      text: _textController.text,
    );
    widget.renderContext.onChanged(
      _current,
      kind: 'editCallout',
      mergeable: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors(context, block.calloutType);
    return BlockFrame(
      block: block,
      geometryRegistry: widget.renderContext.geometryRegistry,
      workspaceId: widget.renderContext.session.workspace.id,
      pageId: widget.renderContext.session.page.id,
      visualLayer: widget.renderContext.visualLayer,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.$1,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon(block.calloutType), color: colors.$2),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocus,
                    onTap: () => _startEditing('callout-title-${block.id}'),
                    readOnly: widget.renderContext.readOnly || block.isLocked,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Título opcional',
                      isDense: true,
                    ),
                  ),
                  TextField(
                    controller: _textController,
                    focusNode: _textFocus,
                    onTap: () => _startEditing('callout-text-${block.id}'),
                    readOnly: widget.renderContext.readOnly || block.isLocked,
                    minLines: 1,
                    maxLines: null,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Contenido',
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  FocusNode _createFocusNode(String targetId) {
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
  }

  void _startEditing(String targetId) {
    widget.renderContext.interaction.dispatch(
      StartEditingIntent(blockId: block.id, focusTargetId: targetId),
    );
  }

  (Color, Color) _colors(BuildContext context, BlockCalloutType type) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = switch (type) {
      BlockCalloutType.info => Colors.blue,
      BlockCalloutType.tip => Colors.purple,
      BlockCalloutType.warning => Colors.orange,
      BlockCalloutType.success => Colors.green,
      BlockCalloutType.error => Colors.red,
      BlockCalloutType.note => Colors.blueGrey,
    };
    return (
      base.withValues(alpha: dark ? 0.22 : 0.12),
      dark ? base.shade200 : base.shade700,
    );
  }

  IconData _icon(BlockCalloutType type) => switch (type) {
    BlockCalloutType.info => Icons.info_outline,
    BlockCalloutType.tip => Icons.lightbulb_outline,
    BlockCalloutType.warning => Icons.warning_amber,
    BlockCalloutType.success => Icons.check_circle_outline,
    BlockCalloutType.error => Icons.error_outline,
    BlockCalloutType.note => Icons.sticky_note_2_outlined,
  };

  String calloutTypeLabel(BlockCalloutType type) => switch (type) {
    BlockCalloutType.info => 'Información',
    BlockCalloutType.tip => 'Consejo',
    BlockCalloutType.warning => 'Advertencia',
    BlockCalloutType.success => 'Éxito',
    BlockCalloutType.error => 'Error',
    BlockCalloutType.note => 'Nota',
  };

  @override
  void dispose() {
    widget.renderContext.interaction.focusCoordinator
      ..unregisterTarget('callout-title-${block.id}')
      ..unregisterTarget('callout-text-${block.id}');
    _titleController
      ..removeListener(_changed)
      ..dispose();
    _textController
      ..removeListener(_changed)
      ..dispose();
    _titleFocus.dispose();
    _textFocus.dispose();
    super.dispose();
  }
}

class UnknownBlockWidget extends StatelessWidget {
  const UnknownBlockWidget({required this.renderContext, super.key});
  final BlockRenderContext renderContext;

  @override
  Widget build(BuildContext context) {
    final block = renderContext.block as UnknownBlock;
    return BlockFrame(
      block: block,
      geometryRegistry: renderContext.geometryRegistry,
      workspaceId: renderContext.session.workspace.id,
      pageId: renderContext.session.page.id,
      visualLayer: renderContext.visualLayer,
      child: ListTile(
        leading: const Icon(Icons.extension_off_outlined),
        title: Text('Bloque no compatible: ${block.originalType}'),
        subtitle: const Text('Los datos originales se conservaron.'),
      ),
    );
  }
}
