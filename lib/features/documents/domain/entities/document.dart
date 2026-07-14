import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';

class Document {
  const Document({
    required this.id,
    required this.title,
    required this.content,
    this.categoryId,
    required this.isFavorite,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.version,
  });

  final Uuid id;
  final String title;
  final DocumentContent content;
  final String? categoryId;
  final bool isFavorite;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int version;

  Document copyWith({
    String? title,
    DocumentContent? content,
    String? categoryId,
    bool? isFavorite,
    bool? isPinned,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    int? version,
  }) => Document(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    categoryId: categoryId ?? this.categoryId,
    isFavorite: isFavorite ?? this.isFavorite,
    isPinned: isPinned ?? this.isPinned,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    version: version ?? this.version,
  );
}
