import 'package:allministrator/core/shared/identifiers.dart';

/// Campos comunes de una entidad que puede sincronizarse.
abstract interface class SyncableEntity {
  Uuid get id;
  int get version;
  DateTime get updatedAt;
  DateTime? get deletedAt;
}
