import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/features/categories/presentation/categories_controller.dart';
import 'package:apnipost_admin/features/content/data/supabase_content_repository.dart';
import 'package:apnipost_admin/features/content/domain/content_post.dart';
import 'package:apnipost_admin/features/content/domain/content_repository.dart';
import 'package:apnipost_admin/features/data_upload/domain/upload_media_mapping.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return SupabaseContentRepository();
});

@immutable
class CategoryOption {
  const CategoryOption({required this.name, required this.isOrphan});

  final String name;

  /// Used by posts but missing from `categories` (renamed/deleted), so the
  /// app never shows these posts.
  final bool isOrphan;
}

@immutable
class ContentLibraryState {
  const ContentLibraryState({
    this.query = const ContentQuery(),
    this.items = const [],
    this.total = 0,
    this.categories = const [],
    this.selectedIds = const {},
    this.isLoading = true,
    this.isLoadingMore = false,
    this.isMutating = false,
    this.errorMessage,
    this.successMessage,
  });

  final ContentQuery query;
  final List<ContentPost> items;
  final int total;
  final List<CategoryOption> categories;
  final Set<String> selectedIds;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isMutating;
  final String? errorMessage;
  final String? successMessage;

  bool get hasMore => items.length < total;
  bool get isSelecting => selectedIds.isNotEmpty;

  /// Categories posts can be moved into (only real ones).
  List<String> get moveTargets => [
        for (final option in categories)
          if (!option.isOrphan) option.name,
      ];

  ContentLibraryState copyWith({
    ContentQuery? query,
    List<ContentPost>? items,
    int? total,
    List<CategoryOption>? categories,
    Set<String>? selectedIds,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isMutating,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ContentLibraryState(
      query: query ?? this.query,
      items: items ?? this.items,
      total: total ?? this.total,
      categories: categories ?? this.categories,
      selectedIds: selectedIds ?? this.selectedIds,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isMutating: isMutating ?? this.isMutating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class ContentLibraryController extends Notifier<ContentLibraryState> {
  static const pageSize = 48;

  ContentRepository get _repository => ref.read(contentRepositoryProvider);

  /// Guards against out-of-order responses when filters change quickly.
  int _requestId = 0;

  @override
  ContentLibraryState build() {
    Future.microtask(() {
      _loadCategories();
      _reload();
    });
    return const ContentLibraryState();
  }

  /// Applies a category from the URL (e.g. a dashboard "Review" link).
  void applyRouteCategory(String? category) {
    if (category == state.query.category) return;
    _setQuery(
      category == null
          ? state.query.copyWith(clearCategory: true)
          : state.query.copyWith(category: category),
    );
  }

  void setCategory(String? category) => applyRouteCategory(category);

  void setMediaType(PostMediaTypeFilter filter) {
    _setQuery(
      filter.type == null
          ? state.query.copyWith(clearMediaType: true)
          : state.query.copyWith(mediaType: filter.type),
    );
  }

  void setSort(ContentSort sort) => _setQuery(state.query.copyWith(sort: sort));

  Future<void> refresh() async {
    await Future.wait([_loadCategories(), _reload()]);
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    final requestId = _requestId;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _repository.fetchPosts(
        query: state.query,
        offset: state.items.length,
        limit: pageSize,
      );
      if (requestId != _requestId) return;
      final known = {for (final post in state.items) post.id};
      state = state.copyWith(
        items: [
          ...state.items,
          for (final post in page.items)
            if (!known.contains(post.id)) post,
        ],
        total: page.total,
        isLoadingMore: false,
      );
    } on AppFailure catch (failure) {
      if (requestId != _requestId) return;
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: failure.message,
      );
    }
  }

  void toggleSelected(String id) {
    final next = {...state.selectedIds};
    if (!next.remove(id)) next.add(id);
    state = state.copyWith(selectedIds: next);
  }

  void selectAllLoaded() {
    state = state.copyWith(
      selectedIds: {for (final post in state.items) post.id},
    );
  }

  void clearSelection() => state = state.copyWith(selectedIds: const {});

  void clearMessages() =>
      state = state.copyWith(clearError: true, clearSuccess: true);

  Future<bool> movePosts(List<String> ids, String category) async {
    return _mutate(
      () => _repository.movePosts(ids: ids, category: category),
      success: '${_postsLabel(ids.length)} moved to $category.',
      apply: (items) {
        final filtered = state.query.category != null &&
            state.query.category != category;
        return [
          for (final post in items)
            if (!ids.contains(post.id))
              post
            else if (!filtered)
              post.copyWith(category: category),
        ];
      },
      removedCount: state.query.category != null &&
              state.query.category != category
          ? ids.length
          : 0,
    );
  }

  /// Moves every post of the current (orphan) category filter into [to],
  /// then switches the filter to [to] so the admin sees them.
  Future<bool> moveAllInCategory({
    required String from,
    required String to,
  }) async {
    if (state.isMutating) return false;
    state = state.copyWith(
      isMutating: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final moved = await _repository.moveAllInCategory(from: from, to: to);
      state = state.copyWith(
        isMutating: false,
        selectedIds: const {},
        successMessage: '${_postsLabel(moved)} moved from $from to $to.',
      );
      ref.invalidate(categoriesControllerProvider);
      await _loadCategories();
      _setQuery(state.query.copyWith(category: to));
      return true;
    } on AppFailure catch (failure) {
      state = state.copyWith(isMutating: false, errorMessage: failure.message);
      return false;
    }
  }

  Future<bool> deletePosts(List<String> ids) async {
    return _mutate(
      () => _repository.deletePosts(ids),
      success: '${_postsLabel(ids.length)} deleted.',
      apply: (items) => [
        for (final post in items)
          if (!ids.contains(post.id)) post,
      ],
      removedCount: ids.length,
    );
  }

  Future<bool> _mutate(
    Future<void> Function() action, {
    required String success,
    required List<ContentPost> Function(List<ContentPost> items) apply,
    required int removedCount,
  }) async {
    if (state.isMutating) return false;
    state = state.copyWith(
      isMutating: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      await action();
      state = state.copyWith(
        isMutating: false,
        items: apply(state.items),
        total: (state.total - removedCount).clamp(0, 1 << 30),
        selectedIds: const {},
        successMessage: success,
      );
      // Category list may gain/lose orphan entries; counts elsewhere refresh.
      _loadCategories();
      ref.invalidate(categoriesControllerProvider);
      return true;
    } on AppFailure catch (failure) {
      state = state.copyWith(isMutating: false, errorMessage: failure.message);
      return false;
    }
  }

  void _setQuery(ContentQuery query) {
    if (query == state.query) return;
    state = state.copyWith(query: query, selectedIds: const {});
    _reload();
  }

  Future<void> _reload() async {
    final requestId = ++_requestId;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _repository.fetchPosts(
        query: state.query,
        offset: 0,
        limit: pageSize,
      );
      if (requestId != _requestId) return;
      state = state.copyWith(
        items: page.items,
        total: page.total,
        isLoading: false,
      );
    } on AppFailure catch (failure) {
      if (requestId != _requestId) return;
      state = state.copyWith(
        items: const [],
        total: 0,
        isLoading: false,
        errorMessage: failure.message,
      );
    }
  }

  Future<void> _loadCategories() async {
    try {
      final officialFuture =
          ref.read(categoriesRepositoryProvider).fetchCategories();
      final usedFuture = _repository.fetchPostCategoryNames();
      final official = [
        for (final category in await officialFuture) category.name,
      ];
      final officialSet = official.toSet();
      final orphans =
          (await usedFuture).where((name) => !officialSet.contains(name));
      state = state.copyWith(
        categories: [
          for (final name in official)
            CategoryOption(name: name, isOrphan: false),
          for (final name in orphans) CategoryOption(name: name, isOrphan: true),
        ],
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(errorMessage: failure.message);
    }
  }

  String _postsLabel(int count) => count == 1 ? '1 post' : '$count posts';
}

/// Segmented filter options for the media type.
enum PostMediaTypeFilter {
  all(null, 'All'),
  images(PostMediaType.image, 'Images'),
  videos(PostMediaType.video, 'Videos');

  const PostMediaTypeFilter(this.type, this.label);

  final PostMediaType? type;
  final String label;

  static PostMediaTypeFilter of(PostMediaType? type) => switch (type) {
        PostMediaType.image => images,
        PostMediaType.video => videos,
        _ => all,
      };
}

final contentLibraryControllerProvider =
    NotifierProvider<ContentLibraryController, ContentLibraryState>(
  ContentLibraryController.new,
);
