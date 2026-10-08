import 'dart:typed_data';

/// Result of browser-side compression (see `web/media_compressor.js`).
class OptimizedMedia {
  const OptimizedMedia({
    required this.bytes,
    required this.contentType,
    required this.changed,
  });

  final Uint8List bytes;
  final String contentType;

  /// False when the original was already small enough and is kept as-is.
  final bool changed;
}
