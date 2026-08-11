import 'dart:typed_data';

/// Browser-selected file used by the Data Upload feature.
class BrowserPickedFile {
  const BrowserPickedFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;
}
