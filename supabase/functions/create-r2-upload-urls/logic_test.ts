import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { authorizeAdminUser } from "./auth.ts";
import {
  MAX_FILES_PER_REQUEST,
  MAX_GIF_BYTES,
  MAX_IMAGE_BYTES,
  MAX_VIDEO_BYTES,
} from "./constants.ts";
import { isLocalDevOrigin, resolveAllowedOrigin } from "./cors.ts";
import {
  buildObjectKey,
  buildPublicUrl,
  extensionForContentType,
  formatUtcDateStamp,
} from "./keys.ts";
import { slugifyCategoryName } from "./slug.ts";
import {
  categoryRowExists,
  isAdminFromAppMetadata,
  validateCreateUploadUrlsRequest,
} from "./validate.ts";

Deno.test("missing category row maps to not found", () => {
  assertEquals(categoryRowExists(null), false);
  assertEquals(categoryRowExists({ name: "" }), false);
  assertEquals(categoryRowExists({ name: "Islamic" }), true);
});

Deno.test("admin authorization succeeds for app_metadata.role=admin", () => {
  const result = authorizeAdminUser({
    id: "user-1",
    app_metadata: { role: "admin" },
  });
  assertEquals(result.ok, true);
});

Deno.test("non-admin rejection for missing/other roles", () => {
  const missing = authorizeAdminUser(null);
  assertEquals(missing.ok, false);
  if (!missing.ok) assertEquals(missing.error, "UNAUTHENTICATED");

  const noRole = authorizeAdminUser({ id: "u1", app_metadata: {} });
  assertEquals(noRole.ok, false);
  if (!noRole.ok) assertEquals(noRole.error, "ADMIN_ACCESS_REQUIRED");

  const userRole = authorizeAdminUser({
    id: "u1",
    app_metadata: { role: "user" },
  });
  assertEquals(userRole.ok, false);
  if (!userRole.ok) assertEquals(userRole.error, "ADMIN_ACCESS_REQUIRED");

  assertEquals(isAdminFromAppMetadata({ role: "Admin" }), false);
});

Deno.test("valid image / gif / video request payloads pass validation", () => {
  const result = validateCreateUploadUrlsRequest({
    category: "Independence Day",
    files: [
      { fileName: "001.jpg", contentType: "image/jpeg", sizeBytes: 1024 },
      { fileName: "anim.gif", contentType: "image/gif", sizeBytes: 2048 },
      { fileName: "clip.mp4", contentType: "video/mp4", sizeBytes: 4096 },
    ],
  });
  assertEquals(result.ok, true);
});

Deno.test("unsupported MIME type is rejected", () => {
  const result = validateCreateUploadUrlsRequest({
    category: "Islamic",
    files: [
      { fileName: "x.bmp", contentType: "image/bmp", sizeBytes: 100 },
    ],
  });
  assertEquals(result.ok, false);
  if (!result.ok) {
    assertEquals(result.error, "UNSUPPORTED_MEDIA_TYPE");
    assertEquals(result.fileName, "x.bmp");
  }
});

Deno.test("image / gif / video size limits", () => {
  const image = validateCreateUploadUrlsRequest({
    category: "Islamic",
    files: [{
      fileName: "big.jpg",
      contentType: "image/jpeg",
      sizeBytes: MAX_IMAGE_BYTES + 1,
    }],
  });
  assertEquals(image.ok, false);
  if (!image.ok) assertEquals(image.error, "FILE_TOO_LARGE");

  const gif = validateCreateUploadUrlsRequest({
    category: "Islamic",
    files: [{
      fileName: "big.gif",
      contentType: "image/gif",
      sizeBytes: MAX_GIF_BYTES + 1,
    }],
  });
  assertEquals(gif.ok, false);
  if (!gif.ok) assertEquals(gif.error, "FILE_TOO_LARGE");

  const video = validateCreateUploadUrlsRequest({
    category: "Islamic",
    files: [{
      fileName: "big.mp4",
      contentType: "video/mp4",
      sizeBytes: MAX_VIDEO_BYTES + 1,
    }],
  });
  assertEquals(video.ok, false);
  if (!video.ok) assertEquals(video.error, "FILE_TOO_LARGE");
});

Deno.test(">100 files returns TOO_MANY_FILES", () => {
  const files = Array.from({ length: MAX_FILES_PER_REQUEST + 1 }, (_, i) => ({
    fileName: `${i}.jpg`,
    contentType: "image/jpeg",
    sizeBytes: 10,
  }));
  const result = validateCreateUploadUrlsRequest({
    category: "Islamic",
    files,
  });
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.error, "TOO_MANY_FILES");
});

Deno.test("category slug generation", () => {
  assertEquals(slugifyCategoryName("Independence Day"), "independence-day");
  assertEquals(slugifyCategoryName("Good Night"), "good-night");
  assertEquals(slugifyCategoryName("Updesh"), "updesh");
  assertEquals(slugifyCategoryName("  Hello---World  "), "hello-world");
});

Deno.test("safe extension mapping", () => {
  assertEquals(extensionForContentType("image/jpeg"), ".jpg");
  assertEquals(extensionForContentType("image/png"), ".png");
  assertEquals(extensionForContentType("image/webp"), ".webp");
  assertEquals(extensionForContentType("image/gif"), ".gif");
  assertEquals(extensionForContentType("video/mp4"), ".mp4");
  assertEquals(extensionForContentType("video/webm"), ".webm");
  assertEquals(extensionForContentType("video/quicktime"), ".mov");
});

Deno.test("object key generation", () => {
  const now = new Date(Date.UTC(2026, 7, 11));
  const key = buildObjectKey({
    categorySlug: "independence-day",
    contentType: "image/jpeg",
    uuid: "550e8400-e29b-41d4-a716-446655440000",
    now,
  });
  assertEquals(
    key,
    "independence-day/20260811_550e8400-e29b-41d4-a716-446655440000.jpg",
  );
  assertEquals(formatUtcDateStamp(now), "20260811");
  assertEquals(
    buildPublicUrl("https://media.apnipost.com/", key),
    `https://media.apnipost.com/${key}`,
  );
  assertMatch(key, /^independence-day\/20260811_[0-9a-f-]+\.jpg$/);
});

Deno.test("CORS allows localhost and configured production origin", () => {
  assertEquals(isLocalDevOrigin("http://localhost:50123"), true);
  assertEquals(isLocalDevOrigin("http://127.0.0.1:3000"), true);
  assertEquals(isLocalDevOrigin("https://evil.example"), false);

  Deno.env.set("PRODUCTION_ADMIN_ORIGIN", "https://admin.apnipost.com");
  assertEquals(
    resolveAllowedOrigin("https://admin.apnipost.com"),
    "https://admin.apnipost.com",
  );
  assertEquals(resolveAllowedOrigin("https://evil.example"), null);
  Deno.env.delete("PRODUCTION_ADMIN_ORIGIN");
});
