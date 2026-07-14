import 'package:drift/drift.dart';

class Settings extends Table {
  TextColumn get id => text()();
  TextColumn get key => text().unique()();
  TextColumn get valueJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}
