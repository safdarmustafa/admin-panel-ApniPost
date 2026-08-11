import 'dart:convert';

import 'package:apnipost_admin/core/config/supabase_bootstrap.dart';
import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/core/utils/app_logger.dart';
import 'package:apnipost_admin/features/data_upload/data/r2_browser_put.dart';
import 'package:apnipost_admin/features/data_upload/domain/upload_media_mapping.dart';
import 'package:apnipost_admin/features/data_upload/domain/upload_models.dart';
import 'package:apnipost_admin/features/data_upload/domain/upload_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseUploadRepository implements UploadRepository {
  SupabaseUploadRepository({
    SupabaseClient? client,
    http.Client? httpClient,
  })  : _client = client ?? SupabaseBootstrap.client,
        _http = httpClient ?? http.Client();

  final SupabaseClient _client;
  final http.Client _http;

  @override
  Future<List<PresignResponseItem>> createUploadUrls({
    required String categoryName,
    required List<PresignRequestFile> files,
  }) async {
    debugPrint(
      '[Upload] stage=presign start fileCount=${files.length} '
      'contentTypes=${files.map((f) => f.contentType).join(',')}',
    );

    try {
      final response = await _client.functions.invoke(
        'create-r2-upload-urls',
        body: {
          'category': categoryName,
          'files': files.map((f) => f.toJson()).toList(growable: false),
        },
      );

      final status = response.status;
      final data = response.data;

      debugPrint('[Upload] stage=presign httpStatus=$status');

      if (status < 200 || status >= 300) {
        final message = _mapFunctionError(status, data);
        final code = _asMap(data)?['error']?.toString();
        debugPrint(
          '[Upload] stage=presign FAILED httpStatus=$status '
          'errorCode=${code ?? '(none)'} message=$message',
        );
        throw AppFailure(message, cause: data);
      }

      if (data is! Map) {
        debugPrint(
          '[Upload] stage=presign FAILED httpStatus=$status '
          'message=unexpected response shape',
        );
        throw const AppFailure(
          'Unable to prepare uploads. Unexpected response from server.',
        );
      }

      final items = data['items'];
      if (items is! List || items.isEmpty) {
        debugPrint(
          '[Upload] stage=presign FAILED httpStatus=$status '
          'message=no items returned',
        );
        throw const AppFailure(
          'Unable to prepare uploads. No upload URLs were returned.',
        );
      }

      final parsed = [
        for (final item in items)
          PresignResponseItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
      ];

      debugPrint(
        '[Upload] stage=presign OK httpStatus=$status itemCount=${parsed.length} '
        'objectKeys=${parsed.map((i) => i.objectKey).join(',')} '
        'urlQueryKeys=${parsed.map((i) => _signedUrlQueryKeys(i.uploadUrl)).join(' | ')}',
      );
      return parsed;
    } on FunctionException catch (error, stackTrace) {
      final message = _mapFunctionError(error.status, error.details);
      final code = _asMap(error.details)?['error']?.toString();
      debugPrint(
        '[Upload] stage=presign FAILED httpStatus=${error.status} '
        'errorCode=${code ?? '(none)'} message=$message',
      );
      AppLogger.error(
        'Presign function failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(message, cause: error);
    } on AppFailure {
      rethrow;
    } catch (error, stackTrace) {
      final safe = _sanitizeError(error);
      debugPrint(
        '[Upload] stage=presign FAILED httpStatus=null message=$safe',
      );
      AppLogger.error(
        'Presign request failed unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(
        'Unable to prepare uploads. Please try again.',
        cause: error,
      );
    }
  }

  @override
  Future<void> uploadToR2({
    required String uploadUrl,
    required String contentType,
    required Uint8List bytes,
    String? objectKey,
  }) async {
    // Note: never log uploadUrl (contains signature query params).
    final host = _hostOnly(uploadUrl);
    debugPrint(
      '[Upload] stage=r2_put start host=$host contentType=$contentType '
      'bytes=${bytes.lengthInBytes} objectKey=${objectKey ?? '(unknown)'} '
      'urlQueryKeys=${_signedUrlQueryKeys(uploadUrl)}',
    );

    try {
      late final int status;
      try {
        status = await putBytesToPresignedUrl(
          uploadUrl: uploadUrl,
          contentType: contentType,
          bytes: bytes,
        );
      } on UnsupportedError {
        final response = await _http.put(
          Uri.parse(uploadUrl),
          headers: {'Content-Type': contentType},
          body: bytes,
        );
        status = response.statusCode;
      }

      debugPrint(
        '[Upload] stage=r2_put httpStatus=$status '
        'objectKey=${objectKey ?? '(unknown)'}',
      );

      if (status < 200 || status >= 300) {
        debugPrint(
          '[Upload] stage=r2_put FAILED httpStatus=$status '
          'objectKey=${objectKey ?? '(unknown)'}',
        );
        throw AppFailure(
          'Unable to upload this file to storage '
          '(HTTP $status). Please try again.',
        );
      }

      debugPrint(
        '[Upload] stage=r2_put OK httpStatus=$status '
        'objectKey=${objectKey ?? '(unknown)'}',
      );
    } on AppFailure {
      rethrow;
    } catch (error, stackTrace) {
      final safe = _sanitizeError(error);
      debugPrint(
        '[Upload] stage=r2_put FAILED httpStatus=null '
        'objectKey=${objectKey ?? '(unknown)'} message=$safe',
      );
      AppLogger.error(
        'R2 PUT failed unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );

      final lower = safe.toLowerCase();
      final looksLikeBrowserBlocked = lower.contains('failed to fetch') ||
          lower.contains('xmlhttprequest') ||
          lower.contains('network error') ||
          lower.contains('clientexception');

      throw AppFailure(
        looksLikeBrowserBlocked
            ? 'Unable to upload this file to storage. The browser blocked the '
                'request (often R2 CORS / signature). Will try proxy if allowed.'
            : 'Unable to upload this file to storage. Check your connection and try again.',
        cause: error,
      );
    }
  }

  @override
  Future<ProxyUploadResult> uploadViaProxy({
    required String categoryName,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    debugPrint(
      '[Upload] stage=proxy_put start bytes=${bytes.lengthInBytes} '
      'contentType=$contentType',
    );

    try {
      final response = await _client.functions.invoke(
        'proxy-r2-upload',
        body: {
          'category': categoryName,
          'fileName': fileName,
          'contentType': contentType,
          'dataBase64': base64Encode(bytes),
        },
      );

      final status = response.status;
      final data = response.data;
      debugPrint('[Upload] stage=proxy_put httpStatus=$status');

      if (status < 200 || status >= 300) {
        final mapped = _mapFunctionError(status, data);
        final detail = _asMap(data)?['message']?.toString();
        final message = (detail != null && detail.isNotEmpty)
            ? '$mapped ($detail)'
            : mapped;
        debugPrint(
          '[Upload] stage=proxy_put FAILED httpStatus=$status message=$message',
        );
        throw AppFailure(message, cause: data);
      }

      if (data is! Map) {
        throw const AppFailure(
          'Proxy upload failed. Unexpected response from server.',
        );
      }

      final result = ProxyUploadResult.fromJson(
        Map<String, dynamic>.from(data),
      );
      debugPrint(
        '[Upload] stage=proxy_put OK objectKey=${result.objectKey}',
      );
      return result;
    } on FunctionException catch (error, stackTrace) {
      final message = _mapFunctionError(error.status, error.details);
      debugPrint(
        '[Upload] stage=proxy_put FAILED httpStatus=${error.status} '
        'message=$message',
      );
      AppLogger.error(
        'Proxy upload function failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(message, cause: error);
    } on AppFailure {
      rethrow;
    } catch (error, stackTrace) {
      final safe = _sanitizeError(error);
      debugPrint('[Upload] stage=proxy_put FAILED message=$safe');
      AppLogger.error(
        'Proxy upload failed unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(
        'Unable to upload this file via proxy. Please try again.',
        cause: error,
      );
    }
  }

  @override
  Future<void> insertPost({
    required String categoryName,
    required String mediaUrl,
    required PostMediaType mediaType,
  }) async {
    // Never log full mediaUrl query fragments; host+path is enough.
    final mediaHostPath = _hostAndPath(mediaUrl);
    debugPrint(
      '[Upload] stage=db_insert start mediaType=${mediaType.dbValue} '
      'media=$mediaHostPath',
    );

    try {
      await _client.from('posts').insert({
        'category': categoryName,
        'media_url': mediaUrl,
        'media_type': mediaType.dbValue,
      });
      debugPrint('[Upload] stage=db_insert OK');
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        '[Upload] stage=db_insert FAILED code=${error.code ?? '(none)'} '
        'message=${error.message}',
      );
      AppLogger.error(
        'posts insert failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapPostgrestError(error), cause: error);
    } catch (error, stackTrace) {
      if (error is AppFailure) rethrow;
      final safe = _sanitizeError(error);
      debugPrint(
        '[Upload] stage=db_insert FAILED code=(none) message=$safe',
      );
      AppLogger.error(
        'posts insert failed unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(
        'Uploaded to storage, but saving the content record failed.',
        cause: error,
      );
    }
  }

  @override
  Future<bool> categoryExists(String categoryName) async {
    try {
      final row = await _client
          .from('categories')
          .select('name')
          .eq('name', categoryName)
          .maybeSingle();
      return row != null && row['name'] != null;
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error(
        'Category existence check failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(
        'Unable to verify the selected category. Please try again.',
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
      return 'You are not authorized to upload content.';
    }
    if (code == 'CATEGORY_NOT_FOUND') {
      return 'The selected category was not found. Refresh and try again.';
    }
    if (code == 'TOO_MANY_FILES') {
      return 'Too many files in this batch. Reduce the selection and try again.';
    }
    if (code == 'UNSUPPORTED_MEDIA_TYPE') {
      return serverMessage ?? 'Unsupported file type.';
    }
    if (code == 'FILE_TOO_LARGE') {
      return serverMessage ?? 'One or more files are too large.';
    }
    if (code == 'INVALID_REQUEST') {
      return serverMessage ?? 'The upload request was invalid. Please try again.';
    }
    // Prefer server detail for ops debugging (never includes secrets).
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return serverMessage;
    }
    if (status >= 500 ||
        code == 'INTERNAL_ERROR' ||
        code == 'CONFIGURATION_ERROR') {
      return 'Upload service is temporarily unavailable. Please try again later.';
    }
    return 'Unable to prepare uploads. Please try again.';
  }

  String _mapPostgrestError(PostgrestException error) {
    final message = error.message.toLowerCase();
    final code = error.code;
    if (code == '42501' ||
        message.contains('row-level security') ||
        message.contains('permission')) {
      return 'You are not authorized to create content records.';
    }
    return 'Uploaded to storage, but saving the content record failed.';
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

  String _hostOnly(String url) {
    final uri = Uri.tryParse(url);
    return uri?.host.isNotEmpty == true ? uri!.host : '(unknown-host)';
  }

  /// Safe: query *names* only (never values / signatures).
  String _signedUrlQueryKeys(String uploadUrl) {
    final uri = Uri.tryParse(uploadUrl);
    if (uri == null) return '(invalid)';
    final keys = uri.queryParameters.keys.toList()..sort();
    return keys.isEmpty ? '(none)' : keys.join(',');
  }

  String _hostAndPath(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return '(unknown-media)';
    return '${uri.host}${uri.path}';
  }

  /// Strips query strings / long credential-like tokens from error text.
  String _sanitizeError(Object error) {
    var text = error.toString();
    text = text.replaceAll(RegExp(r'\?[^\s]+'), '?[redacted]');
    text = text.replaceAll(
      RegExp(r'(signature|x-amz-credential|token)=[^&\s]+', caseSensitive: false),
      r'$1=[redacted]',
    );
    if (text.length > 300) {
      text = '${text.substring(0, 300)}…';
    }
    return text;
  }
}
