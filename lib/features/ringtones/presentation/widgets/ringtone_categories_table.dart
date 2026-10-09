import 'package:apnipost_admin/core/utils/date_formatters.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone_category.dart';
import 'package:flutter/material.dart';

typedef RingtoneCategoryAction = void Function(RingtoneCategory category);

/// Drag-to-reorder table; the order is the app's chip order.
class RingtoneCategoriesTable extends StatelessWidget {
  const RingtoneCategoriesTable({
    super.key,
    required this.categories,
    required this.isMutating,
    required this.onReorder,
    required this.onEdit,
    required this.onDelete,
  });

  final List<RingtoneCategory> categories;
  final bool isMutating;
  final void Function(int oldIndex, int newIndex) onReorder;
  final RingtoneCategoryAction onEdit;
  final RingtoneCategoryAction onDelete;

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
                Expanded(flex: 2, child: Text('Category')),
                Expanded(flex: 2, child: Text('Hindi name (app)')),
                Expanded(child: Text('Ringtones')),
                Expanded(child: Text('Order')),
                Expanded(child: Text('Created')),
                SizedBox(width: 96, child: Text('Actions')),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: categories.length,
              onReorder: isMutating ? (oldIndex, newIndex) {} : onReorder,
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
                  enabled: !isMutating,
                  onEdit: () => onEdit(category),
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
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final RingtoneCategory category;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: enabled ? onEdit : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.6),
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: enabled
                    ? ReorderableDragStartListener(
                        index: index,
                        child: const MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: Icon(Icons.drag_indicator),
                        ),
                      )
                    : const Icon(Icons.drag_indicator, color: Colors.black26),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  category.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  category.hindiName ?? '— (shows English name)',
                  overflow: TextOverflow.ellipsis,
                  style: category.hindiName == null ? muted : null,
                ),
              ),
              Expanded(
                child: Text(
                  category.ringtoneCount == 0
                      ? '0 · hidden in app'
                      : '${category.ringtoneCount}',
                  style: category.ringtoneCount == 0 ? muted : null,
                ),
              ),
              Expanded(child: Text('${category.displayOrder}')),
              Expanded(
                child: Text(DateFormatters.relativeDate(category.createdAt)),
              ),
              SizedBox(
                width: 96,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: enabled ? onEdit : null,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: category.ringtoneCount > 0
                          ? 'Has ringtones; cannot delete'
                          : 'Delete',
                      onPressed:
                          enabled && category.ringtoneCount == 0 ? onDelete : null,
                      icon: Icon(
                        Icons.delete_outline,
                        color: enabled && category.ringtoneCount == 0
                            ? theme.colorScheme.error
                            : null,
                      ),
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
