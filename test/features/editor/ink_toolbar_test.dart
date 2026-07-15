import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/features/editor/presentation/ink/ink_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'ink toolbar exposes touch tools and accessible selection actions',
    (tester) async {
      WorkspaceTool? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InkToolbar(
              activeTool: WorkspaceTool.pen,
              style: InkBrushStyle.pen(),
              hasSelection: true,
              canUndo: true,
              canRedo: false,
              onTool: (tool) => selected = tool,
              onColor: (_) {},
              onWidth: (_) {},
              onOpacity: (_) {},
              onUndo: () {},
              onRedo: () {},
              onDuplicate: () {},
              onDelete: () {},
              onMove: (_) {},
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('ink-toolbar')), findsOneWidget);
      expect(find.byTooltip('Pluma'), findsOneWidget);
      expect(find.byTooltip('Resaltador'), findsOneWidget);
      expect(find.byTooltip('Borrador de tinta'), findsOneWidget);
      expect(find.byTooltip('Lazo de tinta'), findsOneWidget);
      expect(find.byTooltip('Duplicar tinta seleccionada'), findsOneWidget);
      expect(find.byTooltip('Eliminar tinta seleccionada'), findsOneWidget);

      await tester.tap(find.byTooltip('Resaltador'));
      expect(selected, WorkspaceTool.highlighter);
    },
  );
}
