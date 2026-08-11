import 'dart:typed_data';

/// Non-web fallback — the admin app targets Flutter Web.
Future<int> putBytesToPresignedUrl({
  required String uploadUrl,
  required String contentType,
  required Uint8List bytes,
}) {
  throw UnsupportedError('Browser R2 PUT is only supported on Flutter Web.');
}
