import 'dart:convert';

import 'package:apnipost_admin/core/config/supabase_bootstrap.dart';
import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/core/utils/app_logger.dart';
import 'package:apnipost_admin/features/overview/domain/dashboard_stats.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardRepository {
  DashboardRepository({SupabaseClient? client})
      : _client = client ?? SupabaseBootstrap.client;

  final SupabaseClient _client;

  Future<DashboardStats> fetchStats() async {
    try {
      final data = await _client.rpc('admin_dashboard_stats');
      final map = data is String ? jsonDecode(data) : data;
      return DashboardStats.fromJson(Map<String, dynamic>.from(map as Map));
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Dashboard stats failed',
        error: error,
        stackTrace: stackTrace,
      );
      // PGRST202: function not found — migration not applied yet.
      if (error.code == 'PGRST202' || error.code == '42883') {
        throw AppFailure(
          'Dashboard data is not set up yet. Apply '
          'supabase/migrations/20261008_posts_admin_and_dashboard.sql '
          'in the Supabase SQL Editor.',
          cause: error,
        );
      }
      if (error.code == '42501') {
        throw AppFailure(
          'You are not authorized to view dashboard data.',
          cause: error,
        );
      }
      throw AppFailure(
        'Unable to load dashboard data. Please try again.',
        cause: error,
      );
    }
  }
}
