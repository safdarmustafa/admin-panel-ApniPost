export 'web_media_stub.dart'
    if (dart.library.html) 'web_media_web.dart'
    if (dart.library.js_interop) 'web_media_web.dart';
