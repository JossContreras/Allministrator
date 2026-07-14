import 'package:allministrator/features/editor/presentation/document_renderer.dart';
import 'package:allministrator/features/editor/presentation/smart_formatting_toolbar.dart';
import 'package:allministrator/domain/value_objects/structured_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'FlutterDocumentRenderer renders paragraphs and spans without editing',
    () {
      const document = StructuredDocument(
        nodes: [
          ParagraphNode(
            id: 'p',
            text: 'hola',
            spans: [
              TextSpanMark(start: 0, end: 4, attributes: {'bold': true}),
            ],
          ),
        ],
      );
      final span = FlutterDocumentRenderer().render(
        document,
        const RenderConfiguration(style: TextStyle(fontSize: 16)),
      );
      expect(span, isA<TextSpan>());
      expect((span as TextSpan).children, isNotEmpty);
      expect(document.plainText, 'hola');
    },
  );

  test('ToolbarController exposes context and available actions', () {
    final controller = ToolbarController();
    controller.update(const ToolbarContext(hasSelection: true, bold: true));
    expect(controller.state.isVisible, isTrue);
    expect(controller.state.activeActions, contains('bold'));
    expect(controller.state.availableActions, contains('alignment'));
    controller.hide();
    expect(controller.state.isVisible, isFalse);
  });
}
