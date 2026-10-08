import 'package:apnipost_admin/core/config/supabase_bootstrap.dart';
import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/core/utils/app_logger.dart';
import 'package:apnipost_admin/features/content/domain/content_post.dart';
import 'package:apnipost_admin/features/content/domain/content_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseContentRepository implements ContentRepository {
  SupabaseContentRepository({SupabaseClient? client})
      : _client = client ?? SupabaseBootstrap.client;

  final SupabaseClient _client;

  static const _columns = 'id, category, media_url, media_type, created_at';

  @override
  Future<ContentPage> fetchPosts({
    required ContentQuery query,
    required int offset,
    required int limit,
  }) async {
    try {
      var filter = _client.from('posts').select(_columns);
      if (query.category != null) {
        filter = filter.eq('category', query.category!);
      }
      if (query.mediaType != null) {
        filter = filter.eq('media_type', query.mediaType!.dbValue);
      }

      final response = await filter
          .order('created_at', ascending: query.sort == ContentSort.oldest)
          .order('id')
          .range(offset, offset + limit - 1)
          .count(CountOption.exact);

      return ContentPage(
        items: response.data
            .cast<Map<String, dynamic>>()
            .map(ContentPost.fromMap)
            .toList(growable: false),
        total: response.count,
      );
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to fetch posts',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapPostgrestError(error, 'load content'), cause: error);
    } catch (error, stackTrace) {
      if (error is AppFailure) rethrow;
      AppLogger.error(
        'Failed to fetch posts unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(
        'Unable to load content. Please try again.',
        cause: error,
      );
    }
  }

  @override
  Future<List<String>> fetchPostCategoryNames() async {
    try {
      final rows = await _client.from('posts').select('category');
      final names = <String>{
        for (final row in (rows as List<dynamic>).cast<Map<String, dynamic>>())
          if (row['category'] != null) row['category'].toString(),
      }.toList()
        ..sort();
      return names;
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to fetch post categories',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapPostgrestError(error, 'load content'), cause: error);
    }
  }

  @override
  Future<void> movePosts({
    required List<String> ids,
    required String category,
  }) async {
    if (ids.isEmpty) return;
    AppLogger.info('Moving ${ids.length} post(s)');
    try {
      final updated = await _client
          .from('posts')
          .update({'category': category})
          .inFilter('id', ids)
          .select('id');
      _ensureAllAffected(updated, ids.length, 'move');
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to move posts',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapPostgrestError(error, 'move posts'), cause: error);
    }
  }

  @override
  Future<int> moveAllInCategory({
    required String from,
    required String to,
  }) async {
    AppLogger.info('Moving all posts between categories');
    try {
      final updated = await _client
          .from('posts')
          .update({'category': to})
          .eq('category', from)
          .select('id');
      final moved = updated.length;
      if (moved == 0) {
        throw const AppFailure(
          'No posts were moved. Make sure the posts admin policies '
          '(supabase/migrations/20261008_posts_admin_and_dashboard.sql) '
          'are applied.',
        );
      }
      return moved;
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to move category posts',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapPostgrestError(error, 'move posts'), cause: error);
    }
  }

  @override
  Future<void> deletePosts(List<String> ids) async {
    if (ids.isEmpty) return;
    AppLogger.info('Deleting ${ids.length} post(s)');
    try {
      final deleted =
          await _client.from('posts').delete().inFilter('id', ids).select('id');
      _ensureAllAffected(deleted, ids.length, 'delete');
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to delete posts',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapPostgrestError(error, 'delete posts'), cause: error);
    }
  }

  /// RLS silently filters rows instead of erroring, so a missing UPDATE/DELETE
  /// policy shows up as "0 rows affected".
  void _ensureAllAffected(Object? rows, int expected, String action) {
    final affected = rows is List ? rows.length : 0;
    if (affected == 0) {
      throw AppFailure(
        'Could not $action posts. Make sure the posts admin policies '
        '(supabase/migrations/20261008_posts_admin_and_dashboard.sql) '
        'are applied.',
      );
    }
    if (affected < expected) {
      throw AppFailure(
        'Only $affected of $expected posts could be ${action}d. '
        'Refresh and try again.',
      );
    }
  }

  String _mapPostgrestError(PostgrestException error, String action) {
    final message = error.message.toLowerCase();
    if (error.code == '42501' ||
        message.contains('row-level security') ||
        message.contains('permission')) {
      return 'You are not authorized to $action.';
    }
    return 'Unable to $action. Please try again.';
  }
}
