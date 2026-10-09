import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone_category.dart';
import 'package:apnipost_admin/features/ringtones/presentation/ringtone_categories_controller.dart';
import 'package:apnipost_admin/features/ringtones/presentation/widgets/ringtone_categories_table.dart';
import 'package:apnipost_admin/features/ringtones/presentation/widgets/ringtone_category_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RingtoneCategoriesPage extends ConsumerWidget {
  const RingtoneCategoriesPage({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final state = ref.read(ringtoneCategoriesControllerProvider).asData?.value;
    if (state == null) return;

    final draft = await showRingtoneCategoryFormDialog(
      context: context,
      existingNames: state.names,
    );
    if (draft == null) return;

    await ref
        .read(ringtoneCategoriesControllerProvider.notifier)
        .createCategory(name: draft.name, hindiName: draft.hindiName);
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    RingtoneCategory category,
  ) async {
    final state = ref.read(ringtoneCategoriesControllerProvider).asData?.value;
    if (state == null) return;

    final draft = await showRingtoneCategoryFormDialog(
      context: context,
      existing: category,
      existingNames: state.names,
    );
    if (draft == null) return;
    if (draft.name == category.name && draft.hindiName == category.hindiName) {
      return;
    }

    await ref
        .read(ringtoneCategoriesControllerProvider.notifier)
        .updateCategory(
          category: category,
          name: draft.name,
          hindiName: draft.hindiName,
        );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    RingtoneCategory category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('Delete "${category.name}"? This cannot be undone.'),
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
    if (confirmed != true) return;

    await ref
        .read(ringtoneCategoriesControllerProvider.notifier)
        .deleteCategory(category);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(ringtoneCategoriesControllerProvider);
    final controller = ref.read(ringtoneCategoriesControllerProvider.notifier);
    final theme = Theme.of(context);

    ref.listen(ringtoneCategoriesControllerProvider, (previous, next) {
      final value = next.asData?.value;
      final message = value?.errorMessage ?? value?.successMessage;
      final previousValue = previous?.asData?.value;
      final previousMessage =
          previousValue?.errorMessage ?? previousValue?.successMessage;
      if (message != null && message.isNotEmpty && message != previousMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        controller.clearMessages();
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
                  'Categories on the app\'s Ringtones screen. Drag to set the '
                  'chip order. A category shows in the app once it has at '
                  'least one ringtone.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              if (asyncState.asData?.value.isMutating ?? false)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: controller.refresh,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: asyncState.asData == null
                    ? null
                    : () => _create(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Create Category'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: asyncState.when(
              skipLoadingOnRefresh: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error is AppFailure
                          ? error.message
                          : 'Unable to load categories. Please try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: controller.refresh,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
              data: (state) {
                if (state.categories.isEmpty) {
                  return Center(
                    child: Text(
                      'No ringtone categories yet. Create one to start '
                      'uploading ringtones.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return RingtoneCategoriesTable(
                  categories: state.categories,
                  isMutating: state.isMutating,
                  onReorder: controller.reorder,
                  onEdit: (category) => _edit(context, ref, category),
                  onDelete: (category) => _delete(context, ref, category),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
