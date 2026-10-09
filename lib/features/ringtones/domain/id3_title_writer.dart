import 'dart:typed_data';

/// Replaces an MP3's ID3 tags with one ID3v2.3 tag holding only the title
/// (TIT2), so Android's sound settings show the admin-entered title instead
/// of whatever the source file carried.
///
/// Other tag data (artist, cover art, …) is dropped on purpose; ringtones
/// don't need it. Audio frames are left untouched.
abstract final class Id3TitleWriter {
  static Uint8List withTitle(Uint8List mp3, String title) {
    final audio = stripTags(mp3);
    final tag = _buildTag(title);
    return Uint8List(tag.length + audio.length)
      ..setAll(0, tag)
      ..setAll(tag.length, audio);
  }

  /// Removes leading ID3v2 tag(s) and a trailing ID3v1 tag.
  static Uint8List stripTags(Uint8List bytes) {
    var start = 0;
    while (_hasId3v2At(bytes, start)) {
      final flags = bytes[start + 5];
      final size = _readSynchsafe(bytes, start + 6);
      final hasFooter = bytes[start + 3] == 4 && (flags & 0x10) != 0;
      final next = start + 10 + size + (hasFooter ? 10 : 0);
      if (next > bytes.length) break;
      start = next;
    }

    var end = bytes.length;
    if (end - start >= 128 &&
        bytes[end - 128] == 0x54 && // T
        bytes[end - 127] == 0x41 && // A
        bytes[end - 126] == 0x47) {
      // G
      end -= 128;
    }

    return Uint8List.sublistView(bytes, start, end);
  }

  static bool _hasId3v2At(Uint8List bytes, int offset) {
    return bytes.length >= offset + 10 &&
        bytes[offset] == 0x49 && // I
        bytes[offset + 1] == 0x44 && // D
        bytes[offset + 2] == 0x33 && // 3
        bytes[offset + 3] != 0xFF &&
        bytes[offset + 4] != 0xFF &&
        (bytes[offset + 6] |
                bytes[offset + 7] |
                bytes[offset + 8] |
                bytes[offset + 9]) <
            0x80;
  }

  static int _readSynchsafe(Uint8List bytes, int offset) {
    return (bytes[offset] << 21) |
        (bytes[offset + 1] << 14) |
        (bytes[offset + 2] << 7) |
        bytes[offset + 3];
  }

  static Uint8List _buildTag(String title) {
    // TIT2 text: encoding 0x01 (UTF-16 with BOM) so Hindi titles survive.
    final units = title.trim().codeUnits;
    final text = BytesBuilder()
      ..addByte(0x01)
      ..add([0xFF, 0xFE]); // little-endian BOM
    for (final unit in units) {
      text
        ..addByte(unit & 0xFF)
        ..addByte(unit >> 8);
    }
    text.add([0x00, 0x00]);
    final frameBody = text.takeBytes();

    final frameSize = frameBody.length;
    final frame = BytesBuilder()
      ..add('TIT2'.codeUnits)
      // ID3v2.3 frame sizes are plain big-endian (not synchsafe).
      ..add([
        (frameSize >> 24) & 0xFF,
        (frameSize >> 16) & 0xFF,
        (frameSize >> 8) & 0xFF,
        frameSize & 0xFF,
      ])
      ..add([0x00, 0x00])
      ..add(frameBody);
    final frames = frame.takeBytes();

    final tagSize = frames.length;
    return (BytesBuilder()
          ..add('ID3'.codeUnits)
          ..add([0x03, 0x00, 0x00]) // v2.3.0, no flags
          ..add([
            (tagSize >> 21) & 0x7F,
            (tagSize >> 14) & 0x7F,
            (tagSize >> 7) & 0x7F,
            tagSize & 0x7F,
          ])
          ..add(frames))
        .takeBytes();
  }
}
