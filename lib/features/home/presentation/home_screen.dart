import 'package:allministrator/app/theme/app_icons.dart';
import 'package:allministrator/app/theme/app_radius.dart';
import 'package:allministrator/app/theme/app_spacing.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/documents/domain/services/starter_document_service.dart';
import 'package:allministrator/features/documents/presentation/category_catalog.dart';
import 'package:allministrator/features/documents/presentation/document_card.dart';
import 'package:allministrator/features/documents/presentation/document_category_picker.dart';
import 'package:allministrator/features/documents/presentation/documents_screen.dart';
import 'package:allministrator/features/shared/presentation/main_navigation_scaffold.dart';
import 'package:allministrator/features/shared/presentation/section_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.repository, super.key});

  final DocumentRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final DocumentsController _controller;
  late final StarterDocumentService _starterDocuments;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _controller = DocumentsController(
      widget.repository,
      DocumentsBrowserFilter.all,
    );
    _starterDocuments = StarterDocumentService(widget.repository);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => MainNavigationScaffold(
      title: 'Inicio',
      selectedPath: '/home',
      actions: [
        IconButton(
          tooltip: 'Ver todos los archivos',
          onPressed: () => context.go('/library'),
          icon: const Icon(Icons.folder_copy_outlined),
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
      child: _buildBody(context),
    ),
  );

  Widget _buildBody(BuildContext context) {
    if (_controller.loading && _controller.documents.isEmpty) {
      return const _HomeSkeleton();
    }
    if (_controller.error != null && _controller.documents.isEmpty) {
      return Center(child: Text(_controller.error!));
    }
    final documents = _controller.documents;
    final recentDocuments = [...documents]
      ..sort((first, second) => second.updatedAt.compareTo(first.updatedAt));
    final favorites = documents.where((item) => item.isFavorite).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        112,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WelcomePanel(
                  greeting: _greeting,
                  creating: _creating,
                  onCreate: () => _createDocument(),
                  onCanvas: () => _createDocument(
                    title: 'Canvas sin título',
                    categoryId: 'ideas',
                    layoutType: WorkspaceLayoutType.canvas,
                  ),
                  onTemplates: () => context.go('/templates'),
                ),
                if (documents.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Continuar trabajando',
                    subtitle: recentDocuments.first.isCanvas
                        ? 'Retoma tu Canvas más reciente.'
                        : 'Retoma tu documento más reciente.',
                    actionLabel: 'Ver biblioteca',
                    onAction: () => context.go('/library'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ContinueCard(
                    document: recentDocuments.first,
                    onOpen: () => _open(recentDocuments.first),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(
                  title: 'Empieza a crear',
                  subtitle: 'Elige el espacio que mejor acompaña tu idea.',
                ),
                const SizedBox(height: AppSpacing.md),
                _QuickActions(
                  enabled: !_creating,
                  onDocument: () => _createDocument(),
                  onCanvas: () => _createDocument(
                    title: 'Canvas sin título',
                    categoryId: 'ideas',
                    layoutType: WorkspaceLayoutType.canvas,
                  ),
                  onQuickNote: () => _createDocument(
                    title: 'Nota rápida',
                    categoryId: 'personal',
                  ),
                  onTemplate: () => context.go('/templates'),
                ),
                if (documents.isEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  const _FirstDocumentInvitation(),
                ] else ...[
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Recientes',
                    subtitle: 'Tus ideas, justo donde las dejaste.',
                    actionLabel: 'Ver todos',
                    onAction: () => context.go('/recent'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DocumentCarousel(
                    documents: recentDocuments.take(6).toList(),
                    onAction: _onDocumentAction,
                    onOpen: _open,
                  ),
                  if (favorites.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    SectionHeader(
                      title: 'Favoritos',
                      subtitle: 'Acceso directo a lo que más importa.',
                      actionLabel: 'Ver todos',
                      onAction: () => context.go('/favorites'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _DocumentCarousel(
                      documents: favorites.take(6).toList(),
                      onAction: _onDocumentAction,
                      onOpen: _open,
                      useHero: false,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Tus categorías',
                    subtitle: 'Encuentra contenido por contexto.',
                    actionLabel: 'Explorar',
                    onAction: () => context.go('/tags'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _CategorySummary(documents: documents),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  Future<void> _createDocument({
    String title = '',
    String? categoryId,
    WorkspaceLayoutType layoutType = WorkspaceLayoutType.document,
  }) async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final document = await _starterDocuments.create(
        title: title,
        categoryId: categoryId,
        layoutType: layoutType,
      );
      if (mounted) context.go('/editor/${document.id}');
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _open(Document document) => context.go('/editor/${document.id}');

  Future<void> _onDocumentAction(
    Document document,
    DocumentCardAction action,
  ) async {
    try {
      switch (action) {
        case DocumentCardAction.open:
          _open(document);
        case DocumentCardAction.category:
          final selected = await showDocumentCategoryPicker(
            context,
            currentCategoryId: document.categoryId,
          );
          if (selected != null && selected != document.categoryId) {
            await widget.repository.updateDocument(
              document.copyWith(categoryId: selected),
            );
          }
        case DocumentCardAction.favorite:
          await _controller.toggleFavorite(document.id);
        case DocumentCardAction.pin:
          await _controller.togglePinned(document.id);
        case DocumentCardAction.trash:
          await _controller.moveToTrash(document.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Documento movido a la papelera'),
                action: SnackBarAction(
                  label: 'Deshacer',
                  onPressed: () => _controller.restoreDocument(document.id),
                ),
              ),
            );
          }
        case DocumentCardAction.restore:
        case DocumentCardAction.delete:
          break;
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('No se pudo completar la operación: $error')),
  );
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({
    required this.greeting,
    required this.creating,
    required this.onCreate,
    required this.onCanvas,
    required this.onTemplates,
  });

  final String greeting;
  final bool creating;
  final VoidCallback onCreate;
  final VoidCallback onCanvas;
  final VoidCallback onTemplates;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer,
            Color.alphaBlend(
              colors.tertiary.withValues(alpha: .18),
              colors.surfaceContainerLow,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Wrap(
        spacing: AppSpacing.xl,
        runSpacing: AppSpacing.lg,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '¿Qué quieres crear hoy?',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Captura una idea, organiza un proyecto o abre un espacio libre para explorar.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.onPrimaryContainer.withValues(alpha: .82),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilledButton.icon(
                      onPressed: creating ? null : onCreate,
                      icon: creating
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_rounded),
                      label: const Text('Nuevo documento'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: creating ? null : onCanvas,
                      icon: const Icon(Icons.dashboard_customize_outlined),
                      label: const Text('Nuevo Canvas'),
                    ),
                    TextButton.icon(
                      onPressed: onTemplates,
                      icon: const Icon(AppIcons.templates),
                      label: const Text('Explorar plantillas'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.enabled,
    required this.onDocument,
    required this.onCanvas,
    required this.onQuickNote,
    required this.onTemplate,
  });

  final bool enabled;
  final VoidCallback onDocument;
  final VoidCallback onCanvas;
  final VoidCallback onQuickNote;
  final VoidCallback onTemplate;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 4
          : constraints.maxWidth >= 520
          ? 2
          : 1;
      final width =
          (constraints.maxWidth - (columns - 1) * AppSpacing.sm) / columns;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          SizedBox(
            width: width,
            child: _QuickActionCard(
              icon: AppIcons.documents,
              title: 'Documento',
              subtitle: 'Escritura y bloques en flujo',
              color: Theme.of(context).colorScheme.primary,
              onTap: enabled ? onDocument : null,
            ),
          ),
          SizedBox(
            width: width,
            child: _QuickActionCard(
              icon: AppIcons.canvas,
              title: 'Canvas',
              subtitle: 'Ideas libres en un espacio amplio',
              color: Theme.of(context).colorScheme.tertiary,
              onTap: enabled ? onCanvas : null,
            ),
          ),
          SizedBox(
            width: width,
            child: _QuickActionCard(
              icon: AppIcons.quickNote,
              title: 'Nota rápida',
              subtitle: 'Captura algo sin perder tiempo',
              color: const Color(0xFFD4892F),
              onTap: enabled ? onQuickNote : null,
            ),
          ),
          SizedBox(
            width: width,
            child: _QuickActionCard(
              icon: AppIcons.templates,
              title: 'Plantilla',
              subtitle: 'Comienza con una estructura útil',
              color: const Color(0xFFC85D6A),
              onTap: onTemplate,
            ),
          ),
        ],
      );
    },
  );
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    ),
  );
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.document, required this.onOpen});

  final Document document;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final category = CategoryCatalog.resolve(document.categoryId);
    final preview = document.content.text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(
                  document.isCanvas
                      ? Icons.dashboard_customize_outlined
                      : category.icon,
                  color: category.color,
                  size: 30,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title.trim().isEmpty
                          ? document.isCanvas
                                ? 'Canvas sin título'
                                : 'Documento sin título'
                          : document.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      preview.isEmpty
                          ? 'Listo para empezar a escribir.'
                          : preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        Text(
                          document.isCanvas ? 'Canvas' : 'Documento',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: document.isCanvas
                                    ? Theme.of(context).colorScheme.tertiary
                                    : Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          category.name,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          'Editado ${_homeDate(document.updatedAt)}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              IconButton.filledTonal(
                tooltip: document.isCanvas
                    ? 'Continuar en Canvas'
                    : 'Continuar en documento',
                onPressed: onOpen,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentCarousel extends StatelessWidget {
  const _DocumentCarousel({
    required this.documents,
    required this.onAction,
    required this.onOpen,
    this.useHero = true,
  });

  final List<Document> documents;
  final Future<void> Function(Document, DocumentCardAction) onAction;
  final ValueChanged<Document> onOpen;
  final bool useHero;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 238,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: documents.length,
      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm + 4),
      itemBuilder: (context, index) {
        final document = documents[index];
        return SizedBox(
          width: 286,
          child: DocumentCard(
            document: document,
            useHero: useHero,
            onTap: () => onOpen(document),
            onAction: (action) => onAction(document, action),
          ),
        );
      },
    ),
  );
}

class _CategorySummary extends StatelessWidget {
  const _CategorySummary({required this.documents});

  final List<Document> documents;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      for (final category in CategoryCatalog.values)
        ActionChip(
          avatar: Icon(category.icon, size: 18, color: category.color),
          label: Text(
            '${category.name} · ${documents.where((item) => CategoryCatalog.resolve(item.categoryId).id == category.id).length}',
          ),
          onPressed: () => context.go('/category/${category.id}'),
        ),
    ],
  );
}

class _FirstDocumentInvitation extends StatelessWidget {
  const _FirstDocumentInvitation();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Column(
      children: [
        Icon(
          Icons.waving_hand_outlined,
          size: 40,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Tu espacio está listo',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Crea un Documento para escribir en orden o un Canvas para explorar libremente.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.md),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              Container(
                height: 260,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    ],
  );
}

String _homeDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')} · '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
