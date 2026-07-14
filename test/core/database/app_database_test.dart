import 'package:allministrator/core/database/app_database.dart';
import 'package:allministrator/domain/entities/note.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:allministrator/features/notes/data/datasources/notes_local_data_source.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftNotesLocalDataSource dataSource;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    dataSource = DriftNotesLocalDataSource(database);
  });

  tearDown(() => database.close());

  test('persists a structured document in SQLite', () async {
    final note = Note(
      id: '00000000-0000-0000-0000-000000000001',
      document: const DocumentContent(
        schemaVersion: 1,
        data: {'type': 'document', 'children': []},
      ),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      version: 1,
    );

    await dataSource.save(note);
    final restored = await dataSource.findActiveById(note.id);

    expect(restored?.document.schemaVersion, 1);
    expect(restored?.document.data['type'], 'document');
  });
}
