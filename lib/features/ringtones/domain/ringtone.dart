import 'package:flutter/foundation.dart';

/// A row in `public.ringtones` (read by the Android app's Ringtones screen).
@immutable
class Ringtone {
  const Ringtone({
    required this.id,
    required this.title,
    required this.category,
    required this.audioUrl,
    required this.durationSec,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String category;
  final String audioUrl;
  final int durationSec;
  final DateTime? createdAt;

  factory Ringtone.fromMap(Map<String, dynamic> map) {
    return Ringtone(
      id: map['id'].toString(),
      title: (map['title'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      audioUrl: (map['audio_url'] as String?) ?? '',
      durationSec: (map['duration_sec'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  Ringtone copyWith({String? title, String? category}) {
    return Ringtone(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      audioUrl: audioUrl,
      durationSec: durationSec,
      createdAt: createdAt,
    );
  }
}

/// A file ready to upload: validated title/category plus probed duration.
@immutable
class RingtoneDraft {
  const RingtoneDraft({
    required this.title,
    required this.category,
    required this.contentType,
    required this.durationSec,
    required this.bytes,
  });

  final String title;
  final String category;
  final String contentType;
  final int durationSec;
  final Uint8List bytes;
}

/// Where an uploaded file landed in R2.
@immutable
class StoredRingtoneFile {
  const StoredRingtoneFile({
    required this.objectKey,
    required this.publicUrl,
  });

  final String objectKey;
  final String publicUrl;
}

/// Short-lived presigned PUT target from `ringtone-r2`.
@immutable
class RingtoneUploadTarget extends StoredRingtoneFile {
  const RingtoneUploadTarget({
    required super.objectKey,
    required super.publicUrl,
    required this.uploadUrl,
  });

  final String uploadUrl;
}
