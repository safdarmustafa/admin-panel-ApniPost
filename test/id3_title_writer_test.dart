import 'dart:convert';
import 'dart:typed_data';

import 'package:apnipost_admin/features/ringtones/domain/id3_title_writer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake MPEG audio frames (only the sync bytes matter here).
final _audio = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x64, 1, 2, 3, 4, 5]);

Uint8List _id3v2(List<int> body) {
  final size = body.length;
  return Uint8List.fromList([
    ...ascii.encode('ID3'),
    0x04, 0x00, 0x00,
    (size >> 21) & 0x7F, (size >> 14) & 0x7F, (size >> 7) & 0x7F, size & 0x7F,
    ...body,
  ]);
}

Uint8List _id3v1() {
  final tag = Uint8List(128);
  tag.setAll(0, ascii.encode('TAGOld Title'));
  return tag;
}

String _readTit2(Uint8List tagged) {
  expect(ascii.decode(tagged.sublist(0, 3)), 'ID3');
  expect(tagged[3], 3);
  expect(ascii.decode(tagged.sublist(10, 14)), 'TIT2');
  final frameSize = (tagged[14] << 24) |
      (tagged[15] << 16) |
      (tagged[16] << 8) |
      tagged[17];
  final body = tagged.sublist(20, 20 + frameSize);
  expect(body[0], 0x01); // UTF-16 with BOM
  expect(body.sublist(1, 3), [0xFF, 0xFE]);
  final units = <int>[];
  for (var i = 3; i + 1 < body.length - 2; i += 2) {
    units.add(body[i] | (body[i + 1] << 8));
  }
  return String.fromCharCodes(units);
}

void main() {
  test('adds a title tag to an untagged file', () {
    final out = Id3TitleWriter.withTitle(_audio, 'Jai Ganesh Deva');
    expect(_readTit2(out), 'Jai Ganesh Deva');
    expect(out.sublist(out.length - _audio.length), _audio);
  });

  test('replaces existing ID3v2 and ID3v1 tags', () {
    final input = Uint8List.fromList([
      ..._id3v2(List.filled(300, 0x41)),
      ..._audio,
      ..._id3v1(),
    ]);
    final out = Id3TitleWriter.withTitle(input, 'Ram Siya Ram');
    expect(_readTit2(out), 'Ram Siya Ram');
    expect(out.sublist(out.length - _audio.length), _audio);
    expect(Id3TitleWriter.stripTags(out), _audio);
  });

  test('keeps Hindi titles intact', () {
    final out = Id3TitleWriter.withTitle(_audio, 'जय गणेश');
    expect(_readTit2(out), 'जय गणेश');
  });

  test('declared tag size matches the bytes written', () {
    final out = Id3TitleWriter.withTitle(_audio, 'Love');
    final size =
        (out[6] << 21) | (out[7] << 14) | (out[8] << 7) | out[9];
    expect(out.length, 10 + size + _audio.length);
  });
}
