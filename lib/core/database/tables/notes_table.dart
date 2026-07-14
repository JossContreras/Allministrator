import 'package:drift/drift.dart';
import 'package:allministrator/core/database/tables/folders_table.dart';

@DataClassName('NoteRow')
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get folderId => text().nullable().references(Folders, #id)();
  IntColumn get documentSchemaVersion => integer()();
  TextColumn get documentJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}
