import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/domain/value_objects/structured_document.dart';

class DocumentNodeToWorkspaceMigrator {
  const DocumentNodeToWorkspaceMigrator();

  Workspace migrate({
    required StructuredDocument document,
    required Uuid workspaceId,
    String title = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    JsonMap metadata = const {},
  }) {
    final created =
        createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final updated = updatedAt ?? created;
    final blocks = <BaseBlock>[];
    final pendingParagraphs = <ParagraphNode>[];

    void flushParagraphs() {
      if (pendingParagraphs.isEmpty) return;
      blocks.add(
        TextBlock(
          id: pendingParagraphs.first.id,
          orderKey: blocks.length.toDouble(),
          paragraphs: pendingParagraphs
              .map(BlockParagraph.fromLegacy)
              .toList(growable: false),
          createdAt: created,
          updatedAt: updated,
        ),
      );
      pendingParagraphs.clear();
    }

    for (final node in document.nodes) {
      if (node is ParagraphNode) {
        pendingParagraphs.add(node);
        continue;
      }
      flushParagraphs();
      blocks.add(
        _migrateNode(
          node,
          orderKey: blocks.length.toDouble(),
          createdAt: created,
          updatedAt: updated,
        ),
      );
    }
    flushParagraphs();

    if (blocks.isEmpty) {
      blocks.add(
        TextBlock(
          id: generateUuid(),
          orderKey: 0,
          paragraphs: [BlockParagraph(id: generateUuid(), text: '')],
          createdAt: created,
          updatedAt: updated,
        ),
      );
    }

    final pageId = 'page-$workspaceId';
    return Workspace(
      id: workspaceId,
      title: title,
      description: null,
      workspaceType: WorkspaceType.document,
      pages: [
        WorkspacePage(
          id: pageId,
          workspaceId: workspaceId,
          title: null,
          layoutType: WorkspaceLayoutType.document,
          blocks: blocks,
          createdAt: created,
          updatedAt: updated,
          deletedAt: null,
          version: 1,
          metadata: const {},
        ),
      ],
      themeId: null,
      templateId: null,
      isFavorite: false,
      isArchived: false,
      createdAt: created,
      updatedAt: updated,
      deletedAt: null,
      version: 1,
      metadata: {
        ...metadata,
        'migratedFrom': 'StructuredDocument',
        'sourceSchemaVersion': 2,
      },
    );
  }

  BaseBlock _migrateNode(
    DocumentNode node, {
    required double orderKey,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    if (node is ImageNode) {
      return ImageBlock(
        id: node.id,
        orderKey: orderKey,
        attachmentId: node.attachmentId,
        altText: node.altText,
        caption: node.caption,
        alignment: _alignment(node.alignment),
        geometry: BlockGeometry(
          width: node.displayWidth,
          height: node.aspectRatio == null || node.displayWidth == null
              ? null
              : node.displayWidth! / node.aspectRatio!,
        ),
        createdAt: node.createdAt ?? createdAt,
        updatedAt: updatedAt,
        metadata: node.metadata ?? const {},
      );
    }
    if (node is DividerNode) {
      return DividerBlock(
        id: node.id,
        orderKey: orderKey,
        style: node.style == 'dashed'
            ? DividerStyle.dashed
            : DividerStyle.solid,
        thickness: node.thickness,
        createdAt: createdAt,
        updatedAt: updatedAt,
        metadata: node.metadata ?? const {},
      );
    }
    if (node is ChecklistNode) {
      return ChecklistBlock(
        id: node.id,
        orderKey: orderKey,
        items: node.items
            .map(
              (item) => BlockChecklistItem(
                id: item.id,
                text: item.text,
                isChecked: item.isChecked,
                metadata: item.metadata ?? const {},
              ),
            )
            .toList(growable: false),
        createdAt: createdAt,
        updatedAt: updatedAt,
        metadata: node.metadata ?? const {},
      );
    }
    if (node is CodeBlockNode) {
      return CodeBlock(
        id: node.id,
        orderKey: orderKey,
        code: node.code,
        languageId: node.languageId ?? 'plainText',
        showLineNumbers: node.showLineNumbers,
        wrapLines: node.wrapLines,
        caption: node.caption,
        createdAt: createdAt,
        updatedAt: updatedAt,
        metadata: node.metadata ?? const {},
      );
    }
    if (node is TableNode) {
      return TableBlock(
        id: node.id,
        orderKey: orderKey,
        rows: node.rows
            .map(
              (row) => BlockTableRow(
                id: row.id,
                cells: row.cells
                    .map(
                      (cell) => BlockTableCell(
                        id: cell.id,
                        text: cell.content.text,
                        spans: cell.content.spans,
                        metadata: cell.metadata ?? const {},
                      ),
                    )
                    .toList(growable: false),
              ),
            )
            .toList(growable: false),
        columnIds: node.columnDefinitions
            .map((column) => column.id)
            .toList(growable: false),
        hasHeaderRow: node.hasHeaderRow,
        createdAt: createdAt,
        updatedAt: updatedAt,
        metadata: {...?node.metadata, 'legacyTableStyle': node.style.toJson()},
      );
    }
    if (node is AttachmentNode) {
      final extension = node.displayName.contains('.')
          ? node.displayName.split('.').last.toLowerCase()
          : '';
      return AttachmentBlock(
        id: node.id,
        orderKey: orderKey,
        attachmentId: node.attachmentId,
        displayName: node.displayName,
        extension: extension,
        description: node.description,
        createdAt: createdAt,
        updatedAt: updatedAt,
        metadata: node.metadata ?? const {},
      );
    }
    if (node is QuoteNode) {
      return QuoteBlock(
        id: node.id,
        orderKey: orderKey,
        text: node.text,
        spans: node.spans,
        citation: node.citation,
        createdAt: createdAt,
        updatedAt: updatedAt,
        metadata: node.metadata ?? const {},
      );
    }
    if (node is CalloutNode) {
      return CalloutBlock(
        id: node.id,
        orderKey: orderKey,
        title: node.title,
        text: node.text,
        spans: node.spans,
        calloutType: BlockCalloutType.values.firstWhere(
          (value) => value.name == node.calloutType.name,
          orElse: () => BlockCalloutType.info,
        ),
        createdAt: createdAt,
        updatedAt: updatedAt,
        metadata: node.metadata ?? const {},
      );
    }
    return UnknownBlock(
      id: node.id,
      orderKey: orderKey,
      originalType: node.type,
      raw: node.toJson(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      metadata: node.metadata ?? const {},
    );
  }

  BlockAlignment _alignment(NodeAlignment alignment) => switch (alignment) {
    NodeAlignment.left => BlockAlignment.left,
    NodeAlignment.center => BlockAlignment.center,
    NodeAlignment.right => BlockAlignment.right,
  };
}

class WorkspaceLegacyAdapter {
  const WorkspaceLegacyAdapter();

  StructuredDocument toStructuredDocument(Workspace workspace) {
    final nodes = <DocumentNode>[];
    for (final block in workspace.primaryPage.orderedBlocks) {
      if (block is TextBlock) {
        nodes.addAll(block.paragraphs.map((paragraph) => paragraph.toLegacy()));
      } else if (block is ImageBlock) {
        nodes.add(
          ImageNode(
            id: block.id,
            attachmentId: block.attachmentId,
            altText: block.altText,
            caption: block.caption,
            alignment: switch (block.alignment) {
              BlockAlignment.left => NodeAlignment.left,
              BlockAlignment.center => NodeAlignment.center,
              BlockAlignment.right => NodeAlignment.right,
            },
            displayWidth: block.geometry.width,
            createdAt: block.createdAt,
            metadata: block.metadata,
          ),
        );
      } else if (block is DividerBlock) {
        nodes.add(
          DividerNode(
            id: block.id,
            style: block.style.name,
            thickness: block.thickness,
            metadata: block.metadata,
          ),
        );
      } else if (block is ChecklistBlock) {
        nodes.add(
          ChecklistNode(
            id: block.id,
            items: block.items
                .map(
                  (item) => ChecklistItem(
                    id: item.id,
                    text: item.text,
                    isChecked: item.isChecked,
                    metadata: item.metadata,
                  ),
                )
                .toList(),
            metadata: block.metadata,
          ),
        );
      } else if (block is CodeBlock) {
        nodes.add(
          CodeBlockNode(
            id: block.id,
            code: block.code,
            languageId: block.languageId,
            showLineNumbers: block.showLineNumbers,
            wrapLines: block.wrapLines,
            caption: block.caption,
            metadata: block.metadata,
          ),
        );
      } else if (block is TableBlock) {
        nodes.add(
          TableNode(
            id: block.id,
            rows: block.rows
                .map(
                  (row) => TableRowData(
                    id: row.id,
                    cells: row.cells
                        .map(
                          (cell) => TableCellData(
                            id: cell.id,
                            content: StructuredCellContent(
                              text: cell.text,
                              spans: cell.spans,
                            ),
                            metadata: cell.metadata,
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
            columnDefinitions: block.columnIds
                .map((id) => TableColumnDefinition(id: id))
                .toList(),
            hasHeaderRow: block.hasHeaderRow,
            metadata: block.metadata,
          ),
        );
      } else if (block is AttachmentBlock) {
        nodes.add(
          AttachmentNode(
            id: block.id,
            attachmentId: block.attachmentId,
            displayName: block.displayName,
            description: block.description,
            metadata: block.metadata,
          ),
        );
      } else if (block is QuoteBlock) {
        nodes.add(
          QuoteNode(
            id: block.id,
            text: block.text,
            spans: block.spans,
            citation: block.citation,
            metadata: block.metadata,
          ),
        );
      } else if (block is CalloutBlock) {
        nodes.add(
          CalloutNode(
            id: block.id,
            title: block.title,
            text: block.text,
            spans: block.spans,
            calloutType: CalloutType.values.firstWhere(
              (value) => value.name == block.calloutType.name,
              orElse: () => CalloutType.info,
            ),
            metadata: block.metadata,
          ),
        );
      } else if (block is UnknownBlock) {
        nodes.add(DocumentNode.fromJson(block.raw));
      }
    }
    if (nodes.isEmpty) {
      nodes.add(ParagraphNode(id: generateUuid(), text: ''));
    }
    return StructuredDocument(nodes: nodes).normalized();
  }
}
