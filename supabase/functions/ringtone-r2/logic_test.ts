import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  buildRingtoneKey,
  categoryFolder,
  isRingtoneKey,
  MAX_RINGTONE_BYTES,
  randomSuffix,
  titleSlug,
  validateDeleteRequest,
  validatePresignRequest,
} from "./logic.ts";

const validPresign = {
  action: "presign",
  title: "Jai Ganesh Deva",
  category: "Ganesha",
  contentType: "audio/mpeg",
  sizeBytes: 300_000,
};

Deno.test("category folder is lowercase with hyphens", () => {
  assertEquals(categoryFolder("Durga"), "durga");
  assertEquals(categoryFolder("Instrumental"), "instrumental");
  assertEquals(categoryFolder("  Bhojpuri Hits "), "bhojpuri-hits");
});

Deno.test("title slug is ASCII and falls back for Hindi titles", () => {
  assertEquals(titleSlug("Jai Ganesh Deva"), "jai-ganesh-deva");
  assertEquals(titleSlug("  Ram -- Siya_Ram! "), "ram-siya-ram");
  assertEquals(titleSlug("जय गणेश"), "ringtone");
  assertEquals(titleSlug("x".repeat(200)).length, 60);
});

Deno.test("ringtone key layout", () => {
  assertEquals(
    buildRingtoneKey({
      title: "Jai Ganesh Deva",
      category: "Ganesha",
      contentType: "audio/mpeg",
      suffix: "a3f9c1",
    }),
    "ringtones/ganesha/jai-ganesh-deva-a3f9c1.mp3",
  );
  assertEquals(
    buildRingtoneKey({
      title: "Tune",
      category: "Love",
      contentType: "audio/mp4",
      suffix: "000000",
    }),
    "ringtones/love/tune-000000.m4a",
  );
  assertMatch(randomSuffix(), /^[0-9a-f]{6}$/);
});

Deno.test("presign validation", () => {
  assertEquals(validatePresignRequest(validPresign).ok, true);
  assertEquals(
    validatePresignRequest({ ...validPresign, title: "   " }).ok,
    false,
  );
  assertEquals(
    validatePresignRequest({ ...validPresign, category: "All" }).ok,
    false,
  );
  assertEquals(
    validatePresignRequest({ ...validPresign, category: "सभी" }).ok,
    false,
  );

  const badType = validatePresignRequest({
    ...validPresign,
    contentType: "video/mp4",
  });
  assertEquals(badType.ok ? null : badType.error, "UNSUPPORTED_MEDIA_TYPE");

  const tooBig = validatePresignRequest({
    ...validPresign,
    sizeBytes: MAX_RINGTONE_BYTES + 1,
  });
  assertEquals(tooBig.ok ? null : tooBig.error, "FILE_TOO_LARGE");
});

Deno.test("delete only accepts keys under ringtones/", () => {
  // Existing test data uploaded by hand.
  assertEquals(
    isRingtoneKey(
      "ringtones/instrumental/audiocutter-ram-siya-ram-ringtone-viral-shri-ram-ringtone-256k-59546.mp3",
    ),
    true,
  );
  assertEquals(
    isRingtoneKey("ringtones/durga/durga-puja-ringtone-by-lobh-42083.mp3"),
    true,
  );

  assertEquals(isRingtoneKey("bhakti/20261008_abc.mp4"), false);
  assertEquals(isRingtoneKey("ringtones/../bhakti/x.mp3"), false);
  assertEquals(isRingtoneKey("ringtones/durga.mp3"), false);
  assertEquals(isRingtoneKey("ringtones/durga/x.mp4"), false);
  assertEquals(isRingtoneKey("/ringtones/durga/x.mp3"), false);

  assertEquals(validateDeleteRequest({ objectKey: "posts/x.mp3" }).ok, false);
  assertEquals(
    validateDeleteRequest({ objectKey: "ringtones/love/tune-000000.m4a" }).ok,
    true,
  );
});
