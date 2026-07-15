import 'package:allministrator/core/database/tables/attachments_table.dart';
import 'package:allministrator/core/database/tables/categories_table.dart';
import 'package:allministrator/core/database/tables/documents_table.dart';
import 'package:allministrator/core/database/tables/folders_table.dart';
import 'package:allministrator/core/database/tables/note_tags_table.dart';
import 'package:allministrator/core/database/tables/notes_table.dart';
import 'package:allministrator/core/database/tables/settings_table.dart';
import 'package:allministrator/core/database/tables/tags_table.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Documents,
    Categories,
    Notes,
    Folders,
    Tags,
    NoteTags,
    Attachments,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.defaults() : super(driftDatabase(name: 'allministrator'));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _seedCategories();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await migrator.createTable(documents);
      if (from < 3) {
        await migrator.createTable(categories);
        await migrator.addColumn(documents, documents.categoryId);
        await _seedCategories();
      }
      if (from < 4) {
        await migrator.addColumn(attachments, attachments.documentId);
        await migrator.addColumn(attachments, attachments.localPath);
        await migrator.addColumn(attachments, attachments.displayName);
        await migrator.addColumn(attachments, attachments.extension);
        await migrator.addColumn(attachments, attachments.checksum);
      }
      if (from < 5) await _seedCategories();
    },
  );

  Future<void> _seedCategories() async {
    final now = DateTime.now().toUtc();
    const defaults = <(String, String, String)>[
      ('personal', 'Personal', 'blue'),
      ('trabajo', 'Trabajo', 'purple'),
      ('estudio', 'Estudio', 'teal'),
      ('ideas', 'Ideas', 'amber'),
      ('proyectos', 'Proyectos', 'rose'),
      ('archivos', 'Archivos', 'cyan'),
      ('none', 'Sin categoría', 'slate'),
    ];
    await batch((batch) {
      batch.insertAllOnConflictUpdate(categories, [
        for (final item in defaults)
          CategoriesCompanion.insert(
            id: item.$1,
            name: item.$2,
            colorId: item.$3,
            createdAt: now,
            updatedAt: now,
          ),
      ]);
    });
  }
}
