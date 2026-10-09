import 'dart:typed_data';

import 'package:apnipost_admin/features/ringtones/domain/ringtone.dart';

abstract class RingtonesRepository {
  /// All ringtones, newest first (same order as the app).
  Future<List<Ringtone>> fetchRingtones();

  /// Presigned R2 PUT via `ringtone-r2` (server builds the object key).
  Future<RingtoneUploadTarget> prepareUpload({
    required String title,
    required String category,
    required String contentType,
    required int sizeBytes,
  });

  /// Direct browser PUT to the presigned URL.
  Future<void> putToR2({
    required RingtoneUploadTarget target,
    required String contentType,
    required Uint8List bytes,
  });

  /// Server-side R2 upload fallback when the browser PUT is blocked.
  Future<StoredRingtoneFile> uploadViaProxy({
    required String title,
    required String category,
    required String contentType,
    required Uint8List bytes,
  });

  Future<Ringtone> insertRingtone({
    required String title,
    required String category,
    required String audioUrl,
    required int durationSec,
  });

  Future<Ringtone> updateRingtone({
    required String id,
    required String title,
    required String category,
  });

  Future<void> deleteRingtoneRow(String id);

  /// Deletes an object under `ringtones/` via `ringtone-r2`.
  Future<void> deleteObject(String objectKey);
}
