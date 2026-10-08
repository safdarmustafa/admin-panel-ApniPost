import 'package:apnipost_admin/core/utils/date_formatters.dart';
import 'package:apnipost_admin/features/content/domain/content_post.dart';
import 'package:apnipost_admin/shared/web/web_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Searchable single-choice category picker. Returns the chosen name.
Future<String?> showMoveToCategoryDialog(
  BuildContext context, {
  required List<String> categories,
  required int postCount,
  String? currentCategory,
  String? title,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _MoveDialog(
      categories: categories,
      postCount: postCount,
      currentCategory: currentCategory,
      title: title,
    ),
  );
}

class _MoveDialog extends StatefulWidget {
  const _MoveDialog({
    required this.categories,
    required this.postCount,
    this.currentCategory,
    this.title,
  });

  final List<String> categories;
  final int postCount;
  final String? currentCategory;
  final String? title;

  @override
  State<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<_MoveDialog> {
  String _query = '';
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = widget.categories
        .where((name) => name.toLowerCase().contains(_query.toLowerCase()))
        .toList(growable: false);
    final label = widget.postCount == 1 ? '1 post' : '${widget.postCount} posts';

    return AlertDialog(
      title: Text(widget.title ?? 'Move $label'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose the category these posts should appear in.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search categories',
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No matching categories',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final name = filtered[index];
                        final isCurrent = name == widget.currentCategory;
                        final isSelected = name == _selected;
                        return ListTile(
                          dense: true,
                          enabled: !isCurrent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          selected: isSelected,
                          selectedTileColor:
                              theme.colorScheme.primaryContainer,
                          leading: Icon(
                            isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                          ),
                          title: Text(name),
                          trailing: isCurrent
                              ? Text('Current', style: theme.textTheme.labelSmall)
                              : null,
                          onTap: () => setState(() => _selected = name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
          icon: const Icon(Icons.drive_file_move_outline),
          label: Text(_selected == null ? 'Move' : 'Move to $_selected'),
        ),
      ],
    );
  }
}

Future<bool> confirmDeletePosts(BuildContext context, int count) async {
  final label = count == 1 ? 'this post' : 'these $count posts';
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, color: scheme.error, size: 32),
        title: Text(count == 1 ? 'Delete post?' : 'Delete $count posts?'),
        content: SizedBox(
          width: 380,
          child: Text(
            'App users will no longer see $label. This cannot be undone from '
            'the admin panel. (The media file stays in storage.)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

enum PreviewAction { move, delete }

/// Full-size preview with details. Left/right arrow keys browse [posts].
Future<void> showPostPreview(
  BuildContext context, {
  required List<ContentPost> posts,
  required int initialIndex,
  required Future<void> Function(ContentPost post, PreviewAction action)
      onAction,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.82),
    builder: (context) => _PreviewDialog(
      posts: posts,
      initialIndex: initialIndex,
      onAction: onAction,
    ),
  );
}

class _PreviewDialog extends StatefulWidget {
  const _PreviewDialog({
    required this.posts,
    required this.initialIndex,
    required this.onAction,
  });

  final List<ContentPost> posts;
  final int initialIndex;
  final Future<void> Function(ContentPost post, PreviewAction action) onAction;

  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog> {
  late int _index = widget.initialIndex;

  ContentPost get _post => widget.posts[_index];

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.posts.length) return;
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final post = _post;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1100,
              maxHeight: size.height - 48,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NavButton(
                  icon: Icons.chevron_left_rounded,
                  onPressed: _index > 0 ? () => _go(-1) : null,
                ),
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ColoredBox(
                      color: Colors.black,
                      child: post.isVideo
                          ? WebVideo(
                              url: post.mediaUrl,
                              controls: true,
                              cover: false,
                            )
                          : Image.network(
                              post.mediaUrl,
                              key: ValueKey(post.id),
                              fit: BoxFit.contain,
                              webHtmlElementStrategy:
                                  WebHtmlElementStrategy.prefer,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 300,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Post ${_index + 1} of ${widget.posts.length}',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            post.category,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _DetailRow(
                            icon: post.isVideo
                                ? Icons.movie_outlined
                                : Icons.image_outlined,
                            label: 'Type',
                            value: post.isVideo ? 'Video' : 'Image',
                          ),
                          _DetailRow(
                            icon: Icons.schedule_rounded,
                            label: 'Uploaded',
                            value: DateFormatters.dateTime(post.createdAt),
                          ),
                          _DetailRow(
                            icon: Icons.insert_drive_file_outlined,
                            label: 'File',
                            value: post.fileName,
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: post.mediaUrl),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Media link copied'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.link_rounded),
                            label: const Text('Copy media link'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => openUrlInNewTab(post.mediaUrl),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Open original'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await widget.onAction(post, PreviewAction.move);
                            },
                            icon: const Icon(Icons.drive_file_move_outline),
                            label: const Text('Move to category'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                            ),
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await widget.onAction(post, PreviewAction.delete);
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _NavButton(
                  icon: Icons.chevron_right_rounded,
                  onPressed: _index < widget.posts.length - 1
                      ? () => _go(1)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: IconButton.filledTonal(
          iconSize: 28,
          onPressed: onPressed,
          icon: Icon(icon),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
