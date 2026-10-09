/** Pure request validation + object-key rules for `ringtone-r2` (no I/O). */

import { slugifyCategoryName } from "../create-r2-upload-urls/slug.ts";

export const RINGTONES_PREFIX = "ringtones/";

/** Sanity cap; ringtones are normally 200–500 KB. */
export const MAX_RINGTONE_BYTES = 10 * 1024 * 1024;

/** Edge Function body limit for the base64 proxy fallback. */
export const MAX_PROXY_BYTES = 4_500_000;

export const PRESIGNED_URL_EXPIRES_IN_SECONDS = 900;

const MAX_TITLE_LENGTH = 120;
const MAX_CATEGORY_LENGTH = 50;
const MAX_SLUG_LENGTH = 60;

export const AUDIO_EXTENSIONS: Record<string, string> = {
  "audio/mpeg": ".mp3",
  "audio/mp4": ".m4a",
  "audio/ogg": ".ogg",
};

/** The app adds "सभी" (All) itself; storing it would duplicate the chip. */
const RESERVED_CATEGORIES = new Set(["all", "सभी"]);

/** Keys this function may delete: `ringtones/<folder>/<file>.<ext>`. */
const RINGTONE_KEY_PATTERN =
  /^ringtones\/[a-z0-9]+(?:-[a-z0-9]+)*\/[a-z0-9]+(?:[-_][a-z0-9]+)*\.(?:mp3|m4a|ogg)$/;

export type RingtoneErrorCode =
  | "INVALID_REQUEST"
  | "UNSUPPORTED_MEDIA_TYPE"
  | "FILE_TOO_LARGE"
  | "INVALID_OBJECT_KEY";

export type Failure = {
  ok: false;
  error: RingtoneErrorCode;
  message: string;
};

export type UploadTarget = {
  ok: true;
  title: string;
  category: string;
  contentType: string;
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function fail(error: RingtoneErrorCode, message: string): Failure {
  return { ok: false, error, message };
}

/** R2 folder for a category: lowercase, spaces → hyphens. */
export function categoryFolder(category: string): string {
  return slugifyCategoryName(category);
}

/** ASCII file-name slug from a title; Hindi-only titles fall back. */
export function titleSlug(title: string): string {
  const slug = title
    .trim()
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .slice(0, MAX_SLUG_LENGTH)
    .replace(/^-+|-+$/g, "");
  return slug.length > 0 ? slug : "ringtone";
}

/** `ringtones/<category-folder>/<title-slug>-<suffix><ext>` */
export function buildRingtoneKey(params: {
  title: string;
  category: string;
  contentType: string;
  suffix: string;
}): string {
  const ext = AUDIO_EXTENSIONS[params.contentType] ?? "";
  return `${RINGTONES_PREFIX}${categoryFolder(params.category)}/` +
    `${titleSlug(params.title)}-${params.suffix}${ext}`;
}

/** Short unique suffix so two uploads with one title never collide. */
export function randomSuffix(): string {
  return crypto.randomUUID().replace(/-/g, "").slice(0, 6);
}

export function isRingtoneKey(key: string): boolean {
  return RINGTONE_KEY_PATTERN.test(key);
}

/** Shared title/category/contentType checks for `presign` and `proxy`. */
export function validateUploadTarget(
  body: Record<string, unknown>,
): UploadTarget | Failure {
  const title = typeof body.title === "string" ? body.title.trim() : "";
  if (!title) return fail("INVALID_REQUEST", "title is required");
  if (title.length > MAX_TITLE_LENGTH) {
    return fail("INVALID_REQUEST", "title is too long");
  }

  const category = typeof body.category === "string"
    ? body.category.trim()
    : "";
  if (!category) return fail("INVALID_REQUEST", "category is required");
  if (category.length > MAX_CATEGORY_LENGTH) {
    return fail("INVALID_REQUEST", "category is too long");
  }
  if (RESERVED_CATEGORIES.has(category.toLowerCase())) {
    return fail("INVALID_REQUEST", `"${category}" cannot be a category`);
  }

  const contentType = typeof body.contentType === "string"
    ? body.contentType.trim()
    : "";
  if (!(contentType in AUDIO_EXTENSIONS)) {
    return fail(
      "UNSUPPORTED_MEDIA_TYPE",
      "Only MP3, M4A and OGG ringtones are supported.",
    );
  }

  return { ok: true, title, category, contentType };
}

export function validatePresignRequest(
  body: unknown,
): (UploadTarget & { sizeBytes: number }) | Failure {
  if (!isRecord(body)) {
    return fail("INVALID_REQUEST", "Request body must be a JSON object");
  }
  const target = validateUploadTarget(body);
  if (!target.ok) return target;

  const sizeBytes = body.sizeBytes;
  if (
    typeof sizeBytes !== "number" || !Number.isFinite(sizeBytes) ||
    sizeBytes <= 0
  ) {
    return fail("INVALID_REQUEST", "sizeBytes must be a positive number");
  }
  if (sizeBytes > MAX_RINGTONE_BYTES) {
    return fail("FILE_TOO_LARGE", "Ringtone files must be 10 MB or smaller.");
  }
  return { ...target, sizeBytes };
}

export function validateDeleteRequest(
  body: unknown,
): { ok: true; objectKey: string } | Failure {
  if (!isRecord(body)) {
    return fail("INVALID_REQUEST", "Request body must be a JSON object");
  }
  const objectKey = typeof body.objectKey === "string"
    ? body.objectKey.trim()
    : "";
  if (!isRingtoneKey(objectKey)) {
    return fail(
      "INVALID_OBJECT_KEY",
      "Only files under ringtones/ can be deleted.",
    );
  }
  return { ok: true, objectKey };
}
