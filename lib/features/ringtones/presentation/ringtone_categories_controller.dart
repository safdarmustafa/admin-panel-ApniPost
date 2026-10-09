import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/features/ringtones/data/supabase_ringtone_categories_repository.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone_categories_repository.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone_category.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone_rules.dart';
import 'package:apnipost_admin/features/ringtones/presentation/ringtones_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ringtoneCategoriesRepositoryProvider =
    Provider<RingtoneCategoriesRepository>((ref) {
  return SupabaseRingtoneCategoriesRepository();
});

@immutable
class RingtoneCategoriesViewState {
  const RingtoneCategoriesViewState({
    required this.categories,
    this.isMutating = false,
    this.errorMessage,
    this.successMessage,
  });

  /// By display order.
  final List<RingtoneCategory> categories;
  final bool isMutating;
  final String? errorMessage;
  final String? successMessage;

  Iterable<String> get names => categories.map((c) => c.name);

  RingtoneCategoriesViewState copyWith({
    List<RingtoneCategory>? categories,
    bool? isMutating,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return RingtoneCategoriesViewState(
      categories: categories ?? this.categories,
      isMutating: isMutating ?? this.isMutating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class RingtoneCategoriesController
    extends AsyncNotifier<RingtoneCategoriesViewState> {
  RingtoneCategoriesRepository get _repository =>
      ref.read(ringtoneCategoriesRepositoryProvider);

  @override
  Future<RingtoneCategoriesViewState> build() async {
    final categories = await _repository.fetchCategories();
    return RingtoneCategoriesViewState(categories: categories);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<RingtoneCategoriesViewState>()
        .copyWithPrevious(state);
    state = await AsyncValue.guard(build);
  }

  void clearMessages() {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearError: true, clearSuccess: true));
  }

  Future<bool> createCategory({
    required String name,
    required String? hindiName,
  }) async {
    final current = state.asData?.value;
    if (current == null) return false;

    final error = RingtoneRules.categoryNameError(
      name,
      existingNames: current.names,
    );
    if (error != null) {
      state = AsyncData(current.copyWith(errorMessage: error));
      return false;
    }

    final nextOrder = current.categories.isEmpty
        ? 0
        : current.categories
                .map((c) => c.displayOrder)
                .reduce((a, b) => a > b ? a : b) +
            1;

    return _mutate(
      successMessage: 'Category created.',
      action: () => _repository.createCategory(
        name: RingtoneRules.normalizeCategoryName(name),
        hindiName: _normalizeHindi(hindiName),
        displayOrder: nextOrder,
      ),
    );
  }

  Future<bool> updateCategory({
    required RingtoneCategory category,
    required String name,
    required String? hindiName,
  }) async {
    final current = state.asData?.value;
    if (current == null) return false;

    final error = RingtoneRules.categoryNameError(
      name,
      existingNames: current.names,
      currentName: category.name,
    );
    if (error != null) {
      state = AsyncData(current.copyWith(errorMessage: error));
      return false;
    }

    final normalized = RingtoneRules.normalizeCategoryName(name);
    final ok = await _mutate(
      successMessage: 'Category updated.',
      action: () => _repository.updateCategory(
        id: category.id,
        name: normalized,
        hindiName: _normalizeHindi(hindiName),
      ),
    );
    // The database renamed the category on its ringtones too.
    if (ok && normalized != category.name) {
      ref.invalidate(ringtonesControllerProvider);
    }
    return ok;
  }

  Future<bool> reorder(int oldIndex, int newIndex) async {
    final current = state.asData?.value;
    if (current == null) return false;

    final items = [...current.categories];
    if (newIndex > oldIndex) newIndex -= 1;
    items.insert(newIndex, items.removeAt(oldIndex));
    final reindexed = [
      for (var i = 0; i < items.length; i++) items[i].copyWith(displayOrder: i),
    ];

    // Optimistic: show the new order right away.
    state = AsyncData(
      current.copyWith(categories: reindexed, isMutating: true),
    );
    try {
      await _repository.reorderCategories(reindexed);
      state = AsyncData(
        current.copyWith(
          categories: reindexed,
          isMutating: false,
          successMessage: 'Category order saved.',
        ),
      );
      return true;
    } catch (error) {
      await refresh();
      final latest = state.asData?.value ?? current;
      state = AsyncData(
        latest.copyWith(
          isMutating: false,
          errorMessage: error is AppFailure
              ? error.message
              : 'Unable to reorder categories. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<bool> deleteCategory(RingtoneCategory category) async {
    final current = state.asData?.value;
    if (current == null) return false;
    if (category.ringtoneCount > 0) {
      state = AsyncData(
        current.copyWith(
          errorMessage: 'This category has ${category.ringtoneCount} '
              'ringtone(s). Move or delete them first.',
        ),
      );
      return false;
    }
    return _mutate(
      successMessage: 'Category deleted.',
      action: () => _repository.deleteCategory(category.id),
    );
  }

  String? _normalizeHindi(String? raw) {
    final value = raw?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  Future<bool> _mutate({
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    final current = state.asData?.value;
    if (current == null) return false;

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
        ),
      );
      return true;
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isMutating: false,
          errorMessage: error is AppFailure
              ? error.message
              : 'Unable to save the category. Please try again.',
        ),
      );
      return false;
    }
  }
}

final ringtoneCategoriesControllerProvider = AsyncNotifierProvider<
    RingtoneCategoriesController, RingtoneCategoriesViewState>(
  RingtoneCategoriesController.new,
);
