/**
 * Alternate upload path: admin JWT + server-side R2 PUT (no browser→R2 CORS).
 *
 * R2 client matches the working production function `upload-profile-photo`:
 * forcePathStyle + sanitized account ID + PutObjectCommand.
 */
import { PutObjectCommand, S3Client } from "npm:@aws-sdk/client-s3@3.726.1";
import { createClient } from "npm:@supabase/supabase-js@2.49.1";

const MAX_PROXY_BYTES = 4_500_000;

const ALLOWED_CONTENT_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
  "video/mp4",
  "video/webm",
  "video/quicktime",
]);

const CONTENT_TYPE_EXTENSION: Record<string, string> = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
  "image/gif": ".gif",
  "video/mp4": ".mp4",
  "video/webm": ".webm",
  "video/quicktime": ".mov",
};

function isLocalDevOrigin(origin: string): boolean {
  try {
    const url = new URL(origin);
    if (url.protocol !== "http:") return false;
    return url.hostname === "localhost" || url.hostname === "127.0.0.1";
  } catch {
    return false;
  }
}

function resolveAllowedOrigin(requestOrigin: string | null): string | null {
  if (!requestOrigin) return null;
  if (isLocalDevOrigin(requestOrigin)) return requestOrigin;
  const production = Deno.env.get("PRODUCTION_ADMIN_ORIGIN")?.trim();
  if (
    production &&
    requestOrigin.replace(/\/+$/, "") === production.replace(/\/+$/, "")
  ) {
    return requestOrigin.replace(/\/+$/, "");
  }
  return null;
}

function corsHeaders(requestOrigin: string | null): HeadersInit {
  const allowed = resolveAllowedOrigin(requestOrigin);
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    Vary: "Origin",
  };
  if (allowed) headers["Access-Control-Allow-Origin"] = allowed;
  return headers;
}

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

function createR2Client(accountId: string, accessKeyId: string, secretAccessKey: string) {
  return new S3Client({
    region: "auto",
    endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
    forcePathStyle: true,
    credentials: {
      accessKeyId,
      secretAccessKey,
    },
  });
}

function slugifyCategoryName(raw: string): string {
  const ascii = raw
    .trim()
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-+|-+$/g, "");
  return ascii.length > 0 ? ascii : "category";
}

function formatUtcDateStamp(date: Date = new Date()): string {
  const year = date.getUTCFullYear().toString().padStart(4, "0");
  const month = (date.getUTCMonth() + 1).toString().padStart(2, "0");
  const day = date.getUTCDate().toString().padStart(2, "0");
  return `${year}${month}${day}`;
}

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
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { error: "INVALID_REQUEST", message: "POST only" }, origin);
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return jsonResponse(401, { error: "UNAUTHENTICATED" }, origin);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!supabaseUrl || !supabaseAnonKey) {
      return jsonResponse(500, {
        error: "CONFIGURATION_ERROR",
        message: "Missing SUPABASE_URL or SUPABASE_ANON_KEY",
      }, origin);
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

    const role = (user.app_metadata as Record<string, unknown> | null)?.role;
    if (role !== "admin") {
      return jsonResponse(403, { error: "ADMIN_ACCESS_REQUIRED" }, origin);
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

    const category = typeof body.category === "string" ? body.category.trim() : "";
    const fileName = typeof body.fileName === "string" ? body.fileName.trim() : "";
    const contentType = typeof body.contentType === "string"
      ? body.contentType.trim()
      : "";
    const dataBase64 = typeof body.dataBase64 === "string" ? body.dataBase64 : "";

    if (!category || !fileName || !contentType || !dataBase64) {
      return jsonResponse(400, {
        error: "INVALID_REQUEST",
        message: "category, fileName, contentType, dataBase64 are required",
      }, origin);
    }

    if (!ALLOWED_CONTENT_TYPES.has(contentType)) {
      return jsonResponse(400, {
        error: "UNSUPPORTED_MEDIA_TYPE",
        message: "Unsupported file type.",
      }, origin);
    }

    let bytes: Uint8Array;
    try {
      bytes = decodeBase64(dataBase64);
    } catch {
      return jsonResponse(400, {
        error: "INVALID_REQUEST",
        message: "dataBase64 is invalid",
      }, origin);
    }

    if (bytes.byteLength === 0 || bytes.byteLength > MAX_PROXY_BYTES) {
      return jsonResponse(400, {
        error: "FILE_TOO_LARGE",
        message:
          `Proxy uploads are limited to ${Math.floor(MAX_PROXY_BYTES / (1024 * 1024))} MB.`,
      }, origin);
    }

    const { data: categoryRow, error: categoryError } = await supabase
      .from("categories")
      .select("name")
      .eq("name", category)
      .maybeSingle();

    if (categoryError) {
      return jsonResponse(500, {
        error: "INTERNAL_ERROR",
        message: `Category lookup failed: ${categoryError.message}`,
      }, origin);
    }
    if (!categoryRow?.name) {
      return jsonResponse(400, { error: "CATEGORY_NOT_FOUND" }, origin);
    }

    const accountId = sanitizeR2AccountId(
      Deno.env.get("R2_ACCOUNT_ID")?.trim() ?? "",
    );
    const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID")?.trim() ?? "";
    const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY")?.trim() ?? "";
    const bucketName = Deno.env.get("R2_BUCKET_NAME")?.trim() ?? "";
    const publicBaseUrl = Deno.env.get("R2_PUBLIC_BASE_URL")?.trim() ?? "";

    if (!accountId || !accessKeyId || !secretAccessKey || !bucketName || !publicBaseUrl) {
      return jsonResponse(500, {
        error: "CONFIGURATION_ERROR",
        message: "Missing R2 secrets for proxy-r2-upload",
      }, origin);
    }

    const categorySlug = slugifyCategoryName(String(categoryRow.name));
    const ext = CONTENT_TYPE_EXTENSION[contentType] ?? "";
    const objectKey =
      `${categorySlug}/${formatUtcDateStamp()}_${crypto.randomUUID()}${ext}`;

    try {
      const client = createR2Client(accountId, accessKeyId, secretAccessKey);
      await client.send(
        new PutObjectCommand({
          Bucket: bucketName,
          Key: objectKey,
          Body: bytes,
          ContentType: contentType,
        }),
      );
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      console.error(JSON.stringify({
        event: "proxy-r2-upload.r2_put_failed",
        detail,
        objectKey,
      }));
      return jsonResponse(502, {
        error: "INTERNAL_ERROR",
        message: `R2 PUT failed: ${detail}`,
      }, origin);
    }

    const publicUrl =
      `${publicBaseUrl.replace(/\/+$/, "")}/${objectKey.replace(/^\/+/, "")}`;

    console.log(JSON.stringify({
      event: "proxy-r2-upload.success",
      userId: user.id,
      objectKey,
      bytes: bytes.byteLength,
    }));

    return jsonResponse(200, {
      objectKey,
      publicUrl,
      contentType,
      clientFileName: fileName,
    }, origin);
  } catch (error) {
    const message = error instanceof Error ? error.message : "unknown";
    console.error(JSON.stringify({
      event: "proxy-r2-upload.internal_error",
      message,
    }));
    return jsonResponse(500, {
      error: "INTERNAL_ERROR",
      message: `Proxy upload crashed: ${message}`,
    }, origin);
  }
});
