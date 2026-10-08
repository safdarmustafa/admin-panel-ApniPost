import 'dart:js_interop';
import 'dart:typed_data';

import 'optimized_media.dart';

export 'optimized_media.dart';

@JS('apniMedia')
external _ApniMedia? get _apniMedia;

extension type _ApniMedia._(JSObject _) implements JSObject {
  external JSPromise<_OptimizeResult> optimize(
    JSUint8Array bytes,
    JSString mime,
    JSFunction? onProgress,
  );
}

extension type _OptimizeResult._(JSObject _) implements JSObject {
  external JSUint8Array get bytes;
  external JSString get mime;
  external JSBoolean get changed;
}

/// Compresses media in the browser via `globalThis.apniMedia` (loaded from
/// `web/media_compressor.js`).
Future<OptimizedMedia> optimizeMedia({
  required Uint8List bytes,
  required String contentType,
  void Function(double progress)? onProgress,
}) async {
  final api = _apniMedia;
  if (api == null) {
    throw StateError('Media compressor script is not loaded.');
  }

  final result = await api
      .optimize(
        bytes.toJS,
        contentType.toJS,
        onProgress == null
            ? null
            : ((JSNumber p) => onProgress(p.toDartDouble)).toJS,
      )
      .toDart;

  return OptimizedMedia(
    bytes: result.bytes.toDart,
    contentType: result.mime.toDart,
    changed: result.changed.toDart,
  );
}
