import 'browser_picked_file.dart';

export 'browser_picked_file.dart';

/// Non-web stub. Flutter Web compiles [browser_file_picker_web.dart] instead.
abstract final class BrowserFilePicker {
  static Future<List<BrowserPickedFile>> pickMultiple() {
    throw UnsupportedError(
      'BrowserFilePicker is only supported on Flutter Web.',
    );
  }
}
