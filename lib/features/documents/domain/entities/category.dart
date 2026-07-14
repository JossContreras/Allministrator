class DocumentCategory {
  const DocumentCategory({
    required this.id,
    required this.name,
    required this.colorId,
    this.iconId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.version,
  });
  final String id, name, colorId;
  final String? iconId;
  final DateTime createdAt, updatedAt;
  final DateTime? deletedAt;
  final int version;
}
