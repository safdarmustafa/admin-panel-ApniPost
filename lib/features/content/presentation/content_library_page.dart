import 'package:apnipost_admin/core/constants/app_routes.dart';
import 'package:apnipost_admin/features/content/domain/content_post.dart';
import 'package:apnipost_admin/features/content/presentation/content_library_controller.dart';
import 'package:apnipost_admin/features/content/presentation/widgets/post_card.dart';
import 'package:apnipost_admin/features/content/presentation/widgets/post_dialogs.dart';
import 'package:apnipost_admin/shared/web/web_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ContentLibraryPage extends ConsumerStatefulWidget {
  const ContentLibraryPage({super.key, this.initialCategory});

  /// From `?category=` (e.g. a dashboard "Review" link).
  final String? initialCategory;

  @override
  ConsumerState<ContentLibraryPage> createState() => _ContentLibraryPageState();
}

class _ContentLibraryPageState extends ConsumerState<ContentLibraryPage> {
  final _scroll = ScrollController();

  ContentLibraryController get _controller =>
      ref.read(contentLibraryControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _applyRouteCategory();
  }

  @override
  void didUpdateWidget(ContentLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategory != widget.initialCategory) {
      _applyRouteCategory();
    }
  }

  void _applyRouteCategory() {
    final category = widget.initialCategory;
    if (category == null || category.isEmpty) return;
    Future.microtask(() => _controller.applyRouteCategory(category));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 800) _controller.loadMore();
  }

  void _showSnack(String message, {bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          width: 480,
          backgroundColor: error ? scheme.error : null,
          content: Text(message),
        ),
      );
  }

  Future<void> _move(List<String> ids, {String? currentCategory}) async {
    final state = ref.read(contentLibraryControllerProvider);
    final target = await showMoveToCategoryDialog(
      context,
      categories: state.moveTargets,
      postCount: ids.length,
      currentCategory: currentCategory,
    );
    if (target == null) return;
    await _controller.movePosts(ids, target);
  }

  Future<void> _delete(List<String> ids) async {
    if (!await confirmDeletePosts(context, ids.length)) return;
    await _controller.deletePosts(ids);
  }

  Future<void> _moveAll(String from, int count) async {
    final state = ref.read(contentLibraryControllerProvider);
    final target = await showMoveToCategoryDialog(
      context,
      categories: state.moveTargets,
      postCount: count,
      title: 'Move all $count posts from "$from"',
    );
    if (target == null) return;
    await _controller.moveAllInCategory(from: from, to: target);
  }

  Future<void> _onCardAction(ContentPost post, PostCardAction action) async {
    switch (action) {
      case PostCardAction.preview:
        _preview(post);
      case PostCardAction.move:
        await _move([post.id], currentCategory: post.category);
      case PostCardAction.copyLink:
        await Clipboard.setData(ClipboardData(text: post.mediaUrl));
        _showSnack('Media link copied');
      case PostCardAction.openOriginal:
        openUrlInNewTab(post.mediaUrl);
      case PostCardAction.delete:
        await _delete([post.id]);
    }
  }

  void _preview(ContentPost post) {
    final items = ref.read(contentLibraryControllerProvider).items;
    showPostPreview(
      context,
      posts: items,
      initialIndex: items.indexWhere((p) => p.id == post.id),
      onAction: (post, action) async {
        switch (action) {
          case PreviewAction.move:
            await _move([post.id], currentCategory: post.category);
          case PreviewAction.delete:
            await _delete([post.id]);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contentLibraryControllerProvider);

    ref.listen(contentLibraryControllerProvider, (previous, next) {
      if (next.successMessage != null &&
          next.successMessage != previous?.successMessage) {
        _showSnack(next.successMessage!);
        _controller.clearMessages();
      } else if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage &&
          next.items.isNotEmpty) {
        // Errors with an empty grid are shown inline instead.
        _showSnack(next.errorMessage!, error: true);
      }
    });

    final orphan = state.categories
        .where((c) => c.isOrphan && c.name == state.query.category)
        .firstOrNull;

    return Stack(
      children: [
        CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              sliver: SliverToBoxAdapter(
                child: _Header(state: state, onRefresh: _controller.refresh),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              sliver: SliverToBoxAdapter(
                child: _FilterBar(state: state, controller: _controller),
              ),
            ),
            if (orphan != null && !state.isLoading && state.total > 0)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: _OrphanBanner(
                    category: orphan.name,
                    count: state.total,
                    busy: state.isMutating,
                    onMoveAll: () => _moveAll(orphan.name, state.total),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
              sliver: _buildGrid(state),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(
            child: AnimatedSlide(
              offset: state.isSelecting ? Offset.zero : const Offset(0, 2),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: state.isSelecting ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !state.isSelecting,
                  child: _SelectionBar(
                    count: state.selectedIds.length,
                    loaded: state.items.length,
                    busy: state.isMutating,
                    onSelectAll: _controller.selectAllLoaded,
                    onClear: _controller.clearSelection,
                    onMove: () => _move(state.selectedIds.toList()),
                    onDelete: () => _delete(state.selectedIds.toList()),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(ContentLibraryState state) {
    const delegate = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 220,
      mainAxisSpacing: 18,
      crossAxisSpacing: 18,
      childAspectRatio: 0.78,
    );

    if (state.isLoading) {
      return SliverGrid(
        gridDelegate: delegate,
        delegate: SliverChildBuilderDelegate(
          (context, index) => const _SkeletonCard(),
          childCount: 12,
        ),
      );
    }

    if (state.items.isEmpty) {
      return SliverToBoxAdapter(
        child: _EmptyState(
          error: state.errorMessage,
          filtered: state.query != const ContentQuery(),
          onRetry: _controller.refresh,
          onClearFilters: () {
            _controller
              ..setCategory(null)
              ..setMediaType(PostMediaTypeFilter.all);
          },
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverGrid(
          gridDelegate: delegate,
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final post = state.items[index];
              return PostCard(
                key: ValueKey(post.id),
                post: post,
                selected: state.selectedIds.contains(post.id),
                selectionMode: state.isSelecting,
                onTap: () => state.isSelecting
                    ? _controller.toggleSelected(post.id)
                    : _preview(post),
                onToggleSelected: () => _controller.toggleSelected(post.id),
                onAction: (action) => _onCardAction(post, action),
              );
            },
            childCount: state.items.length,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Center(
              child: state.isLoadingMore
                  ? const CircularProgressIndicator()
                  : state.hasMore
                      ? OutlinedButton.icon(
                          onPressed: _controller.loadMore,
                          icon: const Icon(Icons.expand_more_rounded),
                          label: const Text('Load more'),
                        )
                      : Text(
                          "That's everything · ${state.total} posts",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.onRefresh});

  final ContentLibraryState state;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = state.isLoading
        ? 'Loading posts…'
        : state.total == 0
            ? 'No posts match these filters'
            : '${state.total} posts · showing ${state.items.length}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Everything your users can see',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton.outlined(
          tooltip: 'Refresh',
          onPressed: state.isLoading ? null : onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: () => context.go(AppRoutes.upload),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Upload content'),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.state, required this.controller});

  final ContentLibraryState state;
  final ContentLibraryController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = state.query;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String?>(
                key: ValueKey(query.category),
                initialValue: query.category,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.category_outlined),
                  labelText: 'Category',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All categories'),
                  ),
                  for (final option in state.categories)
                    DropdownMenuItem(
                      value: option.name,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (option.isOrphan)
                            Tooltip(
                              message: 'Not a category any more — hidden in the app',
                              child: Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: theme.colorScheme.error,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
                onChanged: controller.setCategory,
              ),
            ),
            SegmentedButton<PostMediaTypeFilter>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: PostMediaTypeFilter.all,
                  label: Text('All'),
                  icon: Icon(Icons.apps_rounded),
                ),
                ButtonSegment(
                  value: PostMediaTypeFilter.images,
                  label: Text('Images'),
                  icon: Icon(Icons.image_outlined),
                ),
                ButtonSegment(
                  value: PostMediaTypeFilter.videos,
                  label: Text('Videos'),
                  icon: Icon(Icons.movie_outlined),
                ),
              ],
              selected: {PostMediaTypeFilter.of(query.mediaType)},
              onSelectionChanged: (value) => controller.setMediaType(value.first),
            ),
            PopupMenuButton<ContentSort>(
              tooltip: 'Sort',
              initialValue: query.sort,
              onSelected: controller.setSort,
              itemBuilder: (context) => [
                for (final sort in ContentSort.values)
                  PopupMenuItem(value: sort, child: Text(sort.label)),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.swap_vert_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(query.sort.label, style: theme.textTheme.labelLarge),
                    const Icon(Icons.arrow_drop_down_rounded),
                  ],
                ),
              ),
            ),
            if (query != const ContentQuery())
              TextButton.icon(
                onPressed: () {
                  controller
                    ..setCategory(null)
                    ..setMediaType(PostMediaTypeFilter.all)
                    ..setSort(ContentSort.newest);
                },
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Clear filters'),
              ),
          ],
        ),
      ),
    );
  }
}

class _OrphanBanner extends StatelessWidget {
  const _OrphanBanner({
    required this.category,
    required this.count,
    required this.busy,
    required this.onMoveAll,
  });

  final String category;
  final int count;
  final bool busy;
  final VoidCallback onMoveAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_off_outlined, color: scheme.error),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'These $count posts are hidden in the app',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'No category named "$category" exists any more. '
                  'Move them into a real category so users can see them.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: busy ? null : onMoveAll,
            icon: const Icon(Icons.drive_file_move_outline),
            label: Text('Move all $count'),
          ),
        ],
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.loaded,
    required this.busy,
    required this.onSelectAll,
    required this.onClear,
    required this.onMove,
    required this.onDelete,
  });

  final int count;
  final int loaded;
  final bool busy;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const onBar = Colors.white;

    return Material(
      color: const Color(0xFF1F2933),
      elevation: 8,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Clear selection',
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, color: onBar),
            ),
            Text(
              '$count selected',
              style: theme.textTheme.titleSmall?.copyWith(
                color: onBar,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            if (count < loaded)
              TextButton(
                onPressed: onSelectAll,
                child: Text(
                  'Select all $loaded',
                  style: TextStyle(color: scheme.primaryFixedDim),
                ),
              ),
            const SizedBox(width: 8),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: onBar,
                  ),
                ),
              )
            else ...[
              FilledButton.tonalIcon(
                onPressed: onMove,
                icon: const Icon(Icons.drive_file_move_outline),
                label: const Text('Move'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                ),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
              ),
            ],
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_pulse),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.error,
    required this.filtered,
    required this.onRetry,
    required this.onClearFilters,
  });

  final String? error;
  final bool filtered;
  final Future<void> Function() onRetry;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isError = error != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: isError ? scheme.errorContainer : scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isError
                  ? Icons.cloud_off_rounded
                  : Icons.photo_library_outlined,
              size: 40,
              color: isError ? scheme.error : scheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isError
                ? 'Couldn\'t load content'
                : filtered
                    ? 'Nothing matches these filters'
                    : 'No posts yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              error ??
                  (filtered
                      ? 'Try another category or media type.'
                      : 'Upload images and videos and they will show up here.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (isError)
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            )
          else if (filtered)
            OutlinedButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Clear filters'),
            )
          else
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.upload),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Upload content'),
            ),
        ],
      ),
    );
  }
}
