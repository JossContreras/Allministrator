import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/documents/presentation/documents_screen.dart';
import 'package:flutter/widgets.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({required this.repository, super.key});
  final DocumentRepository repository;

  @override
  Widget build(BuildContext context) => DocumentsBrowserScreen(
    repository: repository,
    title: 'Papelera',
    selectedPath: '/trash',
    filter: DocumentsBrowserFilter.trash,
  );
}
