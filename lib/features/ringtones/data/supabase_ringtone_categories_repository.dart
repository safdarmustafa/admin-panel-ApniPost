import 'package:apnipost_admin/core/config/supabase_bootstrap.dart';
import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/core/utils/app_logger.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone_categories_repository.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone_category.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRingtoneCategoriesRepository
    implements RingtoneCategoriesRepository {
  SupabaseRingtoneCategoriesRepository({SupabaseClient? client})
      : _client = client ?? SupabaseBootstrap.client;

  final SupabaseClient _client;

  static const _table = 'ringtone_categories';
  static const _policyHint =
      'Make sure supabase/migrations/20261010_ringtone_categories.sql is '
      'applied.';

  @override
  Future<List<RingtoneCategory>> fetchCategories() async {
    try {
      // `ringtones(count)` follows the ringtones.category foreign key.
      final rows = await _client
          .from(_table)
          .select(
            'id, name, hindi_name, display_order, created_at, ringtones(count)',
          )
          .order('display_order')
          .order('name');
      return rows.map(RingtoneCategory.fromMap).toList(growable: false);
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to fetch ringtone categories',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapError(error, 'load categories'), cause: error);
    } catch (error, stackTrace) {
      if (error is AppFailure) rethrow;
      AppLogger.error(
        'Failed to fetch ringtone categories unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(
        'Unable to load categories. Please try again.',
        cause: error,
      );
    }
  }

  @override
  Future<void> createCategory({
    required String name,
    required String? hindiName,
    required int displayOrder,
  }) async {
    try {
      await _client.from(_table).insert({
        'name': name,
        'hindi_name': hindiName,
        'display_order': displayOrder,
      });
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to create ringtone category',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapError(error, 'create categories'), cause: error);
    }
  }

  @override
  Future<void> updateCategory({
    required String id,
    required String name,
    required String? hindiName,
  }) async {
    try {
      final rows = await _client
          .from(_table)
          .update({'name': name, 'hindi_name': hindiName})
          .eq('id', id)
          .select('id');
      // RLS silently filters rows instead of erroring.
      if (rows.isEmpty) {
        throw const AppFailure('Could not update the category. $_policyHint');
      }
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to update ringtone category',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapError(error, 'update categories'), cause: error);
    }
  }

  @override
  Future<void> reorderCategories(List<RingtoneCategory> ordered) async {
    try {
      await Future.wait([
        for (var i = 0; i < ordered.length; i++)
          _client
              .from(_table)
              .update({'display_order': i})
              .eq('id', ordered[i].id),
      ]);
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to reorder ringtone categories',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapError(error, 'reorder categories'), cause: error);
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    try {
      final rows =
          await _client.from(_table).delete().eq('id', id).select('id');
      if (rows.isEmpty) {
        throw const AppFailure('Could not delete the category. $_policyHint');
      }
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to delete ringtone category',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapError(error, 'delete categories'), cause: error);
    }
  }

  String _mapError(PostgrestException error, String action) {
    final message = error.message.toLowerCase();
    if (error.code == '42501' ||
        message.contains('row-level security') ||
        message.contains('permission')) {
      return 'You are not authorized to $action. $_policyHint';
    }
    if (error.code == '23505') {
      return 'A category with this name already exists.';
    }
    if (error.code == '23503') {
      return 'This category still has ringtones. Move or delete them first.';
    }
    if (error.code == '23514') {
      return 'That category name is not allowed.';
    }
    return 'Unable to $action. Please try again.';
  }
}
