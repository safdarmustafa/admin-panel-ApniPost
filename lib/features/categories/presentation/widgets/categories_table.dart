import 'package:apnipost_admin/core/utils/date_formatters.dart';
import 'package:apnipost_admin/features/categories/domain/category.dart';
import 'package:flutter/material.dart';

typedef CategoryAction = void Function(ContentCategory category);

class CategoriesTable extends StatelessWidget {
  const CategoriesTable({
    super.key,
    required this.categories,
    required this.canReorder,
    required this.isMutating,
    required this.onReorder,
    required this.onEdit,
    required this.onToggleShowOnHome,
    required this.onDelete,
  });

  final List<ContentCategory> categories;
  final bool canReorder;
  final bool isMutating;
  final void Function(int oldIndex, int newIndex) onReorder;
  final CategoryAction onEdit;
  final CategoryAction onToggleShowOnHome;
  final CategoryAction onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.45,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                SizedBox(width: 40),
                Expanded(flex: 3, child: Text('Category')),
                Expanded(child: Text('Content')),
                Expanded(child: Text('Show on Home')),
                Expanded(child: Text('Order')),
                Expanded(child: Text('Created')),
                SizedBox(width: 48, child: Text('Actions')),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: categories.length,
              onReorder: canReorder && !isMutating
                  ? onReorder
                  : (oldIndex, newIndex) {},
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final category = categories[index];
                return _CategoryRow(
                  key: ValueKey(category.id),
                  index: index,
                  category: category,
                  canReorder: canReorder && !isMutating,
                  onEdit: () => onEdit(category),
                  onToggleShowOnHome: () => onToggleShowOnHome(category),
                  onDelete: () => onDelete(category),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    super.key,
    required this.index,
    required this.category,
    required this.canReorder,
    required this.onEdit,
    required this.onToggleShowOnHome,
    required this.onDelete,
  });

  final int index;
  final ContentCategory category;
  final bool canReorder;
  final VoidCallback onEdit;
  final VoidCallback onToggleShowOnHome;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
            ),
          ),
          child: Row(
            children: [
              if (canReorder)
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.drag_indicator, size: 20),
                  ),
                )
              else
                const SizedBox(width: 28),
              Expanded(
                flex: 3,
                child: Text(
                  category.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(DateFormatters.compactCount(category.postCount)),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ShowOnHomeChip(showOnHome: category.showOnHome),
                ),
              ),
              Expanded(child: Text('${category.displayOrder}')),
              Expanded(
                child: Text(DateFormatters.mediumDate(category.createdAt)),
              ),
              SizedBox(
                width: 48,
                child: PopupMenuButton<_CategoryMenuAction>(
                  tooltip: 'Actions',
                  onSelected: (action) {
                    switch (action) {
                      case _CategoryMenuAction.edit:
                        onEdit();
                      case _CategoryMenuAction.toggleHome:
                        onToggleShowOnHome();
                      case _CategoryMenuAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _CategoryMenuAction.edit,
                      child: Text('Edit'),
                    ),
                    PopupMenuItem(
                      value: _CategoryMenuAction.toggleHome,
                      child: Text(
                        category.showOnHome
                            ? 'Hide from Home'
                            : 'Show on Home',
                      ),
                    ),
                    const PopupMenuItem(
                      value: _CategoryMenuAction.delete,
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CategoryMenuAction { edit, toggleHome, delete }

class _ShowOnHomeChip extends StatelessWidget {
  const _ShowOnHomeChip({required this.showOnHome});

  final bool showOnHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = showOnHome
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final foreground = showOnHome
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        showOnHome ? 'ON' : 'OFF',
        style: theme.textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
