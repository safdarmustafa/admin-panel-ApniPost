import 'dart:typed_data';

import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone_service.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtones_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements RingtonesRepository {
  bool failPut = false;
  bool failInsert = false;
  bool failDeleteObject = false;

  final calls = <String>[];
  Uint8List? uploadedBytes;

  @override
  Future<List<Ringtone>> fetchRingtones() async => const [];

  @override
  Future<RingtoneUploadTarget> prepareUpload({
    required String title,
    required String category,
    required String contentType,
    required int sizeBytes,
  }) async {
    calls.add('presign');
    return const RingtoneUploadTarget(
      objectKey: 'ringtones/love/tune-aaaaaa.mp3',
      publicUrl: 'https://media.apnipost.com/ringtones/love/tune-aaaaaa.mp3',
      uploadUrl: 'https://r2.example/put',
    );
  }

  @override
  Future<void> putToR2({
    required RingtoneUploadTarget target,
    required String contentType,
    required Uint8List bytes,
  }) async {
    calls.add('put');
    uploadedBytes = bytes;
    if (failPut) throw const AppFailure('blocked');
  }

  @override
  Future<StoredRingtoneFile> uploadViaProxy({
    required String title,
    required String category,
    required String contentType,
    required Uint8List bytes,
  }) async {
    calls.add('proxy');
    return const StoredRingtoneFile(
      objectKey: 'ringtones/love/tune-bbbbbb.mp3',
      publicUrl: 'https://media.apnipost.com/ringtones/love/tune-bbbbbb.mp3',
    );
  }

  @override
  Future<Ringtone> insertRingtone({
    required String title,
    required String category,
    required String audioUrl,
    required int durationSec,
  }) async {
    calls.add('insert:$audioUrl');
    if (failInsert) throw const AppFailure('insert failed');
    return Ringtone(
      id: '1',
      title: title,
      category: category,
      audioUrl: audioUrl,
      durationSec: durationSec,
      createdAt: null,
    );
  }

  @override
  Future<Ringtone> updateRingtone({
    required String id,
    required String title,
    required String category,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteRingtoneRow(String id) async => calls.add('deleteRow');

  @override
  Future<void> deleteObject(String objectKey) async {
    calls.add('deleteObject:$objectKey');
    if (failDeleteObject) throw const AppFailure('r2 down');
  }
}

RingtoneDraft _draft({String contentType = 'audio/mpeg', int duration = 25}) {
  return RingtoneDraft(
    title: 'Tune',
    category: 'Love',
    contentType: contentType,
    durationSec: duration,
    bytes: Uint8List.fromList([0xFF, 0xFB, 0x90, 0x64]),
  );
}

void main() {
  late _FakeRepository repo;
  late RingtoneService service;

  setUp(() {
    repo = _FakeRepository();
    service = RingtoneService(repo);
  });

  test('uploads then inserts the public URL', () async {
    final ringtone = await service.upload(_draft());
    expect(repo.calls, [
      'presign',
      'put',
      'insert:https://media.apnipost.com/ringtones/love/tune-aaaaaa.mp3',
    ]);
    expect(ringtone.durationSec, 25);
  });

  test('writes the ID3 title for MP3 only', () async {
    await service.upload(_draft());
    expect(String.fromCharCodes(repo.uploadedBytes!.sublist(0, 3)), 'ID3');

    await service.upload(_draft(contentType: 'audio/ogg'));
    expect(repo.uploadedBytes, [0xFF, 0xFB, 0x90, 0x64]);
  });

  test('falls back to the proxy when the browser PUT fails', () async {
    repo.failPut = true;
    await service.upload(_draft());
    expect(repo.calls, contains('proxy'));
    expect(
      repo.calls.last,
      'insert:https://media.apnipost.com/ringtones/love/tune-bbbbbb.mp3',
    );
  });

  test('deletes the uploaded file when the insert fails', () async {
    repo.failInsert = true;
    await expectLater(service.upload(_draft()), throwsA(isA<AppFailure>()));
    expect(repo.calls.last, 'deleteObject:ringtones/love/tune-aaaaaa.mp3');
  });

  test('refuses durations over 60 seconds before uploading', () async {
    await expectLater(
      service.upload(_draft(duration: 61)),
      throwsA(isA<AppFailure>()),
    );
    expect(repo.calls, isEmpty);
  });

  group('delete', () {
    const ringtone = Ringtone(
      id: '1',
      title: 'Durga Puja',
      category: 'Durga',
      audioUrl:
          'https://media.apnipost.com/ringtones/durga/durga-puja-ringtone-by-lobh-42083.mp3',
      durationSec: 30,
      createdAt: null,
    );

    test('removes the row first, then the file', () async {
      expect(await service.delete(ringtone), isTrue);
      expect(repo.calls, [
        'deleteRow',
        'deleteObject:ringtones/durga/durga-puja-ringtone-by-lobh-42083.mp3',
      ]);
    });

    test('reports a leftover file when R2 delete fails', () async {
      repo.failDeleteObject = true;
      expect(await service.delete(ringtone), isFalse);
      expect(repo.calls.first, 'deleteRow');
    });
  });
}
