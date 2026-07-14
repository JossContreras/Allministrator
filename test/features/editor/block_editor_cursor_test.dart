import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/editing/workspace_editor_session.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_render_context.dart';
import 'package:allministrator/features/editor/presentation/blocks/text_block_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TextBlock keeps controller, focus and cursor across rebuilds', (
    tester,
  ) async {
    final session = _session();
    final interaction = WorkspaceInteractionController()
      ..dispatch(const StartEditingIntent(blockId: 'text'));

    await tester.pumpWidget(_harness(session, interaction));
    await tester.pump();
    final field = find.byType(TextField);
    expect(field, findsOneWidget);

    await tester.tap(field);
    await tester.pump();
    expect(interaction.context.interactionMode, InteractionMode.textEditing);
    expect(interaction.context.focusedBlock, 'text');
    await tester.enterText(field, 'Árbol 😊\nsegunda línea');
    await tester.pump();

    final firstEditable = tester.widget<EditableText>(
      find.byType(EditableText),
    );
    final firstController = firstEditable.controller;
    final expectedOffset = 'Árbol 😊\nsegunda línea'.length;
    expect(firstController.selection.baseOffset, expectedOffset);
    expect(
      (session.blocks.single as TextBlock).plainText,
      'Árbol 😊\nsegunda línea',
    );

    session.presentationRevision.value++;
    await tester.pump();

    final rebuilt = tester.widget<EditableText>(find.byType(EditableText));
    expect(identical(rebuilt.controller, firstController), isTrue);
    expect(rebuilt.focusNode, same(firstEditable.focusNode));
    expect(rebuilt.controller.selection.baseOffset, expectedOffset);
  });

  testWidgets(
    'moving and replacing a selection uses UTF-16 offsets correctly',
    (tester) async {
      final session = _session(text: 'a😊b á');
      final interaction = WorkspaceInteractionController()
        ..dispatch(const StartEditingIntent(blockId: 'text'));
      await tester.pumpWidget(_harness(session, interaction));
      await tester.pump();

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      editable.controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 3,
      );
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'aXb á',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();

      expect((session.blocks.single as TextBlock).plainText, 'aXb á');
      expect(editable.controller.selection.baseOffset, 2);
    },
  );
}

Widget _harness(
  WorkspaceEditorSession session,
  WorkspaceInteractionController interaction,
) {
  final geometryRegistry = BlockGeometryRegistry();
  return MaterialApp(
    home: Scaffold(
      body: ValueListenableBuilder<int>(
        valueListenable: session.presentationRevision,
        builder: (context, _, _) {
          final block = session.blocks.single as TextBlock;
          return TextBlockWidget(
            key: ValueKey(block.id),
            renderContext: BlockRenderContext(
              block: block,
              session: session,
              interaction: interaction,
              geometryRegistry: geometryRegistry,
              visualLayer: 0,
              onChanged:
                  (
                    block, {
                    required kind,
                    mergeable = false,
                    refreshPresentation = false,
                  }) => session.updateBlock(
                    block,
                    kind: kind,
                    mergeable: mergeable,
                    refreshPresentation: refreshPresentation,
                  ),
              resolveAttachmentPath: (_) => null,
              onReplaceImage: (_) async {},
              onReplaceAttachment: (_) async {},
              onOpenAttachment: (_) async {},
            ),
          );
        },
      ),
    ),
  );
}

WorkspaceEditorSession _session({String text = ''}) {
  final now = DateTime.utc(2026);
  return WorkspaceEditorSession(
    workspace: Workspace(
      id: 'workspace',
      title: 'Documento',
      description: null,
      workspaceType: WorkspaceType.document,
      pages: [
        WorkspacePage(
          id: 'page',
          workspaceId: 'workspace',
          title: null,
          layoutType: WorkspaceLayoutType.document,
          blocks: [
            TextBlock(
              id: 'text',
              orderKey: 0,
              paragraphs: [BlockParagraph(id: 'paragraph', text: text)],
            ),
          ],
          createdAt: now,
          updatedAt: now,
          deletedAt: null,
          version: 1,
          metadata: const {},
        ),
      ],
      themeId: null,
      templateId: null,
      isFavorite: false,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      version: 1,
      metadata: const {},
    ),
    onChanged: (_) {},
  );
}
