import 'dart:typed_data';

import 'optimized_media.dart';

export 'optimized_media.dart';

/// Non-web fallback — the admin app targets Flutter Web.
Future<OptimizedMedia> optimizeMedia({
  required Uint8List bytes,
  required String contentType,
  void Function(double progress)? onProgress,
}) {
  throw UnsupportedError('Media optimization is only supported on Flutter Web.');
}
