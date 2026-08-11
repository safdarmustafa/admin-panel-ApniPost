export 'browser_file_picker_stub.dart'
    if (dart.library.html) 'browser_file_picker_web.dart'
    if (dart.library.js_interop) 'browser_file_picker_web.dart';
