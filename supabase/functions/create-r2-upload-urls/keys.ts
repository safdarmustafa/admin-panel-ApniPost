import {
  CONTENT_TYPE_EXTENSION,
  type AllowedContentType,
} from "./constants.ts";

/** Format UTC date as YYYYMMDD for object-key prefixes. */
export function formatUtcDateStamp(date: Date = new Date()): string {
  const year = date.getUTCFullYear().toString().padStart(4, "0");
  const month = (date.getUTCMonth() + 1).toString().padStart(2, "0");
  const day = date.getUTCDate().toString().padStart(2, "0");
  return `${year}${month}${day}`;
}

export function extensionForContentType(
  contentType: AllowedContentType,
): string {
  return CONTENT_TYPE_EXTENSION[contentType];
}

/**
 * Server-controlled object key:
 *   {categorySlug}/{YYYYMMDD}_{uuid}{ext}
 */
export function buildObjectKey(params: {
  categorySlug: string;
  contentType: AllowedContentType;
  uuid: string;
  now?: Date;
}): string {
  const stamp = formatUtcDateStamp(params.now ?? new Date());
  const ext = extensionForContentType(params.contentType);
  return `${params.categorySlug}/${stamp}_${params.uuid}${ext}`;
}

export function buildPublicUrl(
  publicBaseUrl: string,
  objectKey: string,
): string {
  const base = publicBaseUrl.replace(/\/+$/, "");
  const key = objectKey.replace(/^\/+/, "");
  return `${base}/${key}`;
}
