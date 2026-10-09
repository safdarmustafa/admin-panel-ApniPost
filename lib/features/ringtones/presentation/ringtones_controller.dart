import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/features/ringtones/data/supabase_ringtones_repository.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone_service.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtones_repository.dart';
import 'package:apnipost_admin/features/ringtones/presentation/ringtone_categories_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ringtonesRepositoryProvider = Provider<RingtonesRepository>((ref) {
  return SupabaseRingtonesRepository();
});

final ringtoneServiceProvider = Provider<RingtoneService>((ref) {
  return RingtoneService(ref.watch(ringtonesRepositoryProvider));
});

@immutable
class RingtonesViewState {
  const RingtonesViewState({
    required this.ringtones,
    this.categoryFilter,
    this.isMutating = false,
    this.errorMessage,
    this.successMessage,
  });

  /// Newest first.
  final List<Ringtone> ringtones;

  /// Null shows every category.
  final String? categoryFilter;
  final bool isMutating;
  final String? errorMessage;
  final String? successMessage;

  List<Ringtone> get filtered {
    final filter = categoryFilter?.toLowerCase();
    if (filter == null) return ringtones;
    return ringtones
        .where((r) => r.category.toLowerCase() == filter)
        .toList(growable: false);
  }

  /// Ringtones per category name (for the filter chips).
  Map<String, int> get countsByCategory {
    final counts = <String, int>{};
    for (final ringtone in ringtones) {
      counts.update(ringtone.category, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  RingtonesViewState copyWith({
    List<Ringtone>? ringtones,
    String? categoryFilter,
    bool clearFilter = false,
    bool? isMutating,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return RingtonesViewState(
      ringtones: ringtones ?? this.ringtones,
      categoryFilter:
          clearFilter ? null : (categoryFilter ?? this.categoryFilter),
      isMutating: isMutating ?? this.isMutating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class RingtonesController extends AsyncNotifier<RingtonesViewState> {
  RingtonesRepository get _repository => ref.read(ringtonesRepositoryProvider);
  RingtoneService get _service => ref.read(ringtoneServiceProvider);

  @override
  Future<RingtonesViewState> build() async {
    final ringtones = await _repository.fetchRingtones();
    return RingtonesViewState(ringtones: ringtones);
  }

  Future<void> refresh() async {
    final previous = state.asData?.value;
    state = const AsyncLoading<RingtonesViewState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final ringtones = await _repository.fetchRingtones();
      return RingtonesViewState(
        ringtones: ringtones,
        categoryFilter: previous?.categoryFilter,
      );
    });
  }

  void setCategoryFilter(String? category) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      category == null
          ? current.copyWith(clearFilter: true)
          : current.copyWith(categoryFilter: category),
    );
  }

  void clearMessages() {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearError: true, clearSuccess: true));
  }

  /// Uploads one file; the upload dialog shows per-row errors itself.
  Future<Ringtone> upload(RingtoneDraft draft) async {
    final ringtone = await _service.upload(draft);
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(ringtones: [ringtone, ...current.ringtones]),
      );
    }
    return ringtone;
  }

  Future<bool> updateRingtone({
    required Ringtone ringtone,
    required String title,
    required String category,
  }) {
    return _mutate(
      fallbackError: 'Unable to update the ringtone. Please try again.',
      action: (current) async {
        final updated = await _repository.updateRingtone(
          id: ringtone.id,
          title: title,
          category: category,
        );
        return current.copyWith(
          ringtones: [
            for (final item in current.ringtones)
              item.id == updated.id ? updated : item,
          ],
          successMessage: 'Ringtone updated.',
        );
      },
    );
  }

  Future<bool> deleteRingtone(Ringtone ringtone) {
    return _mutate(
      fallbackError: 'Unable to delete the ringtone. Please try again.',
      action: (current) async {
        final fileRemoved = await _service.delete(ringtone);
        return current.copyWith(
          ringtones: current.ringtones
              .where((item) => item.id != ringtone.id)
              .toList(growable: false),
          successMessage: fileRemoved
              ? 'Ringtone deleted.'
              : 'Ringtone removed from the app, but its file was left in '
                  'storage.',
        );
      },
    );
  }

  Future<bool> _mutate({
    required String fallbackError,
    required Future<RingtonesViewState> Function(RingtonesViewState current)
        action,
  }) async {
    final current = state.asData?.value;
    if (current == null) return false;

    state = AsyncData(
      current.copyWith(isMutating: true, clearError: true, clearSuccess: true),
    );

    try {
      final next = await action(current);
      state = AsyncData(next.copyWith(isMutating: false));
      // Ringtone counts per category changed.
      ref.invalidate(ringtoneCategoriesControllerProvider);
      return true;
    } on AppFailure catch (failure) {
      state = AsyncData(
        current.copyWith(isMutating: false, errorMessage: failure.message),
      );
      return false;
    } catch (_) {
      state = AsyncData(
        current.copyWith(isMutating: false, errorMessage: fallbackError),
      );
      return false;
    }
  }
}

final ringtonesControllerProvider =
    AsyncNotifierProvider<RingtonesController, RingtonesViewState>(
  RingtonesController.new,
);
