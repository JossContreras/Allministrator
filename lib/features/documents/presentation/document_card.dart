import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:flutter/material.dart';
import 'category_catalog.dart';

enum DocumentCardAction {
  open,
  category,
  favorite,
  pin,
  trash,
  restore,
  delete,
}

class DocumentCard extends StatelessWidget {
  const DocumentCard({
    required this.document,
    required this.onAction,
    this.onTap,
    this.isTrash = false,
    this.isList = false,
    this.backgroundImage,
    super.key,
  });

  final Document document;
  final ValueChanged<DocumentCardAction> onAction;
  final VoidCallback? onTap;
  final bool isTrash;
  final bool isList;

  /// Optional local image layer reserved for a future document cover.
  final ImageProvider<Object>? backgroundImage;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.96, end: 1),
    duration: const Duration(milliseconds: 240),
    curve: Curves.easeOutCubic,
    builder: (context, scale, child) =>
        Transform.scale(scale: scale, child: child),
    child: Hero(
      tag: 'document-${document.id}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: isList ? _buildList(context) : _buildGrid(context),
        ),
      ),
    ),
  );

  Widget _buildGrid(BuildContext context) {
    final category = CategoryCatalog.resolve(document.categoryId);
    final surface = Color.alphaBlend(
      category.color.withValues(alpha: 0.16),
      Theme.of(context).colorScheme.surface,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              image: backgroundImage == null
                  ? null
                  : DecorationImage(
                      image: backgroundImage!,
                      fit: BoxFit.cover,
                      opacity: 0.22,
                    ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: _categoryLabel(context, category),
                ),
                const Spacer(),
                Center(
                  child: Text(
                    _title,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        _footer(context),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    final category = CategoryCatalog.resolve(document.categoryId);
    final surface = Color.alphaBlend(
      category.color.withValues(alpha: 0.08),
      Theme.of(context).colorScheme.surface,
    );
    return SizedBox(
      height: 82,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatDate(document.updatedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          Container(
            color: surface,
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _categoryLabel(context, category, compact: true),
                _statusIcons(context),
                _menuButton(),
              ],
            ),
          ),
          Container(width: 6, color: category.color),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 16, right: 4, bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _formatDate(document.updatedAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        _statusIcons(context),
        _menuButton(),
      ],
    ),
  );

  Widget _categoryLabel(
    BuildContext context,
    CategoryVisual category, {
    bool compact = false,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: category.color,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      if (!compact)
        Flexible(
          child: Text(
            category.name,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      if (compact)
        Text(category.name, style: Theme.of(context).textTheme.labelMedium),
    ],
  );

  Widget _statusIcons(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AnimatedScale(
        scale: document.isFavorite ? 1 : 0.65,
        duration: const Duration(milliseconds: 180),
        child: Icon(
          document.isFavorite ? Icons.star : Icons.star_border,
          size: 17,
          color: document.isFavorite
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
        ),
      ),
      AnimatedRotation(
        turns: document.isPinned ? 0 : -0.04,
        duration: const Duration(milliseconds: 180),
        child: Icon(
          Icons.push_pin,
          size: 17,
          color: document.isPinned ? null : Colors.transparent,
        ),
      ),
    ],
  );

  PopupMenuButton<DocumentCardAction> _menuButton() =>
      PopupMenuButton<DocumentCardAction>(
        tooltip: 'Más opciones',
        onSelected: onAction,
        itemBuilder: (_) => isTrash
            ? const [
                PopupMenuItem(
                  value: DocumentCardAction.restore,
                  child: ListTile(
                    leading: Icon(Icons.restore),
                    title: Text('Restaurar'),
                  ),
                ),
                PopupMenuItem(
                  value: DocumentCardAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_forever),
                    title: Text('Eliminar permanentemente'),
                  ),
                ),
              ]
            : [
                const PopupMenuItem(
                  value: DocumentCardAction.open,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Abrir'),
                  ),
                ),
                const PopupMenuItem(
                  value: DocumentCardAction.category,
                  child: ListTile(
                    leading: Icon(Icons.palette_outlined),
                    title: Text('Cambiar categoría'),
                  ),
                ),
                PopupMenuItem(
                  value: DocumentCardAction.favorite,
                  child: ListTile(
                    leading: const Icon(Icons.star_outline),
                    title: Text(
                      document.isFavorite
                          ? 'Quitar de favoritos'
                          : 'Marcar como favorito',
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: DocumentCardAction.pin,
                  child: ListTile(
                    leading: const Icon(Icons.push_pin_outlined),
                    title: Text(document.isPinned ? 'Desfijar' : 'Fijar'),
                  ),
                ),
                const PopupMenuItem(
                  value: DocumentCardAction.trash,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Mover a papelera'),
                  ),
                ),
              ],
        icon: const Icon(Icons.more_vert),
      );

  String get _title =>
      document.title.trim().isEmpty ? 'Documento sin título' : document.title;
  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
