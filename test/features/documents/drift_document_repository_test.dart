import 'dart:io';

import 'package:allministrator/core/database/app_database.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:allministrator/features/documents/data/datasources/documents_local_data_source.dart';
import 'package:allministrator/features/documents/data/repositories/drift_document_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftDocumentRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftDocumentRepository(
      DriftDocumentsLocalDataSource(database),
    );
  });

  tearDown(() => database.close());

  test(
    'supports document lifecycle and excludes trash from active stream',
    () async {
      final created = await repository.createDocument();
      expect(created.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect((await repository.getDocumentById(created.id))?.version, 1);

      final titled = await repository.updateTitle(created.id, 'Mi nota');
      final edited = await repository.updateContent(
        created.id,
        const DocumentContent(schemaVersion: 1, data: {'text': 'Contenido'}),
      );
      expect(titled.title, 'Mi nota');
      expect(edited.content.text, 'Contenido');
      expect(edited.version, greaterThan(created.version));

      final favorite = await repository.toggleFavorite(created.id);
      final pinned = await repository.togglePinned(created.id);
      expect(favorite.isFavorite, isTrue);
      expect(pinned.isPinned, isTrue);

      final deleted = await repository.moveToTrash(created.id);
      expect(deleted.deletedAt, isNotNull);
      expect(await repository.watchActiveDocuments().first, isEmpty);
      expect(
        (await repository.watchDeletedDocuments().first).single.id,
        created.id,
      );

      final restored = await repository.restoreDocument(created.id);
      expect(restored.deletedAt, isNull);
      await repository.moveToTrash(created.id);
      await repository.deletePermanently(created.id);
      expect(await repository.getDocumentById(created.id), isNull);
    },
  );

  test('orders pinned documents before other active documents', () async {
    final first = await repository.createDocument();
    final second = await repository.createDocument();
    await repository.togglePinned(second.id);

    final active = await repository.watchActiveDocuments().first;
    expect(active.map((document) => document.id).toList(), [
      second.id,
      first.id,
    ]);
  });

  test('keeps a document after reopening the SQLite database', () async {
    final directory = await Directory.systemTemp.createTemp('documents_test_');
    final file = File(
      '${directory.path}${Platform.pathSeparator}documents.sqlite',
    );
    await database.close();

    database = AppDatabase(NativeDatabase(file));
    repository = DriftDocumentRepository(
      DriftDocumentsLocalDataSource(database),
    );
    final created = await repository.createDocument();
    await database.close();

    database = AppDatabase(NativeDatabase(file));
    repository = DriftDocumentRepository(
      DriftDocumentsLocalDataSource(database),
    );
    expect((await repository.getDocumentById(created.id))?.id, created.id);

    await database.close();
    await directory.delete(recursive: true);
  });
}
