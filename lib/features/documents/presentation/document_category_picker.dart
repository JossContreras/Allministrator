import 'package:allministrator/app/theme/app_spacing.dart';
import 'package:allministrator/features/documents/presentation/category_catalog.dart';
import 'package:flutter/material.dart';

Future<String?> showDocumentCategoryPicker(
  BuildContext context, {
  String? currentCategoryId,
}) => showModalBottomSheet<String>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(
                'Elegir categoría',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final category in CategoryCatalog.values)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: category.color.withValues(alpha: .18),
                        child: Icon(
                          category.icon,
                          color: category.color,
                          size: 20,
                        ),
                      ),
                      title: Text(category.name),
                      trailing: currentCategoryId == category.id
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.pop(context, category.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
