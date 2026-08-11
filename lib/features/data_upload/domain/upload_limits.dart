/// Client-side upload limits — keep aligned with
/// `supabase/functions/create-r2-upload-urls/constants.ts`.
abstract final class UploadLimits {
  static const int maxFilesPerBatch = 100;

  static const int maxImageBytes = 20 * 1024 * 1024;
  static const int maxGifBytes = 30 * 1024 * 1024;
  static const int maxVideoBytes = 200 * 1024 * 1024;

  /// Concurrent R2 PUT uploads.
  static const int maxConcurrentUploads = 3;

  /// Max size for server-side proxy upload fallback (Edge Function body limit).
  static const int maxProxyUploadBytes = 4 * 1024 * 1024;

  static const Set<String> allowedContentTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'video/mp4',
    'video/webm',
    'video/quicktime',
  };
}
