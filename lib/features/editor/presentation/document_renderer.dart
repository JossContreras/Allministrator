import 'dart:io';
import 'package:flutter/material.dart';
import 'package:allministrator/domain/value_objects/structured_document.dart';

class RenderConfiguration {
  const RenderConfiguration({
    required this.style,
    this.withComposing = true,
    this.attachmentPath,
    this.selectedNodeId,
  });
  final TextStyle style;
  final bool withComposing;
  final String? Function(String attachmentId)? attachmentPath;
  final String? selectedNodeId;
}

abstract interface class DocumentRenderer<TOutput> {
  TOutput render(
    StructuredDocument document,
    RenderConfiguration configuration,
  );
}

final class FlutterDocumentRenderer implements DocumentRenderer<InlineSpan> {
  @override
  InlineSpan render(
    StructuredDocument document,
    RenderConfiguration configuration,
  ) {
    final children = <InlineSpan>[];
    for (var index = 0; index < document.nodes.length; index++) {
      final node = document.nodes[index];
      if (node is ParagraphNode) {
        children.add(_paragraph(node, configuration.style));
      } else if (node is ImageNode) {
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _imageWidget(node, configuration),
          ),
        );
      } else if (node is DividerNode) {
        children.add(
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(width: double.infinity, child: Divider()),
          ),
        );
      } else if (node is ChecklistNode) {
        children.add(
          TextSpan(
            text: node.items
                .map((i) => '${i.isChecked ? '☑' : '☐'} ${i.text}')
                .join('\n'),
            style: configuration.style,
          ),
        );
      } else if (node is QuoteNode) {
        children.add(
          TextSpan(
            text:
                '“${node.text}”${node.citation == null ? '' : ' — ${node.citation}'}',
            style: configuration.style.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (node is CalloutNode) {
        children.add(
          TextSpan(
            text: '${node.title == null ? '' : '${node.title}: '}${node.text}',
            style: configuration.style,
          ),
        );
      } else if (node is CodeBlockNode) {
        children.add(
          TextSpan(
            text: node.code,
            style: configuration.style.copyWith(fontFamily: 'monospace'),
          ),
        );
      } else if (node is TableNode) {
        children.add(
          TextSpan(
            text: node.rows
                .map((r) => r.cells.map((c) => c.content.text).join(' | '))
                .join('\n'),
            style: configuration.style,
          ),
        );
      } else if (node is AttachmentNode) {
        children.add(
          TextSpan(
            text: 'Adjunto: ${node.displayName}',
            style: configuration.style,
          ),
        );
      }
      if (index < document.nodes.length - 1) {
        children.add(TextSpan(text: '\n', style: configuration.style));
      }
    }
    return TextSpan(style: configuration.style, children: children);
  }

  TextSpan _paragraph(ParagraphNode node, TextStyle base) {
    final boundaries = <int>{0, node.text.length};
    for (final span in node.spans) {
      boundaries
        ..add(span.start)
        ..add(span.end);
    }
    final sorted = boundaries.toList()..sort();
    final children = <InlineSpan>[];
    for (var index = 0; index < sorted.length - 1; index++) {
      final start = sorted[index], end = sorted[index + 1];
      final attributes = <String, Object?>{};
      for (final span in node.spans.where(
        (span) => span.start <= start && span.end >= end,
      )) {
        attributes.addAll(span.attributes);
      }
      children.add(
        TextSpan(
          text: node.text.substring(start, end),
          style: _style(base, attributes),
        ),
      );
    }
    return TextSpan(children: children);
  }

  TextStyle _style(TextStyle base, Map<String, Object?> attributes) =>
      base.copyWith(
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
      );

  Widget _imageWidget(ImageNode node, RenderConfiguration configuration) {
    final path = configuration.attachmentPath?.call(node.attachmentId);
    if (path == null || !File(path).existsSync()) {
      return const SizedBox(
        width: 280,
        height: 120,
        child: ColoredBox(
          color: Colors.black12,
          child: Center(child: Text('Imagen no disponible')),
        ),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      cacheWidth: 1200,
      semanticLabel: node.altText,
    );
  }
}

class FlutterDocumentWidgetRenderer implements DocumentRenderer<Widget> {
  @override
  Widget render(
    StructuredDocument document,
    RenderConfiguration configuration,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final node in document.nodes)
        if (node is ParagraphNode)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(node.text, style: configuration.style),
          )
        else if (node is ImageNode)
          _image(node, configuration)
        else if (node is DividerNode)
          _divider(node, configuration)
        else if (node is ChecklistNode)
          _checklist(node, configuration)
        else if (node is QuoteNode)
          _quote(node, configuration)
        else if (node is CalloutNode)
          _callout(node, configuration)
        else if (node is CodeBlockNode)
          _code(node, configuration)
        else if (node is TableNode)
          _table(node, configuration)
        else if (node is AttachmentNode)
          _attachment(node, configuration)
        else
          const SizedBox.shrink(),
    ],
  );

  Widget _image(ImageNode node, RenderConfiguration configuration) {
    final path = configuration.attachmentPath?.call(node.attachmentId);
    final selected = configuration.selectedNodeId == node.id;
    final alignment = switch (node.alignment) {
      NodeAlignment.left => Alignment.centerLeft,
      NodeAlignment.right => Alignment.centerRight,
      _ => Alignment.center,
    };
    final child = path == null || !File(path).existsSync()
        ? _missingImage(node)
        : Image.file(
            File(path),
            fit: BoxFit.contain,
            cacheWidth: 1200,
            semanticLabel: node.altText,
          );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: selected
          ? BoxDecoration(
              border: Border.all(color: Colors.blueAccent, width: 2),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 800, maxHeight: 500),
            child: child,
          ),
          if (node.caption?.isNotEmpty == true)
            Text(
              node.caption!,
              style: configuration.style.copyWith(fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  Widget _missingImage(ImageNode node) => Container(
    height: 140,
    color: Colors.black12,
    alignment: Alignment.center,
    child: const Text('Imagen no disponible'),
  );
  Widget _divider(DividerNode node, RenderConfiguration configuration) => Align(
    alignment: switch (node.alignment) {
      NodeAlignment.left => Alignment.centerLeft,
      NodeAlignment.right => Alignment.centerRight,
      _ => Alignment.center,
    },
    child: FractionallySizedBox(
      widthFactor: node.widthFactor.clamp(0.1, 1),
      child: Divider(thickness: node.thickness),
    ),
  );

  Widget _checklist(ChecklistNode node, RenderConfiguration configuration) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: node.items
            .map(
              (item) => Padding(
                padding: EdgeInsets.only(
                  left: item.indentLevel * 20.0,
                  top: 2,
                  bottom: 2,
                ),
                child: Row(
                  children: [
                    Icon(
                      item.isChecked
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.text,
                        style: configuration.style.copyWith(
                          decoration: item.isChecked
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      );
  Widget _quote(QuoteNode node, RenderConfiguration configuration) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.only(left: 14),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: Colors.blueGrey, width: 3)),
    ),
    child: Text(
      '${node.text}${node.citation == null ? '' : '\n— ${node.citation}'}',
      style: configuration.style.copyWith(fontStyle: FontStyle.italic),
    ),
  );
  Widget _callout(CalloutNode node, RenderConfiguration configuration) => Card(
    child: ListTile(
      leading: Icon(_calloutIcon(node.calloutType)),
      title: node.title == null ? null : Text(node.title!),
      subtitle: Text(node.text),
    ),
  );
  IconData _calloutIcon(CalloutType type) => switch (type) {
    CalloutType.tip => Icons.lightbulb_outline,
    CalloutType.warning => Icons.warning_amber,
    CalloutType.success => Icons.check_circle_outline,
    CalloutType.error => Icons.error_outline,
    CalloutType.note => Icons.sticky_note_2_outlined,
    _ => Icons.info_outline,
  };
  Widget _code(CodeBlockNode node, RenderConfiguration configuration) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        color: Colors.black12,
        child: SingleChildScrollView(
          scrollDirection: node.wrapLines ? Axis.vertical : Axis.horizontal,
          child: Text(
            node.code.isEmpty ? 'Código vacío' : node.code,
            style: configuration.style.copyWith(fontFamily: 'monospace'),
          ),
        ),
      );

  Widget _table(TableNode node, RenderConfiguration configuration) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          border: TableBorder.all(color: Colors.black26),
          children: [
            for (var i = 0; i < node.rows.length; i++)
              TableRow(
                decoration: node.hasHeaderRow && i == 0
                    ? const BoxDecoration(color: Colors.black12)
                    : null,
                children: [
                  for (final cell in node.rows[i].cells)
                    Padding(
                      padding: EdgeInsets.all(node.style.cellPadding),
                      child: Text(
                        cell.content.text,
                        style: configuration.style,
                      ),
                    ),
                ],
              ),
          ],
        ),
      );

  Widget _attachment(AttachmentNode node, RenderConfiguration configuration) =>
      Card(
        child: ListTile(
          leading: const Icon(Icons.attach_file),
          title: Text(node.displayName),
          subtitle: Text(node.description ?? node.presentation.name),
        ),
      );
}
