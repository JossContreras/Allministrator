import 'package:flutter/material.dart';
import 'package:allministrator/domain/value_objects/structured_document.dart';

class RenderConfiguration {
  const RenderConfiguration({required this.style, this.withComposing = true});
  final TextStyle style;
  final bool withComposing;
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
}
