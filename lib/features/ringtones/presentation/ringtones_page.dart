import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone_category.dart';
import 'package:apnipost_admin/features/ringtones/presentation/ringtone_categories_controller.dart';
import 'package:apnipost_admin/features/ringtones/presentation/ringtones_controller.dart';
import 'package:apnipost_admin/features/ringtones/presentation/widgets/ringtone_edit_dialog.dart';
import 'package:apnipost_admin/features/ringtones/presentation/widgets/ringtone_upload_dialog.dart';
import 'package:apnipost_admin/features/ringtones/presentation/widgets/ringtones_table.dart';
import 'package:apnipost_admin/shared/web/web_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RingtonesPage extends ConsumerStatefulWidget {
  const RingtonesPage({super.key});

  @override
  ConsumerState<RingtonesPage> createState() => _RingtonesPageState();
}

class _RingtonesPageState extends ConsumerState<RingtonesPage> {
  @override
  void dispose() {
    AudioPreviewPlayer.instance.stop();
    super.dispose();
  }

  RingtonesController get _controller =>
      ref.read(ringtonesControllerProvider.notifier);

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Categories from `ringtone_categories`, or null (with a message) when
  /// they are not loaded or none exist yet.
  List<RingtoneCategory>? _categoriesOrWarn() {
    final categories = ref
        .read(ringtoneCategoriesControllerProvider)
        .asData
        ?.value
        .categories;
    if (categories == null) {
      _snack('Categories are still loading. Try again in a moment.');
      return null;
    }
    if (categories.isEmpty) {
      _snack('Create a category on the Ringtone Categories page first.');
      return null;
    }
    return categories;
  }

  Future<void> _upload() async {
    final categories = _categoriesOrWarn();
    if (categories == null) return;
    AudioPreviewPlayer.instance.stop();

    final count = await showRingtoneUploadDialog(
      context: context,
      categories: categories,
      upload: _controller.upload,
    );
    if (count > 0 && mounted) {
      // Ringtone counts per category changed.
      ref.invalidate(ringtoneCategoriesControllerProvider);
      _snack('$count ringtone${count == 1 ? '' : 's'} uploaded.');
    }
  }

  Future<void> _edit(Ringtone ringtone) async {
    final categories = _categoriesOrWarn();
    if (categories == null) return;

    final result = await showRingtoneEditDialog(
      context: context,
      ringtone: ringtone,
      categories: categories,
    );
    if (result == null || !mounted) return;
    if (result.title == ringtone.title && result.category == ringtone.category) {
      return;
    }

    await _controller.updateRingtone(
      ringtone: ringtone,
      title: result.title,
      category: result.category,
    );
  }

  Future<void> _delete(Ringtone ringtone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete ringtone?'),
        content: Text(
          'Delete "${ringtone.title}"? It disappears from the app and its '
          'file is removed from storage. People who already set it keep '
          'their copy. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    AudioPreviewPlayer.instance.stopIfPlaying(ringtone.audioUrl);
    await _controller.deleteRingtone(ringtone);
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(ringtonesControllerProvider);
    final categories =
        ref.watch(ringtoneCategoriesControllerProvider).asData?.value.categories ??
            const <RingtoneCategory>[];
    final theme = Theme.of(context);

    ref.listen(ringtonesControllerProvider, (previous, next) {
      final value = next.asData?.value;
      final message = value?.errorMessage ?? value?.successMessage;
      final previousValue = previous?.asData?.value;
      final previousMessage =
          previousValue?.errorMessage ?? previousValue?.successMessage;
      if (message != null && message.isNotEmpty && message != previousMessage) {
        _snack(message);
        _controller.clearMessages();
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
                  'Ringtones shown on the ApniPost app\'s Ringtones screen. '
                  'New uploads appear in the app the next time it opens the '
                  'screen.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: asyncState.asData == null ? null : _upload,
                icon: const Icon(Icons.upload),
                label: const Text('Upload ringtones'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          asyncState.when(
            skipLoadingOnRefresh: false,
            loading: () => const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Expanded(
              child: _MessageCard(
                icon: Icons.error_outline,
                title: 'Unable to load ringtones',
                message: error is AppFailure
                    ? error.message
                    : 'Please try again.',
                actionLabel: 'Try again',
                onAction: _controller.refresh,
              ),
            ),
            data: (state) {
              if (state.ringtones.isEmpty) {
                return Expanded(
                  child: _MessageCard(
                    icon: Icons.music_note_outlined,
                    title: 'No ringtones yet',
                    message: 'Upload ringtones to show them in the app.',
                    actionLabel: 'Upload ringtones',
                    onAction: _upload,
                  ),
                );
              }

              final filtered = state.filtered;
              final counts = state.countsByCategory;
              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: Text('All (${state.ringtones.length})'),
                                selected: state.categoryFilter == null,
                                onSelected: (_) =>
                                    _controller.setCategoryFilter(null),
                              ),
                              // Same order as the app's chips.
                              for (final category in categories)
                                ChoiceChip(
                                  label: Text(
                                    '${category.label} '
                                    '(${counts[category.name] ?? 0})',
                                  ),
                                  selected:
                                      state.categoryFilter == category.name,
                                  onSelected: (_) => _controller
                                      .setCategoryFilter(category.name),
                                ),
                            ],
                          ),
                        ),
                        if (state.isMutating)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: _controller.refresh,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No ringtones in this category.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : RingtonesTable(
                              ringtones: filtered,
                              isMutating: state.isMutating,
                              onEdit: _edit,
                              onDelete: _delete,
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

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

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
                Icon(icon, size: 40, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  title,
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
                FilledButton(onPressed: onAction, child: Text(actionLabel)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
