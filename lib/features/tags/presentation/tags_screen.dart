import 'package:allministrator/app/theme/app_radius.dart';
import 'package:allministrator/app/theme/app_spacing.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/documents/presentation/category_catalog.dart';
import 'package:allministrator/features/documents/presentation/documents_screen.dart';
import 'package:allministrator/features/shared/presentation/main_navigation_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TagsScreen extends StatefulWidget {
  const TagsScreen({required this.repository, super.key});

  final DocumentRepository repository;

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  late final DocumentsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DocumentsController(
      widget.repository,
      DocumentsBrowserFilter.active,
    );
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
      title: 'Categorías',
      selectedPath: '/tags',
      child: _controller.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Encuentra cada idea por su contexto',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Las categorías utilizan los datos reales de tus documentos y funcionan como filtros rápidos.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        LayoutBuilder(
                          builder: (context, constraints) => GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: CategoryCatalog.values.length,
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: constraints.maxWidth < 420
                                      ? 420
                                      : 330,
                                  mainAxisExtent: 190,
                                  crossAxisSpacing: AppSpacing.md,
                                  mainAxisSpacing: AppSpacing.md,
                                ),
                            itemBuilder: (context, index) {
                              final category = CategoryCatalog.values[index];
                              final documents = _controller.documents
                                  .where(
                                    (document) =>
                                        CategoryCatalog.resolve(
                                          document.categoryId,
                                        ).id ==
                                        category.id,
                                  )
                                  .toList();
                              return _CategoryCard(
                                category: category,
                                documents: documents,
                                onTap: () =>
                                    context.go('/category/${category.id}'),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    ),
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.documents,
    required this.onTap,
  });

  final CategoryVisual category;
  final List<Document> documents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                category.color.withValues(alpha: .18),
                category.color.withValues(alpha: .04),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Icon(category.icon, color: category.color),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, color: category.color),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                category.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${documents.where((item) => item.isDocument).length} documentos · ${documents.where((item) => item.isCanvas).length} Canvas',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: category.color),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                documents.isEmpty
                    ? 'Aún no hay contenido en esta categoría.'
                    : documents
                          .take(2)
                          .map(
                            (item) => item.title.trim().isEmpty
                                ? 'Documento sin título'
                                : item.title,
                          )
                          .join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
