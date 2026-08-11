import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'browser_picked_file.dart';

export 'browser_picked_file.dart';

/// Flutter Web multi-file picker using a native `<input type="file">`.
///
/// Appends the input to `document.body` before calling `click()` synchronously
/// inside the user gesture, then waits for change/cancel.
abstract final class BrowserFilePicker {
  static const _accept =
      'image/jpeg,image/png,image/webp,image/gif,video/mp4,video/webm,video/quicktime,.jpg,.jpeg,.png,.webp,.gif,.mp4,.webm,.mov';

  /// Opens the native browser file picker for multiple files.
  ///
  /// Returns an empty list when the user cancels (or selects nothing).
  /// Must be invoked directly from a click/tap handler — do not `await`
  /// anything else before calling this.
  static Future<List<BrowserPickedFile>> pickMultiple() {
    debugPrint('[BrowserFilePicker] pickMultiple() start');

    final completer = Completer<List<BrowserPickedFile>>();

    debugPrint('[BrowserFilePicker] creating <input>');
    final input = web.document.createElement('input') as web.HTMLInputElement;
    debugPrint('[BrowserFilePicker] input created');

    input.type = 'file';
    debugPrint('[BrowserFilePicker] type=file set');

    input.multiple = true;
    debugPrint('[BrowserFilePicker] multiple=true set');

    input.accept = _accept;
    debugPrint('[BrowserFilePicker] accept set');

    // Reset so choosing the same file again still fires `change`.
    input.value = '';

    // Keep it in-document but visually inert. Detached inputs are unreliable.
    input.style
      ..position = 'fixed'
      ..left = '0'
      ..top = '0'
      ..width = '1px'
      ..height = '1px'
      ..opacity = '0'
      ..overflow = 'hidden'
      ..border = '0'
      ..padding = '0'
      ..margin = '0'
      ..zIndex = '-1';

    final body = web.document.body;
    if (body == null) {
      debugPrint('[BrowserFilePicker] ERROR: document.body is null');
      throw StateError('document.body is not available');
    }

    body.append(input);
    debugPrint(
      '[BrowserFilePicker] appended input to document.body '
      '(connected=${input.isConnected})',
    );

    var settled = false;

    void finish(List<BrowserPickedFile> files) {
      if (settled) return;
      settled = true;
      debugPrint(
        '[BrowserFilePicker] finish(${files.length} file(s)); removing input',
      );
      input.remove();
      if (!completer.isCompleted) {
        completer.complete(files);
      }
    }

    void fail(Object error, [StackTrace? stackTrace]) {
      if (settled) return;
      settled = true;
      debugPrint('[BrowserFilePicker] fail: $error');
      if (stackTrace != null) {
        debugPrint('[BrowserFilePicker] fail stack: $stackTrace');
      }
      input.remove();
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }

    debugPrint('[BrowserFilePicker] attaching onChange listener');
    input.onChange.first.then((_) {
      debugPrint('[BrowserFilePicker] onChange fired');
      final fileList = input.files;
      if (fileList == null || fileList.length == 0) {
        debugPrint('[BrowserFilePicker] onChange with zero files → cancel');
        finish(const <BrowserPickedFile>[]);
        return;
      }

      debugPrint(
        '[BrowserFilePicker] selected files retrieval: count=${fileList.length}',
      );
      final selected = <web.File>[
        for (var i = 0; i < fileList.length; i++)
          if (fileList.item(i) != null) fileList.item(i)!,
      ];

      () async {
        try {
          final picked = <BrowserPickedFile>[];
          for (final file in selected) {
            debugPrint(
              '[BrowserFilePicker] reading bytes for '
              'name=${file.name} mime=${file.type} size=${file.size}',
            );
            final bytes = await _readFileBytes(file);
            debugPrint(
              '[BrowserFilePicker] bytes conversion ok '
              '(${bytes.lengthInBytes} bytes)',
            );
            picked.add(
              BrowserPickedFile(
                name: file.name,
                mimeType: file.type,
                bytes: bytes,
              ),
            );
          }
          finish(picked);
        } catch (error, stackTrace) {
          fail(error, stackTrace);
        }
      }();
    });

    // Chromium fires `cancel` when the dialog is dismissed with no selection.
    debugPrint('[BrowserFilePicker] attaching cancel listener');
    input.addEventListener(
      'cancel',
      (web.Event event) {
        debugPrint('[BrowserFilePicker] cancel event fired');
        finish(const <BrowserPickedFile>[]);
      }.toJS,
    );

    // Must stay in the same synchronous turn as the user gesture — no awaits
    // before this point.
    debugPrint(
      '[BrowserFilePicker] calling input.click() '
      '(connected=${input.isConnected})',
    );
    try {
      input.click();
      debugPrint('[BrowserFilePicker] input.click() returned');
    } catch (error, stackTrace) {
      debugPrint('[BrowserFilePicker] input.click() threw: $error');
      fail(error, stackTrace);
    }

    return completer.future;
  }

  static Future<Uint8List> _readFileBytes(web.File file) async {
    final jsArrayBuffer = await file.arrayBuffer().toDart;
    final byteBuffer = jsArrayBuffer.toDart;
    return byteBuffer.asUint8List();
  }
}
