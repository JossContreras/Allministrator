import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/domain/migrations/document_node_to_workspace_migrator.dart';
import 'structured_document.dart';

/// JSON versionado del cuerpo editable. Mantiene compatibilidad con payloads
/// antiguos mientras expone un documento estructurado al editor.
class DocumentContent {
  const DocumentContent({
    required this.schemaVersion,
    required this.data,
    this.wasMigrated = false,
    this.migrationError,
  });

  static const currentSchemaVersion = 5;

  final int schemaVersion;
  final Map<String, Object?> data;
  final bool wasMigrated;
  final String? migrationError;

  factory DocumentContent.forNewWorkspace({
    required String workspaceId,
    String title = '',
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now().toUtc();
    final workspace = Workspace(
      id: workspaceId,
      title: title,
      description: null,
      workspaceType: WorkspaceType.document,
      pages: [
        WorkspacePage(
          id: generateUuid(),
          workspaceId: workspaceId,
          title: null,
          layoutType: WorkspaceLayoutType.document,
          blocks: [
            TextBlock(
              id: generateUuid(),
              orderKey: 0,
              paragraphs: [BlockParagraph(id: generateUuid(), text: '')],
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          ],
          createdAt: timestamp,
          updatedAt: timestamp,
          deletedAt: null,
          version: 1,
          metadata: const {},
        ),
      ],
      themeId: null,
      templateId: null,
      isFavorite: false,
      isArchived: false,
      createdAt: timestamp,
      updatedAt: timestamp,
      deletedAt: null,
      version: 1,
      metadata: const {},
    );
    return DocumentContent.fromWorkspace(workspace);
  }

  factory DocumentContent.fromWorkspace(Workspace workspace) => DocumentContent(
    schemaVersion: currentSchemaVersion,
    data: {'workspace': workspace.toJson()},
  );

  factory DocumentContent.fromJson(Map<String, Object?> json) {
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    if (json['workspace'] is Map) {
      return DocumentContent(
        schemaVersion: currentSchemaVersion,
        data: {
          'workspace': Map<String, Object?>.from(json['workspace'] as Map),
          if (json['migration'] != null) 'migration': json['migration'],
        },
        wasMigrated: version < currentSchemaVersion,
      );
    }
    final raw =
        json['data'] is Map
              ? Map<String, Object?>.from(json['data'] as Map)
              : {...json}
          ..remove('schemaVersion');
    try {
      final structured = StructuredDocument.fromJson({
        'schemaVersion': version,
        ...raw,
      });
      final firstId = structured.nodes.isEmpty
          ? generateUuid()
          : structured.nodes.first.id;
      final workspace = const DocumentNodeToWorkspaceMigrator().migrate(
        document: structured,
        workspaceId: 'legacy-$firstId',
      );
      return DocumentContent(
        schemaVersion: currentSchemaVersion,
        data: {
          ...raw,
          'workspace': workspace.toJson(),
          'migration': {
            'sourceSchemaVersion': version,
            'originalPayload': json,
          },
        },
        wasMigrated: true,
      );
    } catch (error) {
      final fallback = DocumentContent.forNewWorkspace(
        workspaceId: 'migration-failed-${generateUuid()}',
      );
      return DocumentContent(
        schemaVersion: currentSchemaVersion,
        data: {
          ...fallback.data,
          'migration': {
            'sourceSchemaVersion': version,
            'originalPayload': json,
            'error': error.toString(),
          },
        },
        wasMigrated: true,
        migrationError: error.toString(),
      );
    }
  }

  Map<String, Object?> toJson() => {'schemaVersion': schemaVersion, ...data};
  Workspace get workspace => data['workspace'] is Map
      ? Workspace.fromJson(data['workspace'])
      : DocumentContent.fromJson(toJson()).workspace;
  StructuredDocument get structured =>
      const WorkspaceLegacyAdapter().toStructuredDocument(workspace);
  String get text => workspace.pages
      .expand((page) => page.orderedBlocks)
      .whereType<TextBlock>()
      .map((block) => block.plainText)
      .join('\n');

  DocumentContent withWorkspace(Workspace value) => DocumentContent(
    schemaVersion: currentSchemaVersion,
    data: {
      'workspace': value.toJson(),
      if (data['migration'] != null) 'migration': data['migration'],
    },
  );

  DocumentContent withStructured(StructuredDocument value) {
    final current = workspace;
    final migrated = const DocumentNodeToWorkspaceMigrator().migrate(
      document: value,
      workspaceId: current.id,
      title: current.title,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
      metadata: current.metadata,
    );
    return withWorkspace(
      migrated.copyWith(
        description: current.description,
        themeId: current.themeId,
        templateId: current.templateId,
        isFavorite: current.isFavorite,
        isArchived: current.isArchived,
        version: current.version + 1,
      ),
    );
  }

  DocumentContent withText(String value) =>
      withStructured(StructuredDocument.fromPlainText(value));

  DocumentContent withTextAndSoftBreaks(String value, Set<int> offsets) =>
      withStructured(
        StructuredDocument.fromPlainTextWithSoftBreaks(value, offsets),
      );
}
