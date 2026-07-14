import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/entities/syncable_entity.dart';

class Settings implements SyncableEntity {
  const Settings({
    required this.id,
    required this.key,
    required this.preferences,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.deletedAt,
  });
  @override
  final Uuid id;
  final String key;
  final JsonMap preferences;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final int version;
  @override
  final DateTime? deletedAt;
}
