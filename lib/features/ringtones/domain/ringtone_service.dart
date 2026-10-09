import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/core/utils/app_logger.dart';
import 'package:apnipost_admin/features/ringtones/domain/id3_title_writer.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone_rules.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtones_repository.dart';
import 'package:flutter/foundation.dart';

/// Multi-step ringtone operations that must keep R2 and the
/// `ringtones` table in sync.
class RingtoneService {
  const RingtoneService(this._repository);

  final RingtonesRepository _repository;

  /// R2 upload → `ringtones` insert. If the insert fails the uploaded object
  /// is deleted so no orphan file is left behind.
  Future<Ringtone> upload(RingtoneDraft draft) async {
    final durationError = RingtoneRules.durationError(draft.durationSec);
    if (durationError != null) throw AppFailure(durationError);

    final bytes = draft.contentType == 'audio/mpeg'
        ? Id3TitleWriter.withTitle(draft.bytes, draft.title)
        : draft.bytes;

    final stored = await _store(draft, bytes);

    try {
      return await _repository.insertRingtone(
        title: draft.title,
        category: draft.category,
        audioUrl: stored.publicUrl,
        durationSec: draft.durationSec,
      );
    } catch (error) {
      debugPrint(
        '[Ringtones] insert failed; removing ${stored.objectKey} from R2',
      );
      try {
        await _repository.deleteObject(stored.objectKey);
      } catch (cleanupError, stackTrace) {
        AppLogger.error(
          'Orphan ringtone file could not be removed: ${stored.objectKey}',
          error: cleanupError,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }

  Future<StoredRingtoneFile> _store(RingtoneDraft draft, Uint8List bytes) async {
    final target = await _repository.prepareUpload(
      title: draft.title,
      category: draft.category,
      contentType: draft.contentType,
      sizeBytes: bytes.lengthInBytes,
    );

    try {
      await _repository.putToR2(
        target: target,
        contentType: draft.contentType,
        bytes: bytes,
      );
      return target;
    } on AppFailure {
      if (bytes.lengthInBytes > RingtoneRules.maxProxyBytes) rethrow;
      debugPrint('[Ringtones] direct R2 PUT failed; falling back to proxy');
      return _repository.uploadViaProxy(
        title: draft.title,
        category: draft.category,
        contentType: draft.contentType,
        bytes: bytes,
      );
    }
  }

  /// Deletes the row first (the app stops showing it), then the R2 file.
  ///
  /// Returns false when the row is gone but the file could not be removed.
  Future<bool> delete(Ringtone ringtone) async {
    await _repository.deleteRingtoneRow(ringtone.id);

    final key = RingtoneRules.objectKeyFromUrl(ringtone.audioUrl);
    if (key == null) return false;
    try {
      await _repository.deleteObject(key);
      return true;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Ringtone row deleted but R2 file remains: $key',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
