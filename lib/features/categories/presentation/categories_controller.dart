import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/features/categories/data/supabase_categories_repository.dart';
import 'package:apnipost_admin/features/categories/domain/categories_repository.dart';
import 'package:apnipost_admin/features/categories/domain/category.dart';
import 'package:apnipost_admin/features/categories/domain/category_validators.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return SupabaseCategoriesRepository();
});

@immutable
class CategoriesViewState {
  const CategoriesViewState({
    required this.categories,
    this.searchQuery = '',
    this.isMutating = false,
    this.errorMessage,
    this.successMessage,
  });

  final List<ContentCategory> categories;
  final String searchQuery;
  final bool isMutating;
  final String? errorMessage;
  final String? successMessage;

  List<ContentCategory> get filtered {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return categories;
    return categories
        .where((category) => category.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  bool get isEmpty => categories.isEmpty;

  CategoriesViewState copyWith({
    List<ContentCategory>? categories,
    String? searchQuery,
    bool? isMutating,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return CategoriesViewState(
      categories: categories ?? this.categories,
      searchQuery: searchQuery ?? this.searchQuery,
      isMutating: isMutating ?? this.isMutating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class CategoriesController extends AsyncNotifier<CategoriesViewState> {
  CategoriesRepository get _repository =>
      ref.read(categoriesRepositoryProvider);

  @override
  Future<CategoriesViewState> build() async {
    final categories = await _repository.fetchCategories();
    return CategoriesViewState(categories: categories);
  }

  Future<void> refresh() async {
    final previous = state.asData?.value;
    state = const AsyncLoading<CategoriesViewState>()
        .copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final categories = await _repository.fetchCategories();
      return CategoriesViewState(
        categories: categories,
        searchQuery: previous?.searchQuery ?? '',
      );
    });
  }

  void setSearchQuery(String query) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        searchQuery: query,
        clearError: true,
        clearSuccess: true,
      ),
    );
  }

  void clearMessages() {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(clearError: true, clearSuccess: true),
    );
  }

  Future<bool> createCategory({
    required String name,
    required int displayOrder,
    required bool showOnHome,
  }) async {
    final current = state.asData?.value;
    if (current == null) return false;

    final validation = CategoryValidators.validateUniqueName(
      name,
      existingNames: current.categories.map((c) => c.name),
    );
    if (validation != null) {
      state = AsyncData(
        current.copyWith(errorMessage: validation, clearSuccess: true),
      );
      return false;
    }

    return _runMutation(
      current,
      action: () => _repository.createCategory(
        name: name,
        displayOrder: displayOrder,
        showOnHome: showOnHome,
      ),
      successMessage: 'ContentCategory created.',
    );
  }

  Future<bool> updateCategory({
    required ContentCategory category,
    required String name,
    required int displayOrder,
    required bool showOnHome,
  }) async {
    final current = state.asData?.value;
    if (current == null) return false;

    final renaming =
        CategoryValidators.normalizeName(name).toLowerCase() !=
            category.name.toLowerCase();

    if (renaming && !CategoryValidators.canRename(postCount: category.postCount)) {
      state = AsyncData(
        current.copyWith(
          errorMessage:
              'This category contains existing posts. Renaming is disabled to '
              'protect existing content.',
          clearSuccess: true,
        ),
      );
      return false;
    }

    final validation = CategoryValidators.validateUniqueName(
      name,
      existingNames: current.categories.map((c) => c.name),
      currentName: category.name,
    );
    if (validation != null) {
      state = AsyncData(
        current.copyWith(errorMessage: validation, clearSuccess: true),
      );
      return false;
    }

    return _runMutation(
      current,
      action: () => _repository.updateCategory(
        category: category,
        name: name,
        displayOrder: displayOrder,
        showOnHome: showOnHome,
      ),
      successMessage: 'ContentCategory updated.',
    );
  }

  Future<bool> toggleShowOnHome(ContentCategory category) async {
    final current = state.asData?.value;
    if (current == null) return false;

    final nextValue = !category.showOnHome;
    state = AsyncData(current.copyWith(isMutating: true, clearError: true));

    try {
      await _repository.setShowOnHome(
        id: category.id,
        showOnHome: nextValue,
      );
      final updated = current.categories
          .map(
            (item) => item.id == category.id
                ? item.copyWith(showOnHome: nextValue)
                : item,
          )
          .toList(growable: false);

      state = AsyncData(
        current.copyWith(
          categories: updated,
          isMutating: false,
          successMessage: nextValue
              ? 'ContentCategory will show on home.'
              : 'ContentCategory hidden from home.',
          clearError: true,
        ),
      );
      return true;
    } on AppFailure catch (failure) {
      state = AsyncData(
        current.copyWith(
          isMutating: false,
          errorMessage: failure.message,
          clearSuccess: true,
        ),
      );
      return false;
    } catch (_) {
      state = AsyncData(
        current.copyWith(
          isMutating: false,
          errorMessage: 'Unable to update Show on Home. Please try again.',
          clearSuccess: true,
        ),
      );
      return false;
    }
  }

  Future<bool> reorder(int oldIndex, int newIndex) async {
    final current = state.asData?.value;
    if (current == null) return false;
    if (current.searchQuery.trim().isNotEmpty) {
      state = AsyncData(
        current.copyWith(
          errorMessage: 'Clear search before reordering categories.',
          clearSuccess: true,
        ),
      );
      return false;
    }

    final items = [...current.categories];
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    final reindexed = [
      for (var i = 0; i < items.length; i++)
        items[i].copyWith(displayOrder: i),
    ];

    state = AsyncData(
      current.copyWith(
        categories: reindexed,
        isMutating: true,
        clearError: true,
      ),
    );

    try {
      await _repository.reorderCategories(reindexed);
      state = AsyncData(
        current.copyWith(
          categories: reindexed,
          isMutating: false,
          successMessage: 'ContentCategory order saved.',
          clearError: true,
        ),
      );
      return true;
    } on AppFailure catch (failure) {
      // Reload authoritative order on failure.
      await refresh();
      final latest = state.asData?.value ?? current;
      state = AsyncData(
        latest.copyWith(
          isMutating: false,
          errorMessage: failure.message,
          clearSuccess: true,
        ),
      );
      return false;
    } catch (_) {
      await refresh();
      final latest = state.asData?.value ?? current;
      state = AsyncData(
        latest.copyWith(
          isMutating: false,
          errorMessage: 'Unable to reorder categories. Please try again.',
          clearSuccess: true,
        ),
      );
      return false;
    }
  }

  /// Returns null when deletion is allowed; otherwise a blocking message.
  Future<String?> deletionBlockReason(ContentCategory category) async {
    try {
      final count = await _repository.countPostsForCategory(category.name);
      if (count > 0) {
        return 'This category contains $count posts and cannot be deleted.';
      }
      return null;
    } on AppFailure catch (failure) {
      return failure.message;
    } catch (_) {
      return 'Unable to verify category content. Please try again.';
    }
  }

  Future<bool> deleteCategory(ContentCategory category) async {
    final current = state.asData?.value;
    if (current == null) return false;

    state = AsyncData(current.copyWith(isMutating: true, clearError: true));

    try {
      await _repository.deleteCategory(category);
      final remaining = current.categories
          .where((item) => item.id != category.id)
          .toList(growable: false);
      state = AsyncData(
        current.copyWith(
          categories: remaining,
          isMutating: false,
          successMessage: 'ContentCategory deleted.',
          clearError: true,
        ),
      );
      return true;
    } on AppFailure catch (failure) {
      state = AsyncData(
        current.copyWith(
          isMutating: false,
          errorMessage: failure.message,
          clearSuccess: true,
        ),
      );
      return false;
    } catch (_) {
      state = AsyncData(
        current.copyWith(
          isMutating: false,
          errorMessage: 'Unable to delete category. Please try again.',
          clearSuccess: true,
        ),
      );
      return false;
    }
  }

  Future<bool> _runMutation(
    CategoriesViewState current, {
    required Future<ContentCategory> Function() action,
    required String successMessage,
  }) async {
    state = AsyncData(
      current.copyWith(isMutating: true, clearError: true, clearSuccess: true),
    );

    try {
      await action();
      final categories = await _repository.fetchCategories();
      state = AsyncData(
        current.copyWith(
          categories: categories,
          isMutating: false,
          successMessage: successMessage,
          clearError: true,
        ),
      );
      return true;
    } on AppFailure catch (failure) {
      state = AsyncData(
        current.copyWith(
          isMutating: false,
          errorMessage: failure.message,
          clearSuccess: true,
        ),
      );
      return false;
    } catch (_) {
      state = AsyncData(
        current.copyWith(
          isMutating: false,
          errorMessage: 'Unable to save category. Please try again.',
          clearSuccess: true,
        ),
      );
      return false;
    }
  }
}

final categoriesControllerProvider =
    AsyncNotifierProvider<CategoriesController, CategoriesViewState>(
  CategoriesController.new,
);
