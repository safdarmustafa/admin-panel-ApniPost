import 'package:apnipost_admin/features/data_upload/domain/upload_limits.dart';

/// Database `posts.media_type` values.
enum PostMediaType {
  image,
  gif,
  video;

  String get dbValue => name;
}

abstract final class UploadMediaMapping {
  static bool isAllowedContentType(String contentType) {
    return UploadLimits.allowedContentTypes.contains(contentType);
  }

  static int maxBytesForContentType(String contentType) {
    if (contentType == 'image/gif') return UploadLimits.maxGifBytes;
    if (contentType.startsWith('video/')) return UploadLimits.maxVideoBytes;
    return UploadLimits.maxImageBytes;
  }

  /// Maps MIME → `posts.media_type` (`image` | `gif` | `video`).
  static PostMediaType? mediaTypeForContentType(String contentType) {
    switch (contentType) {
      case 'image/jpeg':
      case 'image/png':
      case 'image/webp':
        return PostMediaType.image;
      case 'image/gif':
        return PostMediaType.gif;
      case 'video/mp4':
      case 'video/webm':
      case 'video/quicktime':
        return PostMediaType.video;
      default:
        return null;
    }
  }

  static String? validateContentType(String? contentType) {
    final value = (contentType ?? '').trim().toLowerCase();
    if (value.isEmpty) {
      return 'Unsupported file type.';
    }
    if (!isAllowedContentType(value)) {
      return 'Unsupported file type.';
    }
    return null;
  }

  static String? validateSize({
    required String contentType,
    required int sizeBytes,
  }) {
    if (sizeBytes < 0) {
      return 'Invalid file size.';
    }
    final max = maxBytesForContentType(contentType);
    if (sizeBytes > max) {
      final mb = (max / (1024 * 1024)).round();
      return 'File exceeds the $mb MB limit.';
    }
    return null;
  }

  static String? validateBatchCount(int count) {
    if (count <= 0) {
      return 'Select at least one file.';
    }
    if (count > UploadLimits.maxFilesPerBatch) {
      return 'A maximum of ${UploadLimits.maxFilesPerBatch} files can be uploaded at once.';
    }
    return null;
  }

  static String? validateCategoryName(String? categoryName) {
    if (categoryName == null || categoryName.trim().isEmpty) {
      return 'Select a category before uploading.';
    }
    return null;
  }
}
