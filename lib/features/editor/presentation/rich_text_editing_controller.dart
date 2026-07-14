import 'package:flutter/material.dart';
import 'package:allministrator/domain/value_objects/structured_document.dart';
import 'document_renderer.dart';

class RichTextEditingController extends TextEditingController {
  RichTextEditingController({super.text, StructuredDocument? document})
    : document = document ?? StructuredDocument.empty();
  StructuredDocument document;
  final Map<String, String> attachmentPaths = {};
  final DocumentRenderer<InlineSpan> renderer = FlutterDocumentRenderer();
  void setDocument(StructuredDocument value) => document = value;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final rendered = renderer.render(
      document,
      RenderConfiguration(
        style: style ?? DefaultTextStyle.of(context).style,
        withComposing: withComposing,
        attachmentPath: (id) => attachmentPaths[id],
      ),
    );
    return rendered as TextSpan;
  }
}
