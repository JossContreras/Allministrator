import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/documents/presentation/documents_screen.dart';
import 'package:flutter/widgets.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({required this.repository, super.key});
  final DocumentRepository repository;

  @override
  Widget build(BuildContext context) => DocumentsBrowserScreen(
    repository: repository,
    title: 'Favoritos',
    selectedPath: '/favorites',
    filter: DocumentsBrowserFilter.favorites,
  );
}
