import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// `blob:` URL for local bytes (preview + duration probe before upload).
/// Release it with [revokeBlobUrl].
String createBlobUrl(Uint8List bytes, String mimeType) {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  return web.URL.createObjectURL(blob);
}

void revokeBlobUrl(String url) => web.URL.revokeObjectURL(url);

/// Reads the audio length in seconds with an `<audio>` element
/// (`loadedmetadata`). Returns null when the browser can't decode it.
Future<double?> probeAudioDuration(
  String url, {
  Duration timeout = const Duration(seconds: 15),
}) {
  final completer = Completer<double?>();
  final audio = web.HTMLAudioElement()..preload = 'metadata';

  void finish(double? value) {
    if (completer.isCompleted) return;
    completer.complete(value);
    audio
      ..removeAttribute('src')
      ..load();
  }

  audio
    ..onLoadedMetadata.first.then((_) {
      final duration = audio.duration;
      finish(duration.isFinite && duration > 0 ? duration.toDouble() : null);
    })
    ..onError.first.then((_) => finish(null))
    ..src = url;

  return completer.future.timeout(timeout, onTimeout: () {
    finish(null);
    return null;
  });
}

/// One shared `<audio>` element so only a single ringtone plays at a time.
/// Media on media.apnipost.com has no CORS headers, which plain `<audio>`
/// playback does not need.
class AudioPreviewPlayer extends ChangeNotifier {
  AudioPreviewPlayer._() {
    _audio
      ..preload = 'none'
      ..onTimeUpdate.listen((_) => notifyListeners())
      ..onEnded.listen((_) => _reset())
      ..onError.listen((_) {
        failedUrl = currentUrl;
        _reset();
      });
  }

  static final AudioPreviewPlayer instance = AudioPreviewPlayer._();

  final web.HTMLAudioElement _audio = web.HTMLAudioElement();

  /// URL that is playing (or loading), if any.
  String? currentUrl;

  /// Last URL that failed to load, so the UI can show an error icon.
  String? failedUrl;

  bool isPlaying(String url) => currentUrl == url;

  /// 0..1 progress of [currentUrl].
  double get progress {
    final duration = _audio.duration;
    if (currentUrl == null || !duration.isFinite || duration <= 0) return 0;
    return (_audio.currentTime / duration).clamp(0, 1).toDouble();
  }

  void toggle(String url) {
    if (currentUrl == url) {
      stop();
      return;
    }
    failedUrl = null;
    currentUrl = url;
    _audio
      ..src = url
      ..currentTime = 0;
    _audio.play().toDart.catchError((Object _) {
      failedUrl = url;
      _reset();
      return null;
    });
    notifyListeners();
  }

  /// Stops [url] only if it is the one playing (e.g. a row being removed).
  void stopIfPlaying(String url) {
    if (currentUrl == url) stop();
  }

  void stop() {
    _audio.pause();
    _reset();
  }

  void _reset() {
    _audio
      ..removeAttribute('src')
      ..load();
    currentUrl = null;
    notifyListeners();
  }
}
