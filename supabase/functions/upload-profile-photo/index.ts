/**
 * upload-profile-photo
 *
 * Accepts raw JPEG bytes + phone, uploads to R2 at profile/{userId}.jpg,
 * returns the public media URL. Does NOT update the users table.
 */

import "@supabase/functions-js/edge-runtime.d.ts";
import { PutObjectCommand, S3Client } from "npm:@aws-sdk/client-s3";
import { createClient } from "npm:@supabase/supabase-js@2";

import { handleCorsPreflight } from "../_shared/cors.ts";
import { requireEnv } from "../_shared/env.ts";
import { ERROR_CODES } from "../_shared/errors.ts";
import { errorResponse, successResponse } from "../_shared/response.ts";
import { validateIndianPhone } from "../_shared/validation.ts";

const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

function createServiceClient() {
  return createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    {
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
}

function createR2Client() {
  const rawAccountId = requireEnv("R2_ACCOUNT_ID");
  // Strip any accidental URL parts — keep only the 32-char hex account ID
  const accountId = rawAccountId
    .replace(/https?:\/\//g, "")           // remove http:// or https://
    .replace(/\.r2\.cloudflarestorage\.com.*$/g, "")  // remove domain + anything after
    .replace(/\//g, "")                    // remove any slashes
    .trim();
  return new S3Client({
    region: "auto",
    endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
    forcePathStyle: true,
    credentials: {
      accessKeyId: requireEnv("R2_ACCESS_KEY_ID"),
      secretAccessKey: requireEnv("R2_SECRET_ACCESS_KEY"),
    },
  });
}

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return errorResponse(ERROR_CODES.METHOD_NOT_ALLOWED);
  }

  const phoneHeader = req.headers.get("x-phone");
  const phoneResult = validateIndianPhone(phoneHeader);
  if (!phoneResult.valid || !phoneResult.normalized) {
    return errorResponse(ERROR_CODES.PHONE_INVALID);
  }
  const phone = phoneResult.normalized;

  const contentType = (req.headers.get("content-type") ?? "").toLowerCase();
  if (!contentType.includes("image/jpeg") && !contentType.includes("image/jpg")) {
    return errorResponse(
      ERROR_CODES.BAD_REQUEST,
      "Content-Type must be image/jpeg",
    );
  }

  let imageBytes: Uint8Array;
  try {
    imageBytes = new Uint8Array(await req.arrayBuffer());
  } catch {
    return errorResponse(ERROR_CODES.BAD_REQUEST, "Invalid image body");
  }

  if (imageBytes.byteLength === 0) {
    return errorResponse(ERROR_CODES.BAD_REQUEST, "Invalid image: empty payload");
  }
  if (imageBytes.byteLength > MAX_IMAGE_BYTES) {
    return errorResponse(
      ERROR_CODES.BAD_REQUEST,
      "Invalid image: exceeds maximum size of 5MB",
    );
  }
  if (!(imageBytes[0] === 0xff && imageBytes[1] === 0xd8 && imageBytes[2] === 0xff)) {
    return errorResponse(ERROR_CODES.BAD_REQUEST, "Invalid image: not a valid JPEG");
  }

  try {
    const supabase = createServiceClient();
    const { data: existing, error: lookupError } = await supabase
      .from("users")
      .select("id")
      .eq("phone", phone)
      .maybeSingle();

    if (lookupError) {
      console.error("upload-profile-photo lookup failed", lookupError.message);
      return errorResponse(ERROR_CODES.INTERNAL_SERVER_ERROR);
    }
    if (!existing) {
      return errorResponse(
        ERROR_CODES.BAD_REQUEST,
        "No user found for this phone number",
      );
    }

    const bucketName = requireEnv("R2_BUCKET_NAME");
    const publicBaseUrl = requireEnv("R2_PUBLIC_BASE_URL").replace(/\/+$/, "");
    const objectKey = `profile/${existing.id}.jpg`;

    try {
      const client = createR2Client();
      await client.send(
        new PutObjectCommand({
          Bucket: bucketName,
          Key: objectKey,
          Body: imageBytes,
          ContentType: "image/jpeg",
        }),
      );
    } catch (error) {
      console.error("upload-profile-photo R2 PutObject failed", error);
      return errorResponse(
        ERROR_CODES.BAD_REQUEST,
        "Image upload failed. Please try again",
      );
    }

    const publicUrl = `${publicBaseUrl}/${objectKey}`;
    return successResponse("Profile photo uploaded successfully.", {
      publicUrl,
      profile_photo: publicUrl,
    });
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    console.error("upload-profile-photo unexpected error", detail);
    return errorResponse(ERROR_CODES.INTERNAL_SERVER_ERROR);
  }
});
