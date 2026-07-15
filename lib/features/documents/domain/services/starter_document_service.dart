import 'package:allministrator/domain/entities/canvas_layout.dart';
import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';

class StarterDocumentService {
  const StarterDocumentService(this.repository);

  final DocumentRepository repository;

  Future<Document> create({
    String title = '',
    String? body,
    List<BaseBlock>? blocks,
    String? categoryId,
    WorkspaceLayoutType layoutType = WorkspaceLayoutType.document,
  }) async {
    final draft = await repository.createDocument();
    var content = body == null ? draft.content : draft.content.withText(body);
    if (blocks != null) {
      final workspace = content.workspace;
      final firstPage = workspace.pages.first;
      content = content.withWorkspace(
        workspace.copyWith(
          pages: [
            firstPage.copyWith(blocks: List<BaseBlock>.unmodifiable(blocks)),
            ...workspace.pages.skip(1),
          ],
        ),
      );
    }
    if (layoutType == WorkspaceLayoutType.canvas) {
      final workspace = content.workspace;
      final primaryPage = workspace.pages.first;
      // Keep content explicitly supplied by the caller. Only remove the
      // placeholder block that belongs to a completely blank new document.
      final canvasBlocks =
          blocks ??
          (body == null
              ? const <BaseBlock>[]
              : List<BaseBlock>.unmodifiable(primaryPage.blocks));
      final pages = [
        for (final page in workspace.pages)
          if (page == primaryPage)
            page.copyWith(
              layoutType: WorkspaceLayoutType.canvas,
              // A canvas starts as an actual blank surface. It should not
              // inherit the document editor's placeholder text block.
              blocks: canvasBlocks,
              canvasLayout: CanvasLayoutState.forBlocks(canvasBlocks),
            )
          else
            page,
      ];
      content = content.withWorkspace(
        workspace.copyWith(pages: pages, workspaceType: WorkspaceType.canvas),
      );
    }
    if (title.isEmpty &&
        body == null &&
        blocks == null &&
        categoryId == null &&
        layoutType == WorkspaceLayoutType.document) {
      return draft;
    }
    return repository.updateDocument(
      draft.copyWith(title: title, content: content, categoryId: categoryId),
    );
  }
}
