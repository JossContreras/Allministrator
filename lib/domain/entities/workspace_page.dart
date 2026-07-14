import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/blocks/blocks.dart';

enum WorkspaceLayoutType { document, canvas, whiteboard }

class WorkspacePage {
  const WorkspacePage({
    required this.id,
    required this.workspaceId,
    required this.title,
    required this.layoutType,
    required this.blocks,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.version,
    required this.metadata,
  });

  final Uuid id;
  final Uuid workspaceId;
  final String? title;
  final WorkspaceLayoutType layoutType;
  final List<BaseBlock> blocks;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int version;
  final JsonMap metadata;

  List<BaseBlock> get orderedBlocks {
    final result = [...blocks];
    result.sort((first, second) => first.orderKey.compareTo(second.orderKey));
    return result;
  }

  WorkspacePage copyWith({
    String? workspaceId,
    String? title,
    bool clearTitle = false,
    WorkspaceLayoutType? layoutType,
    List<BaseBlock>? blocks,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    int? version,
    JsonMap? metadata,
  }) => WorkspacePage(
    id: id,
    workspaceId: workspaceId ?? this.workspaceId,
    title: clearTitle ? null : title ?? this.title,
    layoutType: layoutType ?? this.layoutType,
    blocks: blocks ?? this.blocks,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    version: version ?? this.version,
    metadata: metadata ?? this.metadata,
  );

  WorkspacePage normalizeOrder() {
    final ordered = orderedBlocks;
    final now = DateTime.now().toUtc();
    return copyWith(
      blocks: [
        for (var index = 0; index < ordered.length; index++)
          ordered[index].copyWithCommon(
            orderKey: index.toDouble(),
            updatedAt: ordered[index].orderKey == index.toDouble()
                ? ordered[index].updatedAt
                : now,
          ),
      ],
    );
  }

  JsonMap toJson() => {
    'id': id,
    'workspaceId': workspaceId,
    'title': title,
    'layoutType': layoutType.name,
    'blocks': orderedBlocks.map(BlockCodec.toJson).toList(growable: false),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
    'version': version,
    'metadata': metadata,
  };

  factory WorkspacePage.fromJson(Object? value) {
    final json = value is Map
        ? Map<String, Object?>.from(value)
        : <String, Object?>{};
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return WorkspacePage(
      id: json['id'] as String? ?? generateUuid(),
      workspaceId: json['workspaceId'] as String? ?? '',
      title: json['title'] as String?,
      layoutType: WorkspaceLayoutType.values.firstWhere(
        (value) => value.name == json['layoutType'],
        orElse: () => WorkspaceLayoutType.document,
      ),
      blocks: json['blocks'] is List
          ? (json['blocks'] as List).map(BlockCodec.fromJson).toList()
          : const [],
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
