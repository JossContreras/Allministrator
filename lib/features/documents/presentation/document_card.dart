import 'dart:math' as math;

import 'package:allministrator/app/theme/app_icons.dart';
import 'package:allministrator/app/theme/app_motion.dart';
import 'package:allministrator/app/theme/app_radius.dart';
import 'package:allministrator/app/theme/app_spacing.dart';
import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/entities/canvas_layout.dart';
import 'package:allministrator/domain/ink/ink_models.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';
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

enum DocumentCardStyle { regular, featured, compact, canvasPreview }

class DocumentCard extends StatelessWidget {
  const DocumentCard({
    required this.document,
    required this.onAction,
    this.onTap,
    this.isTrash = false,
    this.isList = false,
    this.style = DocumentCardStyle.regular,
    this.useHero = true,
    this.backgroundImage,
    super.key,
  });

  final Document document;
  final ValueChanged<DocumentCardAction> onAction;
  final VoidCallback? onTap;
  final bool isTrash;
  final bool isList;
  final DocumentCardStyle style;
  final bool useHero;

  /// Optional local image layer reserved for a future document cover.
  final ImageProvider<Object>? backgroundImage;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: isList
            ? _buildList(context)
            : switch (style) {
                DocumentCardStyle.regular => _buildGrid(context),
                DocumentCardStyle.featured => _buildFeatured(context),
                DocumentCardStyle.compact => _buildCompact(context),
                DocumentCardStyle.canvasPreview => _buildCanvas(context),
              },
      ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1),
      duration: AppMotion.normal,
      curve: AppMotion.enter,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: useHero ? Hero(tag: 'document-${document.id}', child: card) : card,
    );
  }

  Widget _buildGrid(BuildContext context) {
    final category = CategoryCatalog.resolve(document.categoryId);
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 205 || constraints.maxWidth < 210;
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.alphaBlend(
                        category.color.withValues(alpha: .30),
                        colorScheme.surface,
                      ),
                      Color.alphaBlend(
                        category.color.withValues(alpha: .08),
                        colorScheme.surface,
                      ),
                    ],
                  ),
                  image: backgroundImage == null
                      ? null
                      : DecorationImage(
                          image: backgroundImage!,
                          fit: BoxFit.cover,
                          opacity: .16,
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: compact ? 30 : 34,
                        height: compact ? 30 : 34,
                        decoration: BoxDecoration(
                          color: _contentColor.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: Icon(
                          _contentIcon(category),
                          size: compact ? 16 : 18,
                          color: _contentColor,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _title,
                          maxLines: compact ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                        ),
                      ),
                      _menuButton(),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Expanded(
                    child: Text(
                      _preview,
                      maxLines: compact ? 3 : 5,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(child: _categoryChip(context, category)),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.schedule,
                        size: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          _formatDateTime(document.updatedAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Divider(height: 1),
                  SizedBox(
                    height: 38,
                    child: Row(
                      children: [
                        Expanded(
                          child: _quickAction(
                            context,
                            tooltip: document.isCanvas
                                ? 'Abrir Canvas'
                                : 'Abrir documento',
                            icon: Icons.arrow_forward_rounded,
                            onPressed: () => onAction(DocumentCardAction.open),
                          ),
                        ),
                        Expanded(
                          child: _quickAction(
                            context,
                            tooltip: document.isFavorite
                                ? 'Quitar de favoritos'
                                : 'Marcar como favorito',
                            icon: document.isFavorite
                                ? Icons.star
                                : Icons.star_border,
                            active: document.isFavorite,
                            onPressed: () =>
                                onAction(DocumentCardAction.favorite),
                          ),
                        ),
                        Expanded(
                          child: _quickAction(
                            context,
                            tooltip: document.isPinned ? 'Desfijar' : 'Fijar',
                            icon: document.isPinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            active: document.isPinned,
                            onPressed: () => onAction(DocumentCardAction.pin),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeatured(BuildContext context) {
    final category = CategoryCatalog.resolve(document.categoryId);
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    category.color.withValues(alpha: .24),
                    colors.surfaceContainerLowest,
                  ),
                  colors.surfaceContainerLowest,
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _categoryChip(context, category),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _metadataBadge(context, Icons.article_outlined, 'Destacado'),
                  _menuButton(),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Text(
                  _preview,
                  maxLines: 7,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.48,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Editado ${_formatDateTime(document.updatedAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _quickAction(
                    context,
                    tooltip: document.isFavorite
                        ? 'Quitar de favoritos'
                        : 'Marcar como favorito',
                    icon: document.isFavorite ? Icons.star : Icons.star_border,
                    active: document.isFavorite,
                    onPressed: () => onAction(DocumentCardAction.favorite),
                  ),
                  _quickAction(
                    context,
                    tooltip: document.isPinned ? 'Desfijar' : 'Fijar',
                    icon: document.isPinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                    active: document.isPinned,
                    onPressed: () => onAction(DocumentCardAction.pin),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _quickAction(
                    context,
                    tooltip: 'Abrir documento',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () => onAction(DocumentCardAction.open),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    final category = CategoryCatalog.resolve(document.categoryId);
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 5,
          child: ColoredBox(color: _contentColor),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm + 2,
            AppSpacing.sm + 4,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_contentIcon(category), size: 19, color: _contentColor),
                  const Spacer(),
                  _menuButton(),
                ],
              ),
              Text(
                _title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: Text(
                  _preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(child: _categoryChip(context, category)),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _formatDate(document.updatedAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCanvas(BuildContext context) {
    final category = CategoryCatalog.resolve(document.categoryId);
    final colors = Theme.of(context).colorScheme;
    final page = document.content.workspace.primaryPage;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Icon(
                  Icons.dashboard_customize_outlined,
                  color: colors.onTertiaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${category.name} · Editado ${_formatDateTime(document.updatedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _menuButton(),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _CanvasDocumentPreview(
              document: document,
              accent: category.color,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _metadataBadge(
                    context,
                    Icons.widgets_outlined,
                    '${page.blocks.length} ${page.blocks.length == 1 ? 'bloque' : 'bloques'} · '
                    '${page.inkLayer.elements.length} ${page.inkLayer.elements.length == 1 ? 'trazo' : 'trazos'}',
                  ),
                ),
              ),
              if (isTrash) ...[
                _quickAction(
                  context,
                  tooltip: 'Restaurar Canvas',
                  icon: Icons.restore_rounded,
                  onPressed: () => onAction(DocumentCardAction.restore),
                ),
                _quickAction(
                  context,
                  tooltip: 'Eliminar permanentemente',
                  icon: Icons.delete_forever_outlined,
                  onPressed: () => onAction(DocumentCardAction.delete),
                ),
              ] else ...[
                _quickAction(
                  context,
                  tooltip: document.isFavorite
                      ? 'Quitar de favoritos'
                      : 'Marcar como favorito',
                  icon: document.isFavorite ? Icons.star : Icons.star_border,
                  active: document.isFavorite,
                  onPressed: () => onAction(DocumentCardAction.favorite),
                ),
                _quickAction(
                  context,
                  tooltip: 'Abrir Canvas',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => onAction(DocumentCardAction.open),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _metadataBadge(BuildContext context, IconData icon, String label) =>
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      );

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
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: CircleAvatar(
              backgroundColor: _contentColor.withValues(alpha: .14),
              foregroundColor: _contentColor,
              child: Icon(_contentIcon(category), size: 19),
            ),
          ),
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
        ],
      ),
    );
  }

  Widget _quickAction(
    BuildContext context, {
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    bool active = false,
  }) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    onPressed: onPressed,
    color: active ? CategoryCatalog.resolve(document.categoryId).color : null,
    icon: Icon(icon, size: 20),
  );

  Widget _categoryChip(BuildContext context, CategoryVisual category) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: category.color.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: category.color.withValues(alpha: .35)),
        ),
        child: Text(
          category.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: category.color,
            fontWeight: FontWeight.w700,
          ),
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
        duration: AppMotion.fast,
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
        duration: AppMotion.fast,
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
        icon: const Icon(AppIcons.more),
      );

  String get _title => document.title.trim().isEmpty
      ? document.isCanvas
            ? 'Canvas sin título'
            : 'Documento sin título'
      : document.title;

  IconData _contentIcon(
    CategoryVisual category,
  ) => switch (document.sourceFormat) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'doc' || 'docx' => Icons.description_outlined,
    'md' || 'markdown' => Icons.code_outlined,
    'txt' => Icons.text_snippet_outlined,
    'jpg' || 'jpeg' || 'png' || 'webp' || 'gif' => Icons.image_outlined,
    'mp4' || 'mov' || 'm4v' || 'webm' => Icons.video_file_outlined,
    'dart' ||
    'py' ||
    'js' ||
    'ts' ||
    'html' ||
    'css' ||
    'java' ||
    'c' ||
    'cpp' ||
    'json' ||
    'sql' => Icons.data_object,
    _ => document.isCanvas ? Icons.dashboard_customize_outlined : category.icon,
  };

  Color get _contentColor => switch (document.sourceFormat) {
    'pdf' => const Color(0xFFD13D3D),
    'doc' || 'docx' => const Color(0xFF2B579A),
    'md' || 'markdown' => const Color(0xFF4F5963),
    'txt' => const Color(0xFF607D8B),
    'jpg' || 'jpeg' || 'png' || 'webp' || 'gif' => const Color(0xFF8E5BB7),
    'mp4' || 'mov' || 'm4v' || 'webm' => const Color(0xFFE06A3B),
    'dart' ||
    'py' ||
    'js' ||
    'ts' ||
    'html' ||
    'css' ||
    'java' ||
    'c' ||
    'cpp' ||
    'json' ||
    'sql' => const Color(0xFF19786F),
    _ => CategoryCatalog.resolve(document.categoryId).color,
  };
  String get _preview {
    final value = document.content.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value.isEmpty
        ? document.isCanvas
              ? 'Canvas vacío. Mantén presionado para insertar un bloque.'
              : 'Documento vacío. Toca para comenzar a escribir.'
        : value;
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  String _formatDateTime(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
      '· ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _CanvasDocumentPreview extends StatelessWidget {
  const _CanvasDocumentPreview({required this.document, required this.accent});

  final Document document;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final page = document.content.workspace.primaryPage;
    final empty = page.blocks.isEmpty && page.inkLayer.elements.isEmpty;
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            accent.withValues(alpha: .05),
            colors.surfaceContainerLow,
          ),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _CanvasPreviewPainter(
                document: document,
                colorScheme: colors,
                accent: accent,
              ),
            ),
            if (empty)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Lienzo listo para empezar',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CanvasPreviewPainter extends CustomPainter {
  const _CanvasPreviewPainter({
    required this.document,
    required this.colorScheme,
    required this.accent,
  });

  final Document document;
  final ColorScheme colorScheme;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    final page = document.content.workspace.primaryPage;
    final layout =
        (page.canvasLayout ?? CanvasLayoutState.forBlocks(page.blocks))
            .normalizedFor(page.blocks);
    final visibleInk = page.inkLayer.elements
        .where((element) => element.isVisible)
        .toList();
    if (layout.placements.isEmpty && visibleInk.isEmpty) return;

    final bounds = _contentBounds(layout, visibleInk);
    final availableWidth = math.max(1.0, size.width - 32);
    final availableHeight = math.max(1.0, size.height - 24);
    final scale = math
        .min(
          availableWidth / math.max(bounds.width, 1),
          availableHeight / math.max(bounds.height, 1),
        )
        .clamp(.025, 1.25)
        .toDouble();
    final contentWidth = bounds.width * scale;
    final contentHeight = bounds.height * scale;
    final origin = Offset(
      (size.width - contentWidth) / 2 - bounds.left * scale,
      (size.height - contentHeight) / 2 - bounds.top * scale,
    );
    Offset mapPoint(SpatialPoint point) =>
        Offset(origin.dx + point.x * scale, origin.dy + point.y * scale);

    final placements = {
      for (final item in layout.placements) item.blockId: item,
    };
    final connectorPaint = Paint()
      ..color = colorScheme.outline.withValues(alpha: .48)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (final connector in layout.connectors) {
      final source = placements[connector.sourceBlockId];
      final target = placements[connector.targetBlockId];
      if (source == null || target == null) continue;
      canvas.drawLine(
        mapPoint(source.bounds().center),
        mapPoint(target.bounds().center),
        connectorPaint,
      );
    }

    final blocks = {for (final block in page.blocks) block.id: block};
    final ordered = [...layout.placements]
      ..sort((first, second) => first.zIndex.compareTo(second.zIndex));
    for (final placement in ordered) {
      final block = blocks[placement.blockId];
      if (block == null || !block.isVisible) continue;
      _paintBlock(canvas, placement, block, origin, scale);
    }
    for (final element in visibleInk) {
      _paintInk(canvas, element, mapPoint, scale);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: .42)
      ..strokeWidth = 1;
    const gap = 22.0;
    for (var x = gap / 2; x < size.width; x += gap) {
      for (var y = gap / 2; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), .75, paint);
      }
    }
  }

  SpatialRect _contentBounds(CanvasLayoutState layout, List<InkElement> ink) {
    final values = <SpatialRect>[
      for (final placement in layout.placements)
        placement.bounds(fallbackHeight: 132),
      for (final frame in layout.frames) frame.bounds,
      for (final element in ink) element.bounds,
    ];
    if (values.isEmpty) return const SpatialRect.fromLTWH(0, 0, 800, 500);
    var left = values.first.left;
    var top = values.first.top;
    var right = values.first.right;
    var bottom = values.first.bottom;
    for (final value in values.skip(1)) {
      left = math.min(left, value.left);
      top = math.min(top, value.top);
      right = math.max(right, value.right);
      bottom = math.max(bottom, value.bottom);
    }
    return SpatialRect.fromLTRB(left - 36, top - 36, right + 36, bottom + 36);
  }

  void _paintBlock(
    Canvas canvas,
    CanvasPlacement placement,
    BaseBlock block,
    Offset origin,
    double scale,
  ) {
    final source = placement.bounds(fallbackHeight: 132);
    final rect = Rect.fromLTWH(
      origin.dx + source.left * scale,
      origin.dy + source.top * scale,
      math.max(24, source.width * scale),
      math.max(16, source.height * scale),
    );
    if (rect.width < 46 || rect.height < 18) return;
    final label = _blockLabel(block);
    if (label.isEmpty) return;
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: (11 * scale).clamp(7, 12),
          fontWeight: block is TextBlock ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      maxLines: 2,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(1, rect.width));
    // The preview intentionally renders the content itself, without showing
    // editor block frames, handles or colored type rails.
    textPainter.paint(canvas, Offset(rect.left, rect.top));
  }

  void _paintInk(
    Canvas canvas,
    InkElement element,
    Offset Function(SpatialPoint) mapPoint,
    double scale,
  ) {
    final paint = Paint()
      ..color = Color(
        element.brush.color,
      ).withValues(alpha: element.brush.opacity.clamp(.12, 1))
      ..strokeWidth = (element.brush.baseWidth * scale).clamp(.8, 5)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    if (element is InkStroke && element.points.length >= 2) {
      final path = Path()
        ..moveTo(
          mapPoint(element.points.first.workspacePosition).dx,
          mapPoint(element.points.first.workspacePosition).dy,
        );
      for (final point in element.points.skip(1)) {
        final mapped = mapPoint(point.workspacePosition);
        path.lineTo(mapped.dx, mapped.dy);
      }
      canvas.drawPath(path, paint);
      return;
    }
    if (element is! InkShape) return;
    final start = mapPoint(element.start);
    final end = mapPoint(element.end);
    final rect = Rect.fromPoints(start, end);
    switch (element.kind) {
      case InkShapeKind.rectangle:
        canvas.drawRect(rect, paint);
      case InkShapeKind.ellipse:
        canvas.drawOval(rect, paint);
      case InkShapeKind.line:
      case InkShapeKind.arrow:
        canvas.drawLine(start, end, paint);
    }
  }

  String _blockLabel(BaseBlock block) => switch (block) {
    TextBlock() => block.plainText.trim(),
    ChecklistBlock() => block.items.map((item) => item.text).join(' · '),
    CodeBlock() => block.caption ?? block.code,
    CalloutBlock() => [
      if (block.title != null) block.title!,
      block.text,
    ].join(' · '),
    QuoteBlock() => block.text,
    TableBlock() =>
      block.rows
          .expand((row) => row.cells)
          .map((cell) => cell.text)
          .where((text) => text.isNotEmpty)
          .take(3)
          .join(' · '),
    ImageBlock() => block.caption ?? block.altText ?? 'Imagen',
    AttachmentBlock() => block.displayName,
    DividerBlock() => '',
    UnknownBlock() => block.originalType,
  };

  @override
  bool shouldRepaint(covariant _CanvasPreviewPainter oldDelegate) =>
      oldDelegate.document.id != document.id ||
      oldDelegate.document.version != document.version ||
      oldDelegate.colorScheme != colorScheme ||
      oldDelegate.accent != accent;
}
