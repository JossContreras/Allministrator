import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/documents/presentation/documents_screen.dart';
import 'package:flutter/widgets.dart';

class RecentScreen extends StatelessWidget {
  const RecentScreen({required this.repository, super.key});

  final DocumentRepository repository;

  @override
  Widget build(BuildContext context) => DocumentsBrowserScreen(
    repository: repository,
    title: 'Recientes',
    selectedPath: '/recent',
    filter: DocumentsBrowserFilter.recent,
  );
}
