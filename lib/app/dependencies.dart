import 'package:allministrator/core/database/app_database.dart';
import 'package:allministrator/features/documents/data/datasources/documents_local_data_source.dart';
import 'package:allministrator/features/documents/data/repositories/drift_document_repository.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';

final AppDatabase appDatabase = AppDatabase.defaults();
final DocumentRepository documentRepository = DriftDocumentRepository(
  DriftDocumentsLocalDataSource(appDatabase),
);
