import 'package:flutter/foundation.dart';

/// Non-web fallback — the admin app targets Flutter Web.
String createBlobUrl(Uint8List bytes, String mimeType) {
  throw UnsupportedError('Blob URLs are only supported on Flutter Web.');
}

void revokeBlobUrl(String url) {}

Future<double?> probeAudioDuration(
  String url, {
  Duration timeout = const Duration(seconds: 15),
}) async =>
    null;

class AudioPreviewPlayer extends ChangeNotifier {
  AudioPreviewPlayer._();

  static final AudioPreviewPlayer instance = AudioPreviewPlayer._();

  String? currentUrl;
  String? failedUrl;

  bool isPlaying(String url) => false;

  double get progress => 0;

  void toggle(String url) {}

  void stopIfPlaying(String url) {}

  void stop() {}
}
