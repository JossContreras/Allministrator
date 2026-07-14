import 'package:drift/drift.dart';
import 'package:allministrator/core/database/tables/notes_table.dart';

class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text().references(Notes, #id)();
  TextColumn get documentNodeId => text().nullable()();
  TextColumn get type => text()();
  TextColumn get storageKey => text()();
  TextColumn get fileName => text()();
  TextColumn get mimeType => text()();
  IntColumn get byteSize => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}
