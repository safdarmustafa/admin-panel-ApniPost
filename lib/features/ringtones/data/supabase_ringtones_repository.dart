import 'dart:convert';

import 'package:apnipost_admin/core/config/supabase_bootstrap.dart';
import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/core/utils/app_logger.dart';
import 'package:apnipost_admin/features/data_upload/data/r2_browser_put.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtones_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRingtonesRepository implements RingtonesRepository {
  SupabaseRingtonesRepository({SupabaseClient? client})
      : _client = client ?? SupabaseBootstrap.client;

  final SupabaseClient _client;

  static const _table = 'ringtones';
  static const _function = 'ringtone-r2';
  static const _columns = 'id, title, category, audio_url, duration_sec, created_at';
  static const _policyHint =
      'Make sure supabase/migrations/20261009_ringtones_admin_write_policies.sql '
      'is applied.';

  @override
  Future<List<Ringtone>> fetchRingtones() async {
    try {
      final rows = await _client
          .from(_table)
          .select(_columns)
          .order('created_at', ascending: false)
          .order('id');
      return rows.map(Ringtone.fromMap).toList(growable: false);
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to fetch ringtones',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(
        _mapPostgrestError(error, 'load ringtones'),
        cause: error,
      );
    } catch (error, stackTrace) {
      if (error is AppFailure) rethrow;
      AppLogger.error(
        'Failed to fetch ringtones unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(
        'Unable to load ringtones. Please try again.',
        cause: error,
      );
    }
  }

  @override
  Future<RingtoneUploadTarget> prepareUpload({
    required String title,
    required String category,
    required String contentType,
    required int sizeBytes,
  }) async {
    final data = await _invoke('presign', {
      'title': title,
      'category': category,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
    });
    debugPrint('[Ringtones] stage=presign OK objectKey=${data['objectKey']}');
    return RingtoneUploadTarget(
      objectKey: data['objectKey'] as String,
      publicUrl: data['publicUrl'] as String,
      uploadUrl: data['uploadUrl'] as String,
    );
  }

  @override
  Future<void> putToR2({
    required RingtoneUploadTarget target,
    required String contentType,
    required Uint8List bytes,
  }) async {
    // Never log uploadUrl (contains signature query params).
    late final int status;
    try {
      status = await putBytesToPresignedUrl(
        uploadUrl: target.uploadUrl,
        contentType: contentType,
        bytes: bytes,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[Ringtones] stage=r2_put FAILED objectKey=${target.objectKey}',
      );
      AppLogger.error(
        'Ringtone R2 PUT failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(
        'The browser could not upload this file to storage.',
        cause: error,
      );
    }

    if (status < 200 || status >= 300) {
      debugPrint(
        '[Ringtones] stage=r2_put FAILED httpStatus=$status '
        'objectKey=${target.objectKey}',
      );
      throw AppFailure(
        'Unable to upload this file to storage (HTTP $status).',
      );
    }
    debugPrint('[Ringtones] stage=r2_put OK objectKey=${target.objectKey}');
  }

  @override
  Future<StoredRingtoneFile> uploadViaProxy({
    required String title,
    required String category,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final data = await _invoke('proxy', {
      'title': title,
      'category': category,
      'contentType': contentType,
      'dataBase64': base64Encode(bytes),
    });
    debugPrint('[Ringtones] stage=proxy_put OK objectKey=${data['objectKey']}');
    return StoredRingtoneFile(
      objectKey: data['objectKey'] as String,
      publicUrl: data['publicUrl'] as String,
    );
  }

  @override
  Future<Ringtone> insertRingtone({
    required String title,
    required String category,
    required String audioUrl,
    required int durationSec,
  }) async {
    try {
      final row = await _client
          .from(_table)
          .insert({
            'title': title,
            'category': category,
            'audio_url': audioUrl,
            'duration_sec': durationSec,
          })
          .select(_columns)
          .single();
      debugPrint('[Ringtones] stage=db_insert OK');
      return Ringtone.fromMap(row);
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        '[Ringtones] stage=db_insert FAILED code=${error.code ?? '(none)'} '
        'message=${error.message}',
      );
      AppLogger.error(
        'ringtones insert failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(
        _mapPostgrestError(error, 'save ringtones'),
        cause: error,
      );
    }
  }

  @override
  Future<Ringtone> updateRingtone({
    required String id,
    required String title,
    required String category,
  }) async {
    try {
      final rows = await _client
          .from(_table)
          .update({'title': title, 'category': category})
          .eq('id', id)
          .select(_columns);
      // RLS silently filters rows instead of erroring.
      if (rows.isEmpty) {
        throw const AppFailure('Could not update the ringtone. $_policyHint');
      }
      return Ringtone.fromMap(rows.first);
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'ringtones update failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(
        _mapPostgrestError(error, 'update ringtones'),
        cause: error,
      );
    }
  }

  @override
  Future<void> deleteRingtoneRow(String id) async {
    try {
      final rows =
          await _client.from(_table).delete().eq('id', id).select('id');
      if (rows.isEmpty) {
        throw const AppFailure('Could not delete the ringtone. $_policyHint');
      }
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'ringtones delete failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(
        _mapPostgrestError(error, 'delete ringtones'),
        cause: error,
      );
    }
  }

  @override
  Future<void> deleteObject(String objectKey) async {
    await _invoke('delete', {'objectKey': objectKey});
    debugPrint('[Ringtones] stage=r2_delete OK objectKey=$objectKey');
  }

  Future<Map<String, dynamic>> _invoke(
    String action,
    Map<String, Object?> body,
  ) async {
    try {
      final response = await _client.functions.invoke(
        _function,
        body: {'action': action, ...body},
      );
      final data = _asMap(response.data);
      if (response.status < 200 || response.status >= 300 || data == null) {
        throw AppFailure(
          _mapFunctionError(response.status, response.data),
          cause: response.data,
        );
      }
      return data;
    } on FunctionException catch (error, stackTrace) {
      final message = _mapFunctionError(error.status, error.details);
      debugPrint(
        '[Ringtones] stage=$action FAILED httpStatus=${error.status} '
        'message=$message',
      );
      AppLogger.error(
        'ringtone-r2 $action failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(message, cause: error);
    } on AppFailure {
      rethrow;
    } catch (error, stackTrace) {
      AppLogger.error(
        'ringtone-r2 $action failed unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(
        'Ringtone storage is unreachable. Check your connection and try again.',
        cause: error,
      );
    }
  }

  String _mapFunctionError(int status, Object? details) {
    final map = _asMap(details);
    final code = map?['error']?.toString();
    final serverMessage = map?['message']?.toString();

    if (status == 401) {
      return 'Your session has expired. Please sign in again.';
    }
    if (status == 403 || code == 'ADMIN_ACCESS_REQUIRED') {
      return 'You are not authorized to manage ringtones.';
    }
    if (status == 404) {
      return 'The ringtone-r2 function is not deployed yet.';
    }
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return serverMessage;
    }
    return 'Ringtone storage is temporarily unavailable. Please try again.';
  }

  String _mapPostgrestError(PostgrestException error, String action) {
    final message = error.message.toLowerCase();
    if (error.code == '42501' ||
        message.contains('row-level security') ||
        message.contains('permission')) {
      return 'You are not authorized to $action. $_policyHint';
    }
    if (error.code == '23514') {
      return 'The ringtone was rejected: duration must be 1–60 seconds and '
          'title/category must not be empty.';
    }
    return 'Unable to $action. Please try again.';
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, dynamic val) => MapEntry(key.toString(), val));
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map(
            (key, dynamic val) => MapEntry(key.toString(), val),
          );
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
