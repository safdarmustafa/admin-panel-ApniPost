/** Centralized upload limits and MIME policies for create-r2-upload-urls. */

export const MAX_FILES_PER_REQUEST = 100;

/** Presigned PUT URL lifetime (seconds). */
export const PRESIGNED_URL_EXPIRES_IN_SECONDS = 900;

export const MAX_IMAGE_BYTES = 20 * 1024 * 1024; // 20 MB
export const MAX_GIF_BYTES = 30 * 1024 * 1024; // 30 MB
export const MAX_VIDEO_BYTES = 200 * 1024 * 1024; // 200 MB

export const ALLOWED_CONTENT_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
  "video/mp4",
  "video/webm",
  "video/quicktime",
] as const;

export type AllowedContentType = (typeof ALLOWED_CONTENT_TYPES)[number];

export const CONTENT_TYPE_EXTENSION: Record<AllowedContentType, string> = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
  "image/gif": ".gif",
  "video/mp4": ".mp4",
  "video/webm": ".webm",
  "video/quicktime": ".mov",
};

export function isAllowedContentType(
  value: string,
): value is AllowedContentType {
  return (ALLOWED_CONTENT_TYPES as readonly string[]).includes(value);
}

export function maxBytesForContentType(contentType: AllowedContentType): number {
  if (contentType === "image/gif") return MAX_GIF_BYTES;
  if (contentType.startsWith("video/")) return MAX_VIDEO_BYTES;
  return MAX_IMAGE_BYTES;
}
