import 'dart:async';

import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/features/documents/presentation/document_card.dart';
import 'package:allministrator/features/documents/presentation/category_catalog.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/documents/domain/use_cases/document_use_cases.dart';
import 'package:allministrator/features/shared/presentation/main_navigation_scaffold.dart';
import 'package:allministrator/app/theme/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

enum DocumentsBrowserFilter { active, favorites, trash }

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({required this.repository, super.key});
  final DocumentRepository repository;

  @override
  Widget build(BuildContext context) => DocumentsBrowserScreen(
    repository: repository,
    title: 'Mis documentos',
    selectedPath: '/documents',
  );
}

class DocumentsBrowserScreen extends StatefulWidget {
  const DocumentsBrowserScreen({
    required this.repository,
    required this.title,
    required this.selectedPath,
    this.filter = DocumentsBrowserFilter.active,
    super.key,
  });

  final DocumentRepository repository;
  final String title;
  final String selectedPath;
  final DocumentsBrowserFilter filter;

  @override
  State<DocumentsBrowserScreen> createState() => _DocumentsBrowserScreenState();
}

class _DocumentsBrowserScreenState extends State<DocumentsBrowserScreen> {
  late final DocumentsController _controller;
  bool _isGrid = true;

  @override
  void initState() {
    super.initState();
    _controller = DocumentsController(widget.repository, widget.filter);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTrash = widget.filter == DocumentsBrowserFilter.trash;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => MainNavigationScaffold(
        title: widget.title,
        selectedPath: widget.selectedPath,
        actions: isTrash
            ? null
            : [
                IconButton(
                  tooltip: 'Buscar',
                  icon: const Icon(Icons.search),
                  onPressed: () => _showPending(
                    'La búsqueda estará disponible próximamente.',
                  ),
                ),
                IconButton(
                  tooltip: _isGrid ? 'Vista de lista' : 'Vista de cuadrícula',
                  icon: Icon(
                    _isGrid ? Icons.view_list_outlined : Icons.grid_view,
                  ),
                  onPressed: () => setState(() => _isGrid = !_isGrid),
                ),
                IconButton(
                  tooltip: 'Ordenar y filtrar',
                  icon: const Icon(Icons.tune),
                  onPressed: () => _showPending(
                    'Los filtros estarán disponibles próximamente.',
                  ),
                ),
              ],
        floatingActionButton: widget.filter == DocumentsBrowserFilter.active
            ? FloatingActionButton(
                tooltip: 'Nuevo documento',
                onPressed: _createDocument,
                child: const Icon(Icons.add),
              )
            : null,
        child: _buildBody(context, isTrash),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isTrash) {
    if (_controller.loading && _controller.documents.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.error != null && _controller.documents.isEmpty) {
      return _ErrorState(message: _controller.error!);
    }
    if (_controller.documents.isEmpty) {
      return Center(
        child: Text(
          isTrash ? 'La papelera está vacía' : 'No hay documentos todavía',
        ),
      );
    }
    return AnimatedSwitcher(
      duration: AppMotion.normal,
      child: KeyedSubtree(
        key: ValueKey(_isGrid),
        child: _isGrid
            ? _DocumentsGrid(
                documents: _controller.documents,
                isTrash: isTrash,
                onAction: _onAction,
              )
            : _DocumentsList(
                documents: _controller.documents,
                isTrash: isTrash,
                onAction: _onAction,
              ),
      ),
    );
  }

  Future<void> _createDocument() async {
    try {
      final document = await _controller.createDocument();
      if (mounted) context.go('/editor/${document.id}');
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _onAction(Document document, DocumentCardAction action) async {
    try {
      switch (action) {
        case DocumentCardAction.open:
          context.go('/editor/${document.id}');
        case DocumentCardAction.category:
          await _changeCategory(document);
        case DocumentCardAction.favorite:
          await HapticFeedback.selectionClick();
          await _controller.toggleFavorite(document.id);
        case DocumentCardAction.pin:
          await HapticFeedback.selectionClick();
          await _controller.togglePinned(document.id);
        case DocumentCardAction.trash:
          await _controller.moveToTrash(document.id);
          if (mounted) {
            _showActionSnackBar(
              'Documento movido a la papelera',
              action: SnackBarAction(
                label: 'Deshacer',
                onPressed: () => _controller.restoreDocument(document.id),
              ),
            );
          }
        case DocumentCardAction.restore:
          await _controller.restoreDocument(document.id);
          if (mounted) _showActionSnackBar('Documento restaurado');
        case DocumentCardAction.delete:
          if (await _confirmPermanentDelete(context)) {
            await _controller.deletePermanently(document.id);
          }
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<bool> _confirmPermanentDelete(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Eliminar documento'),
          content: const Text('Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _changeCategory(Document document) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final category in CategoryCatalog.values)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: category.color,
                  radius: 10,
                ),
                title: Text(category.name),
                trailing: document.categoryId == category.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, category.id),
              ),
          ],
        ),
      ),
    );
    if (selected == null || selected == document.categoryId) return;
    await widget.repository.updateDocument(
      document.copyWith(categoryId: selected),
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Categoría actualizada')));
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('No se pudo completar la operación: $error')),
  );

  void _showActionSnackBar(String message, {SnackBarAction? action}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.remove);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: const Duration(milliseconds: 2200),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  void _showPending(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class DocumentsController extends ChangeNotifier {
  DocumentsController(this.repository, this.filter) {
    _subscription =
        (filter == DocumentsBrowserFilter.trash
                ? WatchDeletedDocuments(repository)()
                : WatchActiveDocuments(repository)())
            .listen(
              (documents) {
                this.documents = filter == DocumentsBrowserFilter.favorites
                    ? documents
                          .where((document) => document.isFavorite)
                          .toList()
                    : documents;
                loading = false;
                error = null;
                notifyListeners();
              },
              onError: (Object exception) {
                loading = false;
                error = 'No se pudieron cargar los documentos.';
                notifyListeners();
              },
            );
  }

  final DocumentRepository repository;
  final DocumentsBrowserFilter filter;
  StreamSubscription<List<Document>>? _subscription;
  List<Document> documents = const [];
  bool loading = true;
  String? error;

  Future<Document> createDocument() => CreateDocument(repository)();

  Future<Document> toggleFavorite(String id) =>
      ToggleDocumentFavorite(repository)(id);

  Future<Document> togglePinned(String id) =>
      ToggleDocumentPinned(repository)(id);

  Future<Document> moveToTrash(String id) =>
      MoveDocumentToTrash(repository)(id);

  Future<Document> restoreDocument(String id) =>
      RestoreDocument(repository)(id);

  Future<void> deletePermanently(String id) =>
      DeleteDocumentPermanently(repository)(id);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class _DocumentsGrid extends StatelessWidget {
  const _DocumentsGrid({
    required this.documents,
    required this.isTrash,
    required this.onAction,
  });
  final List<Document> documents;
  final bool isTrash;
  final Future<void> Function(Document, DocumentCardAction) onAction;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    var index = 0;
    while (index < documents.length) {
      if (index % 3 == 0 || index == documents.length - 1) {
        rows.add(_mosaicCard(context, documents[index], height: 196));
        index++;
      } else {
        final first = documents[index];
        final second = documents[index + 1];
        rows.add(
          Row(
            children: [
              Expanded(child: _mosaicCard(context, first, height: 164)),
              const SizedBox(width: 12),
              Expanded(child: _mosaicCard(context, second, height: 164)),
            ],
          ),
        );
        index += 2;
      }
      if (index < documents.length) rows.add(const SizedBox(height: 12));
    }
    return ListView(padding: const EdgeInsets.all(16), children: rows);
  }

  Widget _mosaicCard(
    BuildContext context,
    Document document, {
    required double height,
  }) => SizedBox(
    height: height,
    child: DocumentCard(
      document: document,
      isTrash: isTrash,
      onTap: isTrash ? null : () => context.go('/editor/${document.id}'),
      onAction: (action) => onAction(document, action),
    ),
  );
}

class _DocumentsList extends StatelessWidget {
  const _DocumentsList({
    required this.documents,
    required this.isTrash,
    required this.onAction,
  });
  final List<Document> documents;
  final bool isTrash;
  final Future<void> Function(Document, DocumentCardAction) onAction;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: documents.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (_, index) => SizedBox(
      height: 82,
      child: DocumentCard(
        document: documents[index],
        isTrash: isTrash,
        isList: true,
        onTap: isTrash
            ? null
            : () => context.go('/editor/${documents[index].id}'),
        onAction: (action) => onAction(documents[index], action),
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(child: Text(message));
}

// ignore: unused_element
class _EmptyDocumentsState extends StatelessWidget {
  const _EmptyDocumentsState({
    required this.isTrash,
    required this.isFavorites,
  });
  final bool isTrash, isFavorites;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isTrash
              ? Icons.delete_outline
              : isFavorites
              ? Icons.star_outline
              : Icons.description_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          isTrash
              ? 'La papelera está vacía'
              : isFavorites
              ? 'Aún no tienes favoritos'
              : 'No hay documentos todavía',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text('Crea un documento para comenzar.'),
      ],
    ),
  );
}
