// Temporary Phase 4A verification tool.
//
// Verifies deployed create-r2-upload-urls presigned URL generation only.
// Does NOT PUT bytes to R2. Does NOT modify production app code.
// Uses dart:io only (no extra production dependencies).
//
// Run:
//   export SUPABASE_URL="https://nnexolilmowmcrwlgzfm.supabase.co"
//   export SUPABASE_ANON_KEY="<anon-or-publishable-key>"
//   export ADMIN_EMAIL="<admin-email>"
//   export ADMIN_PASSWORD="<admin-password>"
//   dart run tool/test_r2_upload_function.dart
//
// Never commit credentials. Tokens and uploadUrl are redacted in output.

import 'dart:convert';
import 'dart:io';

const _functionPath = '/functions/v1/create-r2-upload-urls';
const _expectedCategory = 'Updesh';
const _expectedPublicPrefix = 'https://media.apnipost.com/updesh/';
const _expectedObjectKeyPrefix = 'updesh/';

Future<void> main() async {
  final url = Platform.environment['SUPABASE_URL']?.trim() ?? '';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY']?.trim() ?? '';
  final email = Platform.environment['ADMIN_EMAIL']?.trim() ?? '';
  final password = Platform.environment['ADMIN_PASSWORD'] ?? '';

  if (url.isEmpty || anonKey.isEmpty || email.isEmpty || password.isEmpty) {
    stderr.writeln('''
Missing required environment variables.

Required:
  SUPABASE_URL
  SUPABASE_ANON_KEY
  ADMIN_EMAIL
  ADMIN_PASSWORD

Example:
  export SUPABASE_URL="https://nnexolilmowmcrwlgzfm.supabase.co"
  export SUPABASE_ANON_KEY="<anon-or-publishable-key>"
  export ADMIN_EMAIL="you@example.com"
  export ADMIN_PASSWORD='***'
  dart run tool/test_r2_upload_function.dart
''');
    exitCode = 64;
    return;
  }

  final baseUrl = url.replaceAll(RegExp(r'/+$'), '');

  stdout.writeln('Phase 4A — create-r2-upload-urls verification');
  stdout.writeln('Endpoint: $baseUrl$_functionPath');
  stdout.writeln('Category: $_expectedCategory');
  stdout.writeln('Actual R2 PUT upload: NO (presign only)');
  stdout.writeln('');

  final client = HttpClient();
  try {
    // 1) Password login
    stdout.writeln('1) Signing in...');
    final authResult = await _signIn(
      client: client,
      baseUrl: baseUrl,
      anonKey: anonKey,
      email: email,
      password: password,
    );

    if (!authResult.ok) {
      stdout.writeln('AUTHENTICATION RESULT: FAILED');
      stdout.writeln('HTTP STATUS: ${authResult.status}');
      stdout.writeln(
        'Diagnosis: authentication problem (${authResult.message}).',
      );
      exitCode = 1;
      return;
    }

    final accessToken = authResult.accessToken!;
    final role = authResult.role;
    final isAdmin = role == 'admin';

    stdout.writeln(
      'AUTHENTICATION RESULT: SUCCESS (JWT present, token redacted)',
    );
    stdout.writeln(
      'ADMIN AUTHORIZATION: ${isAdmin ? 'SUCCESS (app_metadata.role=admin)' : 'FAILED (role=${role ?? 'missing'})'}',
    );
    if (!isAdmin) {
      stdout.writeln(
        'Diagnosis: admin authorization problem — Edge Function will return 403.',
      );
    }

    // 2) Invoke Edge Function
    stdout.writeln('2) Calling Edge Function (presign only)...');
    final invoke = await _invokeCreateUploadUrls(
      client: client,
      baseUrl: baseUrl,
      anonKey: anonKey,
      accessToken: accessToken,
    );

    stdout.writeln('HTTP STATUS: ${invoke.status}');

    if (invoke.status != 200) {
      _reportFunctionFailure(
        status: invoke.status,
        body: invoke.body,
      );
      exitCode = 1;
      return;
    }

    final map = invoke.body;
    if (map == null) {
      stdout.writeln('PRESIGNED URL GENERATION: FAILED');
      stdout.writeln('Diagnosis: unexpected/non-JSON response body.');
      exitCode = 1;
      return;
    }

    final items = map['items'];
    if (items is! List || items.isEmpty) {
      stdout.writeln('CATEGORY VALIDATION: UNKNOWN (no items in success payload)');
      stdout.writeln('PRESIGNED URL GENERATION: FAILED (missing items[])');
      exitCode = 1;
      return;
    }

    final first = items.first;
    if (first is! Map) {
      stdout.writeln('PRESIGNED URL GENERATION: FAILED (invalid item shape)');
      exitCode = 1;
      return;
    }

    final item = Map<String, dynamic>.from(first);
    final clientFileName = item['clientFileName']?.toString();
    final contentType = item['contentType']?.toString();
    final objectKey = item['objectKey']?.toString();
    final uploadUrl = item['uploadUrl']?.toString();
    final publicUrl = item['publicUrl']?.toString();

    final hasAllFields = clientFileName != null &&
        contentType != null &&
        objectKey != null &&
        uploadUrl != null &&
        publicUrl != null &&
        uploadUrl.isNotEmpty;

    stdout.writeln('CATEGORY VALIDATION: SUCCESS (Updesh accepted by function)');
    stdout.writeln(
      'PRESIGNED URL GENERATION: ${hasAllFields ? 'SUCCESS' : 'FAILED'}',
    );
    stdout.writeln('clientFileName: $clientFileName');
    stdout.writeln('contentType: $contentType');
    stdout.writeln('objectKey: $objectKey');
    stdout.writeln('publicUrl: $publicUrl');
    stdout.writeln('uploadUrl: <REDACTED>');

    final objectKeyOk =
        objectKey != null && objectKey.startsWith(_expectedObjectKeyPrefix);
    final publicUrlOk =
        publicUrl != null && publicUrl.startsWith(_expectedPublicPrefix);
    final contentTypeOk = contentType == 'image/jpeg';
    final fileNameOk = clientFileName == 'phase4-test.jpg';

    stdout.writeln(
      'OBJECT KEY PREFIX CHECK (updesh/): ${objectKeyOk ? 'PASS' : 'FAIL'}',
    );
    stdout.writeln(
      'PUBLIC URL PREFIX CHECK (https://media.apnipost.com/updesh/): '
      '${publicUrlOk ? 'PASS' : 'FAIL'}',
    );
    stdout.writeln('Actual R2 upload performed: NO');

    final redactedPreview = <String, dynamic>{
      'items': [
        {
          'clientFileName': clientFileName,
          'contentType': contentType,
          'objectKey': objectKey,
          'uploadUrl': '<REDACTED>',
          'publicUrl': publicUrl,
        },
      ],
    };
    stdout.writeln('Response preview (redacted):');
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert(redactedPreview),
    );

    if (!hasAllFields ||
        !objectKeyOk ||
        !publicUrlOk ||
        !contentTypeOk ||
        !fileNameOk) {
      exitCode = 1;
      return;
    }

    stdout.writeln('');
    stdout.writeln('VERIFICATION RESULT: PASS');
  } finally {
    client.close(force: true);
  }
}

class _AuthResult {
  const _AuthResult._({
    required this.ok,
    required this.status,
    this.accessToken,
    this.role,
    this.message = '',
  });

  const _AuthResult.success({
    required String accessToken,
    required String? role,
    required int status,
  }) : this._(
          ok: true,
          status: status,
          accessToken: accessToken,
          role: role,
        );

  const _AuthResult.failure({
    required int status,
    required String message,
  }) : this._(ok: false, status: status, message: message);

  final bool ok;
  final int status;
  final String? accessToken;
  final String? role;
  final String message;
}

class _InvokeResult {
  const _InvokeResult({
    required this.status,
    required this.body,
  });

  final int status;
  final Map<String, dynamic>? body;
}

Future<_AuthResult> _signIn({
  required HttpClient client,
  required String baseUrl,
  required String anonKey,
  required String email,
  required String password,
}) async {
  final uri = Uri.parse('$baseUrl/auth/v1/token?grant_type=password');
  final request = await client.postUrl(uri);
  request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
  request.headers.set('apikey', anonKey);
  request.add(
    utf8.encode(
      jsonEncode({
        'email': email,
        'password': password,
      }),
    ),
  );

  final response = await request.close();
  final raw = await response.transform(utf8.decoder).join();
  final status = response.statusCode;

  Map<String, dynamic>? body;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      body = decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {
    body = null;
  }

  if (status < 200 || status >= 300 || body == null) {
    return _AuthResult.failure(
      status: status,
      message: _safeAuthMessage(body?['error_description']?.toString() ??
          body?['msg']?.toString() ??
          body?['error']?.toString() ??
          'sign-in rejected'),
    );
  }

  final accessToken = body['access_token']?.toString();
  if (accessToken == null || accessToken.isEmpty) {
    return const _AuthResult.failure(
      status: 401,
      message: 'no access token in auth response',
    );
  }

  String? role;
  final user = body['user'];
  if (user is Map) {
    final appMetadata = user['app_metadata'];
    if (appMetadata is Map) {
      role = appMetadata['role']?.toString();
    }
  }

  return _AuthResult.success(
    accessToken: accessToken,
    role: role,
    status: status,
  );
}

Future<_InvokeResult> _invokeCreateUploadUrls({
  required HttpClient client,
  required String baseUrl,
  required String anonKey,
  required String accessToken,
}) async {
  final uri = Uri.parse('$baseUrl$_functionPath');
  final request = await client.postUrl(uri);
  request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
  request.headers.set('apikey', anonKey);
  request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
  request.add(
    utf8.encode(
      jsonEncode({
        'category': _expectedCategory,
        'files': [
          {
            'fileName': 'phase4-test.jpg',
            'contentType': 'image/jpeg',
            'sizeBytes': 1024,
          },
        ],
      }),
    ),
  );

  final response = await request.close();
  final raw = await response.transform(utf8.decoder).join();
  final status = response.statusCode;

  Map<String, dynamic>? body;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      body = decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {
    body = null;
  }

  return _InvokeResult(status: status, body: body);
}

void _reportFunctionFailure({
  required int status,
  required Map<String, dynamic>? body,
}) {
  final errorCode = body?['error']?.toString();
  final message = body?['message']?.toString();

  if (errorCode != null) {
    stdout.writeln('ERROR CODE: $errorCode');
  }
  if (message != null && message.isNotEmpty) {
    stdout.writeln('ERROR MESSAGE: $message');
  }
  if (body != null) {
    // Body should not contain secrets; still redact accidental URL-ish fields.
    final safe = Map<String, dynamic>.from(body);
    if (safe.containsKey('uploadUrl')) {
      safe['uploadUrl'] = '<REDACTED>';
    }
    stdout.writeln('RESPONSE BODY: ${jsonEncode(safe)}');
  } else {
    stdout.writeln('RESPONSE BODY: <empty or non-JSON>');
  }

  switch (status) {
    case 401:
      stdout.writeln('Diagnosis: authentication problem.');
    case 403:
      stdout.writeln('Diagnosis: admin authorization problem.');
    case 400:
      if (errorCode == 'CATEGORY_NOT_FOUND') {
        stdout.writeln(
          'Diagnosis: category lookup problem (Updesh not found).',
        );
      } else {
        stdout.writeln(
          'Diagnosis: request validation problem'
          '${errorCode != null ? ' ($errorCode)' : ''}.',
        );
      }
    case 500:
      stdout.writeln(
        'Diagnosis: likely R2 credentials / signing / configuration problem '
        'on the Edge Function (check R2_* secrets).',
      );
    default:
      stdout.writeln('Diagnosis: unexpected failure (status $status).');
  }

  stdout.writeln('PRESIGNED URL GENERATION: FAILED');
  stdout.writeln('Actual R2 upload performed: NO');
}

String _safeAuthMessage(String message) {
  final lowered = message.toLowerCase();
  if (lowered.contains('invalid login credentials')) {
    return 'invalid login credentials';
  }
  if (lowered.contains('email not confirmed')) {
    return 'email not confirmed';
  }
  if (lowered.contains('access token')) {
    return 'no access token in auth response';
  }
  return 'sign-in rejected';
}
