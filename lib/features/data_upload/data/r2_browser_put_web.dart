import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Direct browser `fetch` PUT using a Blob (more reliable than `package:http`
/// on Flutter Web for R2/S3 presigned URLs).
Future<int> putBytesToPresignedUrl({
  required String uploadUrl,
  required String contentType,
  required Uint8List bytes,
}) async {
  final blobParts = <JSAny>[bytes.toJS].toJS;
  final blob = web.Blob(
    blobParts,
    web.BlobPropertyBag(type: contentType),
  );

  final headers = web.Headers();
  headers.set('Content-Type', contentType);

  final response = await web.window
      .fetch(
        uploadUrl.toJS,
        web.RequestInit(
          method: 'PUT',
          headers: headers,
          body: blob,
          mode: 'cors',
          credentials: 'omit',
          cache: 'no-store',
        ),
      )
      .toDart;

  return response.status;
}
