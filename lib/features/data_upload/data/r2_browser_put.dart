export 'r2_browser_put_stub.dart'
    if (dart.library.html) 'r2_browser_put_web.dart'
    if (dart.library.js_interop) 'r2_browser_put_web.dart';
