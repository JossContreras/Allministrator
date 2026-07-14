import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/editing/code_language_catalog.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_frame.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_render_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CodeBlockWidget extends StatefulWidget {
  const CodeBlockWidget({required this.renderContext, super.key});

  final BlockRenderContext renderContext;

  @override
  State<CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<CodeBlockWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late CodeBlock _current;
  bool _external = false;

  String get _focusTargetId => 'code-${block.id}';

  CodeBlock get block => _current;

  @override
  void initState() {
    super.initState();
    _current = widget.renderContext.block as CodeBlock;
    _controller = TextEditingController(text: block.code)
      ..addListener(_handleChanged);
    _focusNode = FocusNode(debugLabel: 'code-block-${block.id}')
      ..addListener(_handleFocusChanged);
    widget.renderContext.interaction.focusCoordinator.registerTarget(
      targetId: _focusTargetId,
      blockId: block.id,
      requestFocus: _focusNode.requestFocus,
      releaseFocus: _focusNode.unfocus,
    );
  }

  @override
  void didUpdateWidget(covariant CodeBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.renderContext.block as CodeBlock;
    if (incoming.version != _current.version) _current = incoming;
    if (_controller.text != block.code) {
      _external = true;
      final selection = _controller.selection;
      _controller.value = TextEditingValue(
        text: block.code,
        selection: TextSelection.collapsed(
          offset: selection.extentOffset.clamp(0, block.code.length),
        ),
      );
      _external = false;
    }
  }

  void _handleChanged() {
    if (_external || _controller.text == block.code) return;
    _current = block.copyWith(code: _controller.text);
    widget.renderContext.onChanged(_current, kind: 'editCode', mergeable: true);
  }

  void _handleFocusChanged() {
    widget.renderContext.interaction.focusCoordinator.reportFocusChange(
      _focusTargetId,
      hasFocus: _focusNode.hasFocus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF161B22)
        : const Color(0xFFF3F5F7);
    return BlockFrame(
      block: block,
      geometryRegistry: widget.renderContext.geometryRegistry,
      workspaceId: widget.renderContext.session.workspace.id,
      pageId: widget.renderContext.session.page.id,
      visualLayer: widget.renderContext.visualLayer,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  DropdownButton<String>(
                    value: CodeLanguageCatalog.supports(block.languageId)
                        ? block.languageId
                        : 'plainText',
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final language in CodeLanguageCatalog.ids)
                        DropdownMenuItem(
                          value: language,
                          child: Text(_languageLabel(language)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        widget.renderContext.onChanged(
                          block.copyWith(languageId: value),
                          kind: 'updateCodeLanguage',
                          refreshPresentation: true,
                        );
                      }
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: block.showLineNumbers
                        ? 'Ocultar números de línea'
                        : 'Mostrar números de línea',
                    onPressed: () => widget.renderContext.onChanged(
                      block.copyWith(showLineNumbers: !block.showLineNumbers),
                      kind: 'updateCodeOptions',
                      refreshPresentation: true,
                    ),
                    icon: const Icon(Icons.format_list_numbered),
                  ),
                  IconButton(
                    tooltip: block.wrapLines
                        ? 'Desactivar ajuste'
                        : 'Ajustar líneas',
                    onPressed: () => widget.renderContext.onChanged(
                      block.copyWith(wrapLines: !block.wrapLines),
                      kind: 'updateCodeOptions',
                      refreshPresentation: true,
                    ),
                    icon: const Icon(Icons.wrap_text),
                  ),
                  IconButton(
                    tooltip: 'Copiar código',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _controller.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: block.wrapLines
                    ? Axis.vertical
                    : Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (block.showLineNumbers)
                      Container(
                        width: 48,
                        padding: const EdgeInsets.fromLTRB(8, 10, 6, 10),
                        color: Colors.black.withValues(alpha: 0.05),
                        child: Text(
                          List.generate(
                            _controller.text.split('\n').length,
                            (index) => '${index + 1}',
                          ).join('\n'),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: block.wrapLines
                          ? constraints.maxWidth -
                                (block.showLineNumbers ? 48 : 0)
                          : 720,
                      child: widget.renderContext.region(
                        id: 'code-text',
                        target: TextRegionHitTarget(block.id, fieldId: 'code'),
                        priority: 20,
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          readOnly:
                              widget.renderContext.readOnly || block.isLocked,
                          minLines: 3,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          style: const TextStyle(fontFamily: 'monospace'),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Escribe código…',
                            contentPadding: EdgeInsets.all(10),
                          ),
                          onTap: () =>
                              widget.renderContext.interaction.dispatch(
                                StartEditingIntent(
                                  blockId: block.id,
                                  focusTargetId: _focusTargetId,
                                ),
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (block.caption?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  block.caption!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.renderContext.interaction.focusCoordinator.unregisterTarget(
      _focusTargetId,
    );
    _controller
      ..removeListener(_handleChanged)
      ..dispose();
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  String _languageLabel(String id) => switch (id) {
    'plainText' => 'Texto plano',
    'javascript' => 'JavaScript',
    'typescript' => 'TypeScript',
    'csharp' => 'C#',
    'cpp' => 'C++',
    _ => id[0].toUpperCase() + id.substring(1),
  };
}
