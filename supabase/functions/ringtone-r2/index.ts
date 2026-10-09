/**
 * R2 storage for ringtones (admin only). Database rows are written by the
 * admin panel directly under RLS; this function only touches R2. Uploads
 * must name a category that exists in `ringtone_categories`.
 *
 * POST { action: "presign", title, category, contentType, sizeBytes }
 *   → { objectKey, uploadUrl, publicUrl, contentType }
 * POST { action: "proxy", title, category, contentType, dataBase64 }
 *   → { objectKey, publicUrl, contentType }   (fallback when browser PUT fails)
 * POST { action: "delete", objectKey }
 *   → { deleted: true }                        (keys under ringtones/ only)
 *
 * R2 client matches `create-r2-upload-urls` / `upload-profile-photo`.
 */
import {
  DeleteObjectCommand,
  PutObjectCommand,
  S3Client,
} from "npm:@aws-sdk/client-s3@3.726.1";
import { getSignedUrl } from "npm:@aws-sdk/s3-request-presigner@3.726.1";
import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.49.1";

import { authorizeAdminUser } from "../create-r2-upload-urls/auth.ts";
import { corsHeaders } from "../create-r2-upload-urls/cors.ts";
import { buildPublicUrl } from "../create-r2-upload-urls/keys.ts";
import {
  buildRingtoneKey,
  MAX_PROXY_BYTES,
  PRESIGNED_URL_EXPIRES_IN_SECONDS,
  randomSuffix,
  validateDeleteRequest,
  validatePresignRequest,
  validateUploadTarget,
} from "./logic.ts";

function jsonResponse(
  status: number,
  body: unknown,
  origin: string | null,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(origin),
      "Content-Type": "application/json",
    },
  });
}

function sanitizeR2AccountId(raw: string): string {
  return raw
    .replace(/https?:\/\//g, "")
    .replace(/\.r2\.cloudflarestorage\.com.*$/g, "")
    .replace(/\//g, "")
    .trim();
}

function readR2Config() {
  const accountId = sanitizeR2AccountId(
    Deno.env.get("R2_ACCOUNT_ID")?.trim() ?? "",
  );
  const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID")?.trim() ?? "";
  const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY")?.trim() ?? "";
  const bucketName = Deno.env.get("R2_BUCKET_NAME")?.trim() ?? "";
  const publicBaseUrl = Deno.env.get("R2_PUBLIC_BASE_URL")?.trim() ?? "";

  if (
    !accountId || !accessKeyId || !secretAccessKey || !bucketName ||
    !publicBaseUrl
  ) {
    return null;
  }

  return {
    bucketName,
    publicBaseUrl,
    client: new S3Client({
      region: "auto",
      endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
      forcePathStyle: true,
      credentials: { accessKeyId, secretAccessKey },
    }),
  };
}

/** Exact-name lookup in `ringtone_categories` (readable by any role). */
async function categoryExists(
  // deno-lint-ignore no-explicit-any
  supabase: SupabaseClient<any, "public", any>,
  name: string,
): Promise<boolean> {
  const { data, error } = await supabase
    .from("ringtone_categories")
    .select("name")
    .eq("name", name)
    .maybeSingle();
  if (error) throw new Error(`Category lookup failed: ${error.message}`);
  return data != null;
}

const CATEGORY_NOT_FOUND = {
  error: "CATEGORY_NOT_FOUND",
  message:
    "This category does not exist. Create it on the Ringtone Categories page.",
};

function decodeBase64(dataBase64: string): Uint8Array {
  const cleaned = dataBase64.includes(",")
    ? dataBase64.slice(dataBase64.indexOf(",") + 1)
    : dataBase64;
  const binary = atob(cleaned);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin");

  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders(origin) });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, {
      error: "INVALID_REQUEST",
      message: "Only POST is supported",
    }, origin);
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse(401, { error: "UNAUTHENTICATED" }, origin);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!supabaseUrl || !supabaseAnonKey) {
      console.error("Missing SUPABASE_URL or SUPABASE_ANON_KEY");
      return jsonResponse(500, { error: "CONFIGURATION_ERROR" }, origin);
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();
    if (userError || !user) {
      return jsonResponse(401, { error: "UNAUTHENTICATED" }, origin);
    }

    const authz = authorizeAdminUser({
      id: user.id,
      app_metadata: user.app_metadata as Record<string, unknown>,
    });
    if (!authz.ok) {
      console.log(JSON.stringify({
        event: "ringtone-r2.denied",
        userId: user.id,
        code: authz.error,
      }));
      return jsonResponse(authz.status, { error: authz.error }, origin);
    }

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return jsonResponse(400, {
        error: "INVALID_REQUEST",
        message: "Invalid JSON body",
      }, origin);
    }

    const r2 = readR2Config();
    if (!r2) {
      console.error(JSON.stringify({ event: "ringtone-r2.config_error" }));
      return jsonResponse(500, {
        error: "CONFIGURATION_ERROR",
        message: "Missing R2 secrets for ringtone-r2",
      }, origin);
    }

    switch (body?.action) {
      case "presign": {
        const validated = validatePresignRequest(body);
        if (!validated.ok) {
          return jsonResponse(400, validated, origin);
        }
        if (!(await categoryExists(supabase, validated.category))) {
          return jsonResponse(400, CATEGORY_NOT_FOUND, origin);
        }

        const objectKey = buildRingtoneKey({
          ...validated,
          suffix: randomSuffix(),
        });
        // Do NOT sign content-type — browser fetch mismatches become R2 403s.
        const uploadUrl = await getSignedUrl(
          r2.client,
          new PutObjectCommand({
            Bucket: r2.bucketName,
            Key: objectKey,
            ContentType: validated.contentType,
          }),
          { expiresIn: PRESIGNED_URL_EXPIRES_IN_SECONDS },
        );

        console.log(JSON.stringify({
          event: "ringtone-r2.presign",
          userId: authz.userId,
          objectKey,
        }));
        return jsonResponse(200, {
          objectKey,
          uploadUrl,
          publicUrl: buildPublicUrl(r2.publicBaseUrl, objectKey),
          contentType: validated.contentType,
        }, origin);
      }

      case "proxy": {
        const validated = validateUploadTarget(body);
        if (!validated.ok) {
          return jsonResponse(400, validated, origin);
        }
        if (!(await categoryExists(supabase, validated.category))) {
          return jsonResponse(400, CATEGORY_NOT_FOUND, origin);
        }

        let bytes: Uint8Array;
        try {
          bytes = decodeBase64(
            typeof body.dataBase64 === "string" ? body.dataBase64 : "",
          );
        } catch {
          return jsonResponse(400, {
            error: "INVALID_REQUEST",
            message: "dataBase64 is invalid",
          }, origin);
        }
        if (bytes.byteLength === 0 || bytes.byteLength > MAX_PROXY_BYTES) {
          return jsonResponse(400, {
            error: "FILE_TOO_LARGE",
            message: "Proxy uploads are limited to 4 MB.",
          }, origin);
        }

        const objectKey = buildRingtoneKey({
          ...validated,
          suffix: randomSuffix(),
        });
        await r2.client.send(
          new PutObjectCommand({
            Bucket: r2.bucketName,
            Key: objectKey,
            Body: bytes,
            ContentType: validated.contentType,
          }),
        );

        console.log(JSON.stringify({
          event: "ringtone-r2.proxy",
          userId: authz.userId,
          objectKey,
          bytes: bytes.byteLength,
        }));
        return jsonResponse(200, {
          objectKey,
          publicUrl: buildPublicUrl(r2.publicBaseUrl, objectKey),
          contentType: validated.contentType,
        }, origin);
      }

      case "delete": {
        const validated = validateDeleteRequest(body);
        if (!validated.ok) {
          return jsonResponse(400, validated, origin);
        }

        await r2.client.send(
          new DeleteObjectCommand({
            Bucket: r2.bucketName,
            Key: validated.objectKey,
          }),
        );

        console.log(JSON.stringify({
          event: "ringtone-r2.delete",
          userId: authz.userId,
          objectKey: validated.objectKey,
        }));
        return jsonResponse(200, { deleted: true }, origin);
      }

      default:
        return jsonResponse(400, {
          error: "INVALID_REQUEST",
          message: 'action must be "presign", "proxy" or "delete"',
        }, origin);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "unknown";
    console.error(JSON.stringify({
      event: "ringtone-r2.internal_error",
      message,
    }));
    return jsonResponse(500, {
      error: "INTERNAL_ERROR",
      message: `Ringtone storage request failed: ${message}`,
    }, origin);
  }
});
