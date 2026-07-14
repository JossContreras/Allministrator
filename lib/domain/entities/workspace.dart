import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/entities/syncable_entity.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';

enum WorkspaceType {
  document,
  canvas,
  whiteboard,
  mindMap,
  timeline,
  presentation,
}

class Workspace implements SyncableEntity {
  const Workspace({
    required this.id,
    required this.title,
    required this.description,
    required this.workspaceType,
    required this.pages,
    required this.themeId,
    required this.templateId,
    required this.isFavorite,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.deletedAt,
    required this.metadata,
  });

  @override
  final Uuid id;
  final String title;
  final String? description;
  final WorkspaceType workspaceType;
  final List<WorkspacePage> pages;
  final String? themeId;
  final String? templateId;
  final bool isFavorite;
  final bool isArchived;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final int version;
  @override
  final DateTime? deletedAt;
  final JsonMap metadata;

  WorkspacePage get primaryPage {
    if (pages.isEmpty) {
      throw StateError('El Workspace no contiene páginas.');
    }
    return pages.first;
  }

  Workspace copyWith({
    String? id,
    String? title,
    String? description,
    bool clearDescription = false,
    WorkspaceType? workspaceType,
    List<WorkspacePage>? pages,
    String? themeId,
    bool clearThemeId = false,
    String? templateId,
    bool clearTemplateId = false,
    bool? isFavorite,
    bool? isArchived,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    int? version,
    JsonMap? metadata,
  }) => Workspace(
    id: id ?? this.id,
    title: title ?? this.title,
    description: clearDescription ? null : description ?? this.description,
    workspaceType: workspaceType ?? this.workspaceType,
    pages: pages ?? this.pages,
    themeId: clearThemeId ? null : themeId ?? this.themeId,
    templateId: clearTemplateId ? null : templateId ?? this.templateId,
    isFavorite: isFavorite ?? this.isFavorite,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    version: version ?? this.version,
    metadata: metadata ?? this.metadata,
  );

  JsonMap toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'workspaceType': workspaceType.name,
    'pages': pages.map((page) => page.toJson()).toList(growable: false),
    'themeId': themeId,
    'templateId': templateId,
    'isFavorite': isFavorite,
    'isArchived': isArchived,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
    'version': version,
    'metadata': metadata,
  };

  factory Workspace.fromJson(Object? value) {
    final json = value is Map
        ? Map<String, Object?>.from(value)
        : <String, Object?>{};
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return Workspace(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      workspaceType: WorkspaceType.values.firstWhere(
        (value) => value.name == json['workspaceType'],
        orElse: () => WorkspaceType.document,
      ),
      pages: json['pages'] is List
          ? (json['pages'] as List).map(WorkspacePage.fromJson).toList()
          : const [],
      themeId: json['themeId'] as String?,
      templateId: json['templateId'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toUtc() ??
          createdAt,
      deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? '')?.toUtc(),
      version: (json['version'] as num?)?.toInt() ?? 1,
      metadata: json['metadata'] is Map
          ? Map<String, Object?>.from(json['metadata'] as Map)
          : const {},
    );
  }
}
