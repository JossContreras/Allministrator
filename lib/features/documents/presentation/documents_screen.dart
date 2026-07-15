import 'dart:async';
import 'dart:convert';

import 'package:allministrator/app/theme/app_icons.dart';
import 'package:allministrator/app/theme/app_motion.dart';
import 'package:allministrator/app/theme/app_spacing.dart';
import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/documents/domain/services/starter_document_service.dart';
import 'package:allministrator/features/documents/domain/use_cases/document_use_cases.dart';
import 'package:allministrator/features/documents/presentation/category_catalog.dart';
import 'package:allministrator/features/documents/presentation/document_card.dart';
import 'package:allministrator/features/documents/presentation/document_category_picker.dart';
import 'package:allministrator/features/content_io/data/external_document_import_service.dart';
import 'package:allministrator/features/shared/presentation/app_empty_state.dart';
import 'package:allministrator/features/shared/presentation/main_navigation_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

enum DocumentsBrowserFilter { all, active, canvas, recent, favorites, trash }

enum DocumentsSort { updatedDesc, createdDesc, titleAsc }

enum DocumentSizeFilter { all, small, medium, large }

enum DocumentDateFilter { anytime, today, sevenDays, thirtyDays, thisYear }

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
    this.initialCategoryId,
    super.key,
  });

  final DocumentRepository repository;
  final String title;
  final String selectedPath;
  final DocumentsBrowserFilter filter;
  final String? initialCategoryId;

  @override
  State<DocumentsBrowserScreen> createState() => _DocumentsBrowserScreenState();
}

class _DocumentsBrowserScreenState extends State<DocumentsBrowserScreen> {
  late final DocumentsController _controller;
  final TextEditingController _searchController = TextEditingController();
  bool _isGrid = true;
  bool _showSearch = false;
  String _query = '';
  String? _categoryId;
  DocumentKind? _kind;
  DocumentSizeFilter _size = DocumentSizeFilter.all;
  DocumentDateFilter _date = DocumentDateFilter.anytime;
  DocumentsSort _sort = DocumentsSort.updatedDesc;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _controller = DocumentsController(widget.repository, widget.filter);
    _categoryId = widget.initialCategoryId;
    _searchController.addListener(_searchChanged);
  }

  void _searchChanged() {
    if (_query == _searchController.text) return;
    setState(() => _query = _searchController.text);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_searchChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => MainNavigationScaffold(
      title: widget.title,
      selectedPath: widget.selectedPath,
      actions: [
        if (widget.filter == DocumentsBrowserFilter.all ||
            widget.filter == DocumentsBrowserFilter.active)
          IconButton(
            tooltip: 'Importar archivo',
            onPressed: _importing ? null : _importExternalFile,
            icon: _importing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_open_outlined),
          ),
        IconButton(
          tooltip: _showSearch ? 'Cerrar búsqueda' : 'Buscar',
          icon: Icon(_showSearch ? Icons.close_rounded : AppIcons.search),
          onPressed: () => setState(() {
            _showSearch = !_showSearch;
            if (!_showSearch) _searchController.clear();
          }),
        ),
        IconButton(
          tooltip: _isGrid ? 'Vista de lista' : 'Vista de cuadrícula',
          icon: Icon(_isGrid ? Icons.view_list_outlined : Icons.grid_view),
          onPressed: () => setState(() => _isGrid = !_isGrid),
        ),
        IconButton(
          tooltip: 'Ordenar y filtrar',
          icon: const Icon(AppIcons.filter),
          onPressed: _showFilters,
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
      floatingActionButton:
          widget.filter == DocumentsBrowserFilter.active ||
              widget.filter == DocumentsBrowserFilter.canvas
          ? FloatingActionButton.extended(
              tooltip: widget.filter == DocumentsBrowserFilter.canvas
                  ? 'Nuevo Canvas'
                  : 'Nuevo documento',
              onPressed: _createDocument,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                widget.filter == DocumentsBrowserFilter.canvas
                    ? 'Nuevo Canvas'
                    : 'Crear',
              ),
            )
          : null,
      child: _buildBody(context),
    ),
  );

  Widget _buildBody(BuildContext context) {
    if (_controller.loading && _controller.documents.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.error != null && _controller.documents.isEmpty) {
      return _ErrorState(message: _controller.error!);
    }
    if (_controller.documents.isEmpty) return _emptyState();
    final documents = _visibleDocuments;
    final isTrash = widget.filter == DocumentsBrowserFilter.trash;
    return Column(
      children: [
        AnimatedSize(
          duration: AppMotion.fast,
          curve: AppMotion.state,
          child: !_showSearch
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    0,
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Buscar por título, contenido o categoría',
                      prefixIcon: const Icon(AppIcons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.clear_rounded),
                            ),
                    ),
                  ),
                ),
        ),
        _DocumentsSummaryBar(
          count: documents.length,
          itemName: switch (widget.filter) {
            DocumentsBrowserFilter.canvas => 'Canvas',
            DocumentsBrowserFilter.all ||
            DocumentsBrowserFilter.trash => 'archivo',
            _ => 'documento',
          },
          categoryId: _categoryId,
          sort: _sort,
          onClearCategory: () => setState(() => _categoryId = null),
        ),
        Expanded(
          child: documents.isEmpty
              ? AppEmptyState(
                  icon: AppIcons.search,
                  title: 'No encontramos coincidencias',
                  message:
                      'Prueba con otra palabra o quita los filtros activos.',
                  actionLabel: 'Limpiar filtros',
                  onAction: () => setState(() {
                    _searchController.clear();
                    _categoryId = null;
                    _kind = null;
                    _size = DocumentSizeFilter.all;
                    _date = DocumentDateFilter.anytime;
                  }),
                )
              : AnimatedSwitcher(
                  duration: AppMotion.normal,
                  child: KeyedSubtree(
                    key: ValueKey(_isGrid),
                    child: _isGrid
                        ? _DocumentsGrid(
                            documents: documents,
                            isTrash: isTrash,
                            filter: widget.filter,
                            onAction: _onAction,
                          )
                        : _DocumentsList(
                            documents: documents,
                            isTrash: isTrash,
                            onAction: _onAction,
                          ),
                  ),
                ),
        ),
      ],
    );
  }

  List<Document> get _visibleDocuments {
    final normalizedQuery = _query.trim().toLowerCase();
    final result = _controller.documents.where((document) {
      final category = CategoryCatalog.resolve(document.categoryId);
      if (_categoryId != null && category.id != _categoryId) return false;
      if (_kind != null && document.kind != _kind) return false;
      if (!_matchesSize(document, _size)) return false;
      if (!_matchesDate(document.updatedAt, _date)) return false;
      if (normalizedQuery.isEmpty) return true;
      return document.title.toLowerCase().contains(normalizedQuery) ||
          document.content.text.toLowerCase().contains(normalizedQuery) ||
          category.name.toLowerCase().contains(normalizedQuery);
    }).toList();
    switch (_sort) {
      case DocumentsSort.updatedDesc:
        result.sort((a, b) {
          if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });
      case DocumentsSort.createdDesc:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case DocumentsSort.titleAsc:
        result.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    }
    return result;
  }

  bool _matchesSize(Document document, DocumentSizeFilter filter) {
    if (filter == DocumentSizeFilter.all) return true;
    final serialized = utf8
        .encode(jsonEncode(document.content.toJson()))
        .length;
    final attachments = document.content.workspace.primaryPage.blocks
        .whereType<AttachmentBlock>()
        .fold<int>(0, (total, block) => total + block.sizeBytes);
    final bytes = serialized + attachments;
    return switch (filter) {
      DocumentSizeFilter.all => true,
      DocumentSizeFilter.small => bytes < 10 * 1024,
      DocumentSizeFilter.medium => bytes >= 10 * 1024 && bytes < 100 * 1024,
      DocumentSizeFilter.large => bytes >= 100 * 1024,
    };
  }

  bool _matchesDate(DateTime value, DocumentDateFilter filter) {
    if (filter == DocumentDateFilter.anytime) return true;
    final now = DateTime.now();
    final local = value.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final today = DateTime(now.year, now.month, now.day);
    return switch (filter) {
      DocumentDateFilter.anytime => true,
      DocumentDateFilter.today => day == today,
      DocumentDateFilter.sevenDays => !day.isBefore(
        today.subtract(const Duration(days: 6)),
      ),
      DocumentDateFilter.thirtyDays => !day.isBefore(
        today.subtract(const Duration(days: 29)),
      ),
      DocumentDateFilter.thisYear => local.year == now.year,
    };
  }

  Widget _emptyState() {
    final isTrash = widget.filter == DocumentsBrowserFilter.trash;
    final isFavorites = widget.filter == DocumentsBrowserFilter.favorites;
    final isRecent = widget.filter == DocumentsBrowserFilter.recent;
    final isCanvas = widget.filter == DocumentsBrowserFilter.canvas;
    final isAll = widget.filter == DocumentsBrowserFilter.all;
    return AppEmptyState(
      icon: isTrash
          ? AppIcons.trash
          : isFavorites
          ? AppIcons.favorite
          : isRecent
          ? AppIcons.recent
          : isAll
          ? Icons.folder_copy_outlined
          : isCanvas
          ? AppIcons.canvas
          : AppIcons.documents,
      title: isTrash
          ? 'La papelera está vacía'
          : isFavorites
          ? 'Guarda aquí lo que más importa'
          : isRecent
          ? 'Todavía no hay actividad reciente'
          : isAll
          ? 'Tu biblioteca está lista'
          : isCanvas
          ? 'Un espacio abierto para tus ideas'
          : 'Tu primera idea empieza aquí',
      message: isTrash
          ? 'Los documentos y Canvas que elimines aparecerán aquí y podrás restaurarlos.'
          : isFavorites
          ? 'Marca una tarjeta con la estrella para encontrarla rápidamente.'
          : isRecent
          ? 'Cuando edites documentos, aparecerán ordenados aquí.'
          : isAll
          ? 'Los documentos y Canvas que crees aparecerán aquí, claramente diferenciados.'
          : isCanvas
          ? 'Crea un Canvas para organizar bloques libremente en el espacio.'
          : 'Crea un documento y empieza a escribir sin configurar nada.',
      actionLabel: widget.filter == DocumentsBrowserFilter.active
          ? 'Crear documento'
          : isCanvas
          ? 'Crear Canvas'
          : null,
      onAction: widget.filter == DocumentsBrowserFilter.active || isCanvas
          ? _createDocument
          : null,
    );
  }

  Future<void> _showFilters() async {
    final result = await showModalBottomSheet<_DocumentsFilterResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _DocumentsFilterSheet(
        categoryId: _categoryId,
        sort: _sort,
        kind: _kind,
        size: _size,
        date: _date,
        showKind: widget.filter == DocumentsBrowserFilter.all,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _categoryId = result.categoryId;
      _sort = result.sort;
      _kind = result.kind;
      _size = result.size;
      _date = result.date;
    });
  }

  Future<void> _createDocument() async {
    try {
      final document = widget.filter == DocumentsBrowserFilter.canvas
          ? await StarterDocumentService(widget.repository).create(
              title: 'Canvas sin título',
              categoryId: 'ideas',
              layoutType: WorkspaceLayoutType.canvas,
            )
          : await _controller.createDocument();
      if (mounted) context.go('/editor/${document.id}');
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _importExternalFile() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final result = await ExternalDocumentImportService(
        repository: widget.repository,
      ).pickAndImport();
      if (!mounted || result == null) return;
      if (result.warning != null) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.info_outline),
            title: Text('.${result.sourceExtension.toUpperCase()} importado'),
            content: Text(result.warning!),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
      if (mounted) context.go('/editor/${result.document.id}');
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _importing = false);
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
              '${document.isCanvas ? 'Canvas' : 'Documento'} movido a la papelera',
              action: SnackBarAction(
                label: 'Deshacer',
                onPressed: () => _controller.restoreDocument(document.id),
              ),
            );
          }
        case DocumentCardAction.restore:
          await _controller.restoreDocument(document.id);
          if (mounted) {
            _showActionSnackBar(
              document.isCanvas ? 'Canvas restaurado' : 'Documento restaurado',
            );
          }
        case DocumentCardAction.delete:
          if (await _confirmPermanentDelete(context)) {
            await _controller.deletePermanently(document.id);
          }
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _changeCategory(Document document) async {
    final selected = await showDocumentCategoryPicker(
      context,
      currentCategoryId: document.categoryId,
    );
    if (selected == null || selected == document.categoryId) return;
    await widget.repository.updateDocument(
      document.copyWith(categoryId: selected),
    );
    if (mounted) _showActionSnackBar('Categoría actualizada');
  }

  Future<bool> _confirmPermanentDelete(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.delete_forever_outlined),
          title: const Text('Eliminar documento'),
          content: const Text(
            'Esta acción borrará el documento definitivamente y no se puede deshacer.',
          ),
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
      ),
    );
  }
}

class DocumentsController extends ChangeNotifier {
  DocumentsController(this.repository, this.filter) {
    _subscription =
        (filter == DocumentsBrowserFilter.trash
                ? WatchDeletedDocuments(repository)()
                : WatchActiveDocuments(repository)())
            .listen(
              (source) {
                documents = switch (filter) {
                  DocumentsBrowserFilter.all => source,
                  DocumentsBrowserFilter.favorites =>
                    source.where((document) => document.isFavorite).toList(),
                  DocumentsBrowserFilter.canvas =>
                    source.where((document) => document.isCanvas).toList(),
                  DocumentsBrowserFilter.active =>
                    source.where((document) => document.isDocument).toList(),
                  DocumentsBrowserFilter.recent => source.take(40).toList(),
                  DocumentsBrowserFilter.trash => source,
                };
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
    required this.filter,
    required this.onAction,
  });

  final List<Document> documents;
  final bool isTrash;
  final DocumentsBrowserFilter filter;
  final Future<void> Function(Document, DocumentCardAction) onAction;

  @override
  Widget build(BuildContext context) {
    if (filter == DocumentsBrowserFilter.canvas) {
      return _CanvasGallery(documents: documents, onAction: onAction);
    }
    if (filter == DocumentsBrowserFilter.active) {
      return _DocumentGallery(documents: documents, onAction: onAction);
    }
    if (filter == DocumentsBrowserFilter.all ||
        filter == DocumentsBrowserFilter.recent ||
        filter == DocumentsBrowserFilter.favorites) {
      return _UnifiedGallery(documents: documents, onAction: onAction);
    }
    if (filter == DocumentsBrowserFilter.trash) {
      return _UnifiedGallery(
        documents: documents,
        isTrash: true,
        onAction: onAction,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          104,
        ),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: constraints.maxWidth < 620 ? 620 : 320,
          childAspectRatio: 1.04,
          crossAxisSpacing: AppSpacing.sm + AppSpacing.xs,
          mainAxisSpacing: AppSpacing.sm + AppSpacing.xs,
        ),
        itemCount: documents.length,
        itemBuilder: (context, index) {
          final document = documents[index];
          return DocumentCard(
            key: ValueKey(document.id),
            document: document,
            isTrash: isTrash,
            onTap: isTrash ? null : () => context.go('/editor/${document.id}'),
            onAction: (action) => onAction(document, action),
          );
        },
      ),
    );
  }
}

class _DocumentGallery extends StatelessWidget {
  const _DocumentGallery({required this.documents, required this.onAction});

  final List<Document> documents;
  final Future<void> Function(Document, DocumentCardAction) onAction;

  @override
  Widget build(BuildContext context) {
    final featured = documents.first;
    final secondary = documents.skip(1).toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).width < 520 ? 304 : 280,
                  child: DocumentCard(
                    key: ValueKey('featured-${featured.id}'),
                    document: featured,
                    style: DocumentCardStyle.featured,
                    onTap: () => context.go('/editor/${featured.id}'),
                    onAction: (action) => onAction(featured, action),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (secondary.isNotEmpty)
          const SliverToBoxAdapter(
            child: _GallerySectionTitle(
              title: 'Más documentos',
              subtitle: 'Vistas rápidas para encontrar lo que buscas.',
            ),
          ),
        if (secondary.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              104,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                childAspectRatio: .92,
                crossAxisSpacing: AppSpacing.sm + AppSpacing.xs,
                mainAxisSpacing: AppSpacing.sm + AppSpacing.xs,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final document = secondary[index];
                return DocumentCard(
                  key: ValueKey(document.id),
                  document: document,
                  style: DocumentCardStyle.compact,
                  onTap: () => context.go('/editor/${document.id}'),
                  onAction: (action) => onAction(document, action),
                );
              }, childCount: secondary.length),
            ),
          ),
      ],
    );
  }
}

class _CanvasGallery extends StatelessWidget {
  const _CanvasGallery({required this.documents, required this.onAction});

  final List<Document> documents;
  final Future<void> Function(Document, DocumentCardAction) onAction;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      104,
    ),
    itemCount: documents.length,
    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
    itemBuilder: (context, index) {
      final document = documents[index];
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).width < 520 ? 262 : 292,
            child: DocumentCard(
              key: ValueKey(document.id),
              document: document,
              style: DocumentCardStyle.canvasPreview,
              onTap: () => context.go('/editor/${document.id}'),
              onAction: (action) => onAction(document, action),
            ),
          ),
        ),
      );
    },
  );
}

class _UnifiedGallery extends StatelessWidget {
  const _UnifiedGallery({
    required this.documents,
    required this.onAction,
    this.isTrash = false,
  });

  final List<Document> documents;
  final Future<void> Function(Document, DocumentCardAction) onAction;
  final bool isTrash;

  @override
  Widget build(BuildContext context) {
    final documentItems = documents.where((item) => item.isDocument).toList();
    final canvasItems = documents.where((item) => item.isCanvas).toList();
    return CustomScrollView(
      slivers: [
        if (documentItems.isNotEmpty)
          SliverToBoxAdapter(
            child: _GallerySectionTitle(
              title: isTrash ? 'Documentos eliminados' : 'Documentos',
              subtitle: isTrash
                  ? '${documentItems.length} disponibles para restaurar'
                  : '${documentItems.length} en flujo vertical',
            ),
          ),
        if (documentItems.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                childAspectRatio: .92,
                crossAxisSpacing: AppSpacing.sm + AppSpacing.xs,
                mainAxisSpacing: AppSpacing.sm + AppSpacing.xs,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final document = documentItems[index];
                return DocumentCard(
                  key: ValueKey(document.id),
                  document: document,
                  style: DocumentCardStyle.compact,
                  isTrash: isTrash,
                  onTap: isTrash
                      ? null
                      : () => context.go('/editor/${document.id}'),
                  onAction: (action) => onAction(document, action),
                );
              }, childCount: documentItems.length),
            ),
          ),
        if (canvasItems.isNotEmpty)
          SliverToBoxAdapter(
            child: _GallerySectionTitle(
              title: isTrash ? 'Canvas eliminados' : 'Canvas',
              subtitle: isTrash
                  ? '${canvasItems.length} lienzos disponibles para restaurar'
                  : '${canvasItems.length} lienzos espaciales',
            ),
          ),
        if (canvasItems.isNotEmpty)
          SliverList.builder(
            itemCount: canvasItems.length,
            itemBuilder: (context, index) {
              final document = canvasItems[index];
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  index == 0 ? AppSpacing.xs : AppSpacing.sm,
                  AppSpacing.md,
                  index == canvasItems.length - 1 ? 104 : AppSpacing.xs,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: SizedBox(
                      height: MediaQuery.sizeOf(context).width < 520
                          ? 262
                          : 292,
                      child: DocumentCard(
                        key: ValueKey(document.id),
                        document: document,
                        style: DocumentCardStyle.canvasPreview,
                        isTrash: isTrash,
                        onTap: isTrash
                            ? null
                            : () => context.go('/editor/${document.id}'),
                        onAction: (action) => onAction(document, action),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _GallerySectionTitle extends StatelessWidget {
  const _GallerySectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.xs,
    ),
    child: Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            subtitle,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
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
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      104,
    ),
    itemCount: documents.length,
    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
    itemBuilder: (context, index) {
      final document = documents[index];
      return SizedBox(
        height: 86,
        child: DocumentCard(
          key: ValueKey(document.id),
          document: document,
          isTrash: isTrash,
          isList: true,
          onTap: isTrash ? null : () => context.go('/editor/${document.id}'),
          onAction: (action) => onAction(document, action),
        ),
      );
    },
  );
}

class _DocumentsSummaryBar extends StatelessWidget {
  const _DocumentsSummaryBar({
    required this.count,
    required this.itemName,
    required this.categoryId,
    required this.sort,
    required this.onClearCategory,
  });

  final int count;
  final String itemName;
  final String? categoryId;
  final DocumentsSort sort;
  final VoidCallback onClearCategory;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.xs,
    ),
    child: Row(
      children: [
        Text(
          '$count ${count == 1
              ? itemName
              : itemName == 'Canvas'
              ? 'Canvas'
              : '${itemName}s'}',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        if (categoryId != null)
          InputChip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(
              CategoryCatalog.resolve(categoryId).icon,
              size: 16,
              color: CategoryCatalog.resolve(categoryId).color,
            ),
            label: Text(CategoryCatalog.resolve(categoryId).name),
            onDeleted: onClearCategory,
          ),
        if (categoryId != null) const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            _sortLabel(sort),
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DocumentsFilterResult {
  const _DocumentsFilterResult({
    required this.categoryId,
    required this.sort,
    required this.kind,
    required this.size,
    required this.date,
  });
  final String? categoryId;
  final DocumentsSort sort;
  final DocumentKind? kind;
  final DocumentSizeFilter size;
  final DocumentDateFilter date;
}

class _DocumentsFilterSheet extends StatefulWidget {
  const _DocumentsFilterSheet({
    required this.categoryId,
    required this.sort,
    required this.kind,
    required this.size,
    required this.date,
    required this.showKind,
  });

  final String? categoryId;
  final DocumentsSort sort;
  final DocumentKind? kind;
  final DocumentSizeFilter size;
  final DocumentDateFilter date;
  final bool showKind;

  @override
  State<_DocumentsFilterSheet> createState() => _DocumentsFilterSheetState();
}

class _DocumentsFilterSheetState extends State<_DocumentsFilterSheet> {
  late String? _categoryId = widget.categoryId;
  late DocumentsSort _sort = widget.sort;
  late DocumentKind? _kind = widget.kind;
  late DocumentSizeFilter _size = widget.size;
  late DocumentDateFilter _date = widget.date;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ordenar y filtrar',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (widget.showKind) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Tipo de archivo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _kind == null,
                  onSelected: (_) => setState(() => _kind = null),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.article_outlined, size: 16),
                  label: const Text('Documentos'),
                  selected: _kind == DocumentKind.document,
                  onSelected: (_) =>
                      setState(() => _kind = DocumentKind.document),
                ),
                ChoiceChip(
                  avatar: const Icon(
                    Icons.dashboard_customize_outlined,
                    size: 16,
                  ),
                  label: const Text('Canvas'),
                  selected: _kind == DocumentKind.canvas,
                  onSelected: (_) =>
                      setState(() => _kind = DocumentKind.canvas),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('Categoría', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text('Todas'),
                selected: _categoryId == null,
                onSelected: (_) => setState(() => _categoryId = null),
              ),
              for (final category in CategoryCatalog.values)
                ChoiceChip(
                  avatar: Icon(category.icon, size: 16, color: category.color),
                  label: Text(category.name),
                  selected: _categoryId == category.id,
                  onSelected: (_) => setState(() => _categoryId = category.id),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Tamaño del contenido',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final value in DocumentSizeFilter.values)
                ChoiceChip(
                  label: Text(_sizeLabel(value)),
                  selected: _size == value,
                  onSelected: (_) => setState(() => _size = value),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Última edición',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final value in DocumentDateFilter.values)
                ChoiceChip(
                  label: Text(_dateLabel(value)),
                  selected: _date == value,
                  onSelected: (_) => setState(() => _date = value),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Orden', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          RadioGroup<DocumentsSort>(
            groupValue: _sort,
            onChanged: (value) {
              if (value != null) setState(() => _sort = value);
            },
            child: const Column(
              children: [
                RadioListTile(
                  value: DocumentsSort.updatedDesc,
                  title: Text('Última edición'),
                ),
                RadioListTile(
                  value: DocumentsSort.createdDesc,
                  title: Text('Fecha de creación'),
                ),
                RadioListTile(
                  value: DocumentsSort.titleAsc,
                  title: Text('Título de A a Z'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _DocumentsFilterResult(
                  categoryId: _categoryId,
                  sort: _sort,
                  kind: _kind,
                  size: _size,
                  date: _date,
                ),
              ),
              child: const Text('Aplicar'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: Icons.cloud_off_outlined,
    title: 'No pudimos cargar tus documentos',
    message: message,
  );
}

String _sortLabel(DocumentsSort sort) => switch (sort) {
  DocumentsSort.updatedDesc => 'Última edición',
  DocumentsSort.createdDesc => 'Más recientes',
  DocumentsSort.titleAsc => 'A–Z',
};

String _sizeLabel(DocumentSizeFilter filter) => switch (filter) {
  DocumentSizeFilter.all => 'Cualquier tamaño',
  DocumentSizeFilter.small => 'Ligero · < 10 KB',
  DocumentSizeFilter.medium => 'Medio · 10–100 KB',
  DocumentSizeFilter.large => 'Grande · > 100 KB',
};

String _dateLabel(DocumentDateFilter filter) => switch (filter) {
  DocumentDateFilter.anytime => 'Cualquier fecha',
  DocumentDateFilter.today => 'Hoy',
  DocumentDateFilter.sevenDays => 'Últimos 7 días',
  DocumentDateFilter.thirtyDays => 'Últimos 30 días',
  DocumentDateFilter.thisYear => 'Este año',
};
