import 'dart:typed_data';

import 'package:apnipost_admin/features/data_upload/domain/upload_media_mapping.dart';
import 'package:apnipost_admin/features/data_upload/domain/upload_models.dart';

abstract class UploadRepository {
  /// Creates short-lived R2 PUT URLs via `create-r2-upload-urls`.
  Future<List<PresignResponseItem>> createUploadUrls({
    required String categoryName,
    required List<PresignRequestFile> files,
  });

  /// Direct browser PUT to Cloudflare R2 using the presigned URL.
  Future<void> uploadToR2({
    required String uploadUrl,
    required String contentType,
    required Uint8List bytes,
    String? objectKey,
  });

  /// Server-side R2 upload fallback (no browser→R2 CORS). Size-limited.
  Future<ProxyUploadResult> uploadViaProxy({
    required String categoryName,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  });

  /// Inserts a `public.posts` row after a successful R2 upload.
  Future<void> insertPost({
    required String categoryName,
    required String mediaUrl,
    required PostMediaType mediaType,
  });

  /// Confirms the category still exists by exact name.
  Future<bool> categoryExists(String categoryName);
}
