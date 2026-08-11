import 'package:apnipost_admin/core/config/supabase_bootstrap.dart';
import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/core/utils/app_logger.dart';
import 'package:apnipost_admin/features/categories/domain/categories_repository.dart';
import 'package:apnipost_admin/features/categories/domain/category.dart';
import 'package:apnipost_admin/features/categories/domain/category_validators.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCategoriesRepository implements CategoriesRepository {
  SupabaseCategoriesRepository({SupabaseClient? client})
      : _client = client ?? SupabaseBootstrap.client;

  final SupabaseClient _client;

  @override
  Future<List<ContentCategory>> fetchCategories() async {
    AppLogger.info('Fetching categories');
    try {
      final rows = await _client
          .from('categories')
          .select('id, name, display_order, show_on_home, created_at')
          .order('display_order', ascending: true);

      final categories = (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ContentCategory.fromMap)
          .toList();

      if (categories.isEmpty) {
        return const [];
      }

      final counts = await Future.wait(
        categories.map((category) => countPostsForCategory(category.name)),
      );

      return [
        for (var i = 0; i < categories.length; i++)
          categories[i].copyWith(postCount: counts[i]),
      ];
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to fetch categories',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapPostgrestError(error), cause: error);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to fetch categories unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      if (error is AppFailure) rethrow;
      throw AppFailure(
        'Unable to load categories. Please try again.',
        cause: error,
      );
    }
  }

  @override
  Future<bool> isNameTaken(String name, {String? excludingId}) async {
    final normalized = CategoryValidators.normalizeName(name);
    try {
      var query = _client
          .from('categories')
          .select('id, name')
          .ilike('name', normalized);

      if (excludingId != null) {
        query = query.neq('id', excludingId);
      }

      final rows = await query.limit(20);
      final list = (rows as List<dynamic>).cast<Map<String, dynamic>>();
      return list.any(
        (row) =>
            (row['name'] as String).trim().toLowerCase() ==
            normalized.toLowerCase(),
      );
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed duplicate-name check',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapPostgrestError(error), cause: error);
    }
  }

  @override
  Future<ContentCategory> createCategory({
    required String name,
    required int displayOrder,
    required bool showOnHome,
  }) async {
    final normalized = CategoryValidators.normalizeName(name);
    AppLogger.info('Creating category');

    try {
      if (await isNameTaken(normalized)) {
        throw const AppFailure('A category with this name already exists.');
      }

      final row = await _client
          .from('categories')
          .insert({
            'name': normalized,
            'display_order': displayOrder,
            'show_on_home': showOnHome,
          })
          .select('id, name, display_order, show_on_home, created_at')
          .single();

      return ContentCategory.fromMap(row, postCount: 0);
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to create category',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapPostgrestError(error), cause: error);
    } catch (error, stackTrace) {
      if (error is AppFailure) rethrow;
      AppLogger.error(
        'Failed to create category unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(
        'Unable to create category. Please try again.',
        cause: error,
      );
    }
  }

  @override
  Future<ContentCategory> updateCategory({
    required ContentCategory category,
    required String name,
    required int displayOrder,
    required bool showOnHome,
  }) async {
    final normalized = CategoryValidators.normalizeName(name);
    final renaming = normalized.toLowerCase() != category.name.toLowerCase();

    AppLogger.info('Updating category id=${category.id}');

    try {
      if (renaming) {
        if (category.hasPosts) {
          throw const AppFailure(
            'This category contains existing posts. Renaming is disabled to '
            'protect existing content.',
          );
        }
        // Re-check live count in case the list is stale.
        final liveCount = await countPostsForCategory(category.name);
        if (liveCount > 0) {
          throw const AppFailure(
            'This category contains existing posts. Renaming is disabled to '
            'protect existing content.',
          );
        }
        if (await isNameTaken(normalized, excludingId: category.id)) {
          throw const AppFailure('A category with this name already exists.');
        }
      }

      final row = await _client
          .from('categories')
          .update({
            'name': normalized,
            'display_order': displayOrder,
            'show_on_home': showOnHome,
          })
          .eq('id', category.id)
          .select('id, name, display_order, show_on_home, created_at')
          .single();

      final count = renaming
          ? 0
          : await countPostsForCategory(normalized);

      return ContentCategory.fromMap(row, postCount: count);
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to update category',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapPostgrestError(error), cause: error);
    } catch (error, stackTrace) {
      if (error is AppFailure) rethrow;
      AppLogger.error(
        'Failed to update category unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(
        'Unable to update category. Please try again.',
        cause: error,
      );
    }
  }

  @override
  Future<void> setShowOnHome({
    required String id,
    required bool showOnHome,
  }) async {
    AppLogger.info('Toggling show_on_home for category id=$id');
    try {
      await _client
          .from('categories')
          .update({'show_on_home': showOnHome})
          .eq('id', id);
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to update show_on_home',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapPostgrestError(error), cause: error);
    } catch (error) {
      if (error is AppFailure) rethrow;
      throw AppFailure(
        'Unable to update Show on Home. Please try again.',
        cause: error,
      );
    }
  }

  @override
  Future<void> reorderCategories(List<ContentCategory> ordered) async {
    AppLogger.info('Reordering ${ordered.length} categories');
    try {
      // Persist sequential display_order values for the new arrangement.
      await Future.wait([
        for (var i = 0; i < ordered.length; i++)
          _client
              .from('categories')
              .update({'display_order': i})
              .eq('id', ordered[i].id),
      ]);
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to reorder categories',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapPostgrestError(error), cause: error);
    } catch (error) {
      if (error is AppFailure) rethrow;
      throw AppFailure(
        'Unable to reorder categories. Please try again.',
        cause: error,
      );
    }
  }

  @override
  Future<int> countPostsForCategory(String categoryName) async {
    try {
      // HEAD count — does not download post rows.
      final count = await _client
          .from('posts')
          .count(CountOption.exact)
          .eq('category', categoryName);
      return count;
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to count posts for category',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapPostgrestError(error), cause: error);
    }
  }

  @override
  Future<void> deleteCategory(ContentCategory category) async {
    AppLogger.info('Deleting category id=${category.id}');
    try {
      final count = await countPostsForCategory(category.name);
      if (count > 0) {
        throw AppFailure(
          'This category contains $count posts and cannot be deleted.',
        );
      }

      await _client.from('categories').delete().eq('id', category.id);
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to delete category',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapPostgrestError(error), cause: error);
    } catch (error, stackTrace) {
      if (error is AppFailure) rethrow;
      AppLogger.error(
        'Failed to delete category unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(
        'Unable to delete category. Please try again.',
        cause: error,
      );
    }
  }

  String _mapPostgrestError(PostgrestException error) {
    final message = error.message.toLowerCase();
    final code = error.code;

    if (code == '42501' ||
        message.contains('permission denied') ||
        message.contains('row-level security') ||
        message.contains('rls')) {
      return 'You are not authorized to change categories.';
    }
    if (code == '23505' || message.contains('duplicate')) {
      return 'A category with this name already exists.';
    }
    if (message.contains('jwt') || message.contains('not authenticated')) {
      return 'Your session has expired. Please sign in again.';
    }
    return 'Unable to complete the category operation. Please try again.';
  }
}
