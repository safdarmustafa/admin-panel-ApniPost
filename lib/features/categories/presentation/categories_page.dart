import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/features/categories/domain/category.dart';
import 'package:apnipost_admin/features/categories/presentation/categories_controller.dart';
import 'package:apnipost_admin/features/categories/presentation/widgets/categories_table.dart';
import 'package:apnipost_admin/features/categories/presentation/widgets/category_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final state = ref.read(categoriesControllerProvider).asData?.value;
    if (state == null) return;

    final nextOrder = state.categories.isEmpty
        ? 0
        : state.categories
                .map((c) => c.displayOrder)
                .reduce((a, b) => a > b ? a : b) +
            1;

    final draft = await showCategoryFormDialog(
      context: context,
      existingNames: state.categories.map((c) => c.name),
      suggestedDisplayOrder: nextOrder,
    );
    if (draft == null || !context.mounted) return;

    final ok = await ref.read(categoriesControllerProvider.notifier).createCategory(
          name: draft.name,
          displayOrder: draft.displayOrder,
          showOnHome: draft.showOnHome,
        );
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ContentCategory created.')),
      );
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ContentCategory category,
  ) async {
    final state = ref.read(categoriesControllerProvider).asData?.value;
    if (state == null) return;

    final draft = await showCategoryFormDialog(
      context: context,
      existing: category,
      existingNames: state.categories.map((c) => c.name),
    );
    if (draft == null || !context.mounted) return;

    final ok = await ref.read(categoriesControllerProvider.notifier).updateCategory(
          category: category,
          name: draft.name,
          displayOrder: draft.displayOrder,
          showOnHome: draft.showOnHome,
        );
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ContentCategory updated.')),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ContentCategory category,
  ) async {
    final controller = ref.read(categoriesControllerProvider.notifier);
    final blockReason = await controller.deletionBlockReason(category);
    if (!context.mounted) return;

    if (blockReason != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot delete category'),
          content: Text(blockReason),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Delete "${category.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ok = await controller.deleteCategory(category);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ContentCategory deleted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(categoriesControllerProvider);
    final theme = Theme.of(context);

    ref.listen(categoriesControllerProvider, (previous, next) {
      final message = next.asData?.value.errorMessage;
      if (message != null &&
          message.isNotEmpty &&
          message != previous?.asData?.value.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        ref.read(categoriesControllerProvider.notifier).clearMessages();
      }
    });

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Manage content categories used by the ApniPost Android app.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: asyncState.isLoading
                    ? null
                    : () => _create(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Create Category'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          asyncState.when(
            loading: () => const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Expanded(
              child: _ErrorState(
                message: error is AppFailure
                    ? error.message
                    : 'Unable to load categories. Please try again.',
                onRetry: () =>
                    ref.read(categoriesControllerProvider.notifier).refresh(),
              ),
            ),
            data: (state) {
              if (state.isEmpty) {
                return Expanded(
                  child: _EmptyState(onCreate: () => _create(context, ref)),
                );
              }

              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: TextField(
                            onChanged: (value) => ref
                                .read(categoriesControllerProvider.notifier)
                                .setSearchQuery(value),
                            decoration: InputDecoration(
                              hintText: 'Search categories...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: state.searchQuery.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () => ref
                                          .read(
                                            categoriesControllerProvider
                                                .notifier,
                                          )
                                          .setSearchQuery(''),
                                      icon: const Icon(Icons.clear),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (state.isMutating)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        const Spacer(),
                        Text(
                          '${state.filtered.length} of ${state.categories.length}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: () => ref
                              .read(categoriesControllerProvider.notifier)
                              .refresh(),
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    if (state.searchQuery.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Clear search to reorder categories by drag-and-drop.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (state.filtered.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            'No categories match your search.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: CategoriesTable(
                          categories: state.filtered,
                          canReorder: state.searchQuery.trim().isEmpty,
                          isMutating: state.isMutating,
                          onReorder: (oldIndex, newIndex) {
                            ref
                                .read(categoriesControllerProvider.notifier)
                                .reorder(oldIndex, newIndex);
                          },
                          onEdit: (category) => _edit(context, ref, category),
                          onToggleShowOnHome: (category) {
                            ref
                                .read(categoriesControllerProvider.notifier)
                                .toggleShowOnHome(category);
                          },
                          onDelete: (category) =>
                              _delete(context, ref, category),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No categories yet',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first category to organize ApniPost content.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Category'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 40,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to load categories',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
