import { S3Client, PutObjectCommand } from "npm:@aws-sdk/client-s3@3.726.1";
import { getSignedUrl } from "npm:@aws-sdk/s3-request-presigner@3.726.1";
import { createClient } from "npm:@supabase/supabase-js@2.49.1";

import { authorizeAdminUser } from "./auth.ts";
import {
  PRESIGNED_URL_EXPIRES_IN_SECONDS,
} from "./constants.ts";
import { corsHeaders } from "./cors.ts";
import { buildObjectKey, buildPublicUrl } from "./keys.ts";
import { slugifyCategoryName } from "./slug.ts";
import type { ErrorCode, ErrorResponse, UploadUrlItem } from "./types.ts";
import { validateCreateUploadUrlsRequest, categoryRowExists } from "./validate.ts";

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

function errorResponse(
  status: number,
  error: ErrorCode,
  origin: string | null,
  extras?: Omit<ErrorResponse, "error">,
): Response {
  return jsonResponse(status, { error, ...extras }, origin);
}

function sanitizeR2AccountId(raw: string): string {
  // Match production upload-profile-photo: strip accidental URL wrappers.
  return raw
    .replace(/https?:\/\//g, "")
    .replace(/\.r2\.cloudflarestorage\.com.*$/g, "")
    .replace(/\//g, "")
    .trim();
}

function readR2Config():
  | {
    ok: true;
    accountId: string;
    accessKeyId: string;
    secretAccessKey: string;
    bucketName: string;
    publicBaseUrl: string;
  }
  | { ok: false; message: string } {
  const accountId = sanitizeR2AccountId(
    Deno.env.get("R2_ACCOUNT_ID")?.trim() ?? "",
  );
  const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID")?.trim() ?? "";
  const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY")?.trim() ?? "";
  const bucketName = Deno.env.get("R2_BUCKET_NAME")?.trim() ?? "";
  const publicBaseUrl = Deno.env.get("R2_PUBLIC_BASE_URL")?.trim() ?? "";

  if (
    !accountId ||
    !accessKeyId ||
    !secretAccessKey ||
    !bucketName ||
    !publicBaseUrl
  ) {
    return {
      ok: false,
      message: "Missing required R2 environment configuration",
    };
  }

  return {
    ok: true,
    accountId,
    accessKeyId,
    secretAccessKey,
    bucketName,
    publicBaseUrl,
  };
}

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin");

  if (req.method === "OPTIONS") {
    return new Response("ok", {
      status: 200,
      headers: corsHeaders(origin),
    });
  }

  if (req.method !== "POST") {
    return errorResponse(405, "INVALID_REQUEST", origin, {
      message: "Only POST is supported",
    });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return errorResponse(401, "UNAUTHENTICATED", origin);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!supabaseUrl || !supabaseAnonKey) {
      console.error("Missing SUPABASE_URL or SUPABASE_ANON_KEY");
      return errorResponse(500, "CONFIGURATION_ERROR", origin);
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: { Authorization: authHeader },
      },
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      return errorResponse(401, "UNAUTHENTICATED", origin);
    }

    const authz = authorizeAdminUser({
      id: user.id,
      app_metadata: user.app_metadata as Record<string, unknown>,
    });
    if (!authz.ok) {
      console.log(
        JSON.stringify({
          event: "create-r2-upload-urls.denied",
          userId: user.id,
          code: authz.error,
        }),
      );
      return errorResponse(authz.status, authz.error, origin);
    }

    let body: unknown;
    try {
      body = await req.json();
    } catch {
      return errorResponse(400, "INVALID_REQUEST", origin, {
        message: "Invalid JSON body",
      });
    }

    const validated = validateCreateUploadUrlsRequest(body);
    if (!validated.ok) {
      console.log(
        JSON.stringify({
          event: "create-r2-upload-urls.validation_failed",
          userId: authz.userId,
          code: validated.error,
        }),
      );
      return errorResponse(validated.status, validated.error, origin, {
        message: validated.message,
        fileName: validated.fileName,
      });
    }

    const { data: categoryRow, error: categoryError } = await supabase
      .from("categories")
      .select("name")
      .eq("name", validated.category)
      .maybeSingle();

    if (categoryError) {
      console.error(
        JSON.stringify({
          event: "create-r2-upload-urls.category_lookup_failed",
          userId: authz.userId,
        }),
      );
      return errorResponse(500, "INTERNAL_ERROR", origin);
    }

    if (!categoryRow || !categoryRowExists(categoryRow)) {
      console.log(
        JSON.stringify({
          event: "create-r2-upload-urls.category_not_found",
          userId: authz.userId,
          category: validated.category,
          fileCount: validated.files.length,
        }),
      );
      return errorResponse(400, "CATEGORY_NOT_FOUND", origin);
    }

    const verifiedCategoryName = categoryRow.name;
    const categorySlug = slugifyCategoryName(verifiedCategoryName);

    const r2 = readR2Config();
    if (!r2.ok) {
      console.error(
        JSON.stringify({
          event: "create-r2-upload-urls.config_error",
          userId: authz.userId,
        }),
      );
      return errorResponse(500, "CONFIGURATION_ERROR", origin);
    }

    // Match production upload-profile-photo R2 client.
    const s3 = new S3Client({
      region: "auto",
      endpoint: `https://${r2.accountId}.r2.cloudflarestorage.com`,
      forcePathStyle: true,
      credentials: {
        accessKeyId: r2.accessKeyId,
        secretAccessKey: r2.secretAccessKey,
      },
    });

    const now = new Date();
    const items: UploadUrlItem[] = [];

    for (const file of validated.files) {
      const objectKey = buildObjectKey({
        categorySlug,
        contentType: file.contentType,
        uuid: crypto.randomUUID(),
        now,
      });

      const command = new PutObjectCommand({
        Bucket: r2.bucketName,
        Key: objectKey,
        ContentType: file.contentType,
      });

      // Do NOT use signableHeaders for content-type — Flutter Web / browser
      // fetch signature mismatches then become R2 403s (shown as CORS).
      const uploadUrl = await getSignedUrl(s3, command, {
        expiresIn: PRESIGNED_URL_EXPIRES_IN_SECONDS,
      });

      const queryKeys = [...new URL(uploadUrl).searchParams.keys()];
      const hasChecksumQuery = queryKeys.some((key) =>
        key.toLowerCase().includes("checksum")
      );
      if (hasChecksumQuery) {
        console.error(
          JSON.stringify({
            event: "create-r2-upload-urls.checksum_in_signed_url",
            objectKey,
            queryKeys,
          }),
        );
        return errorResponse(500, "INTERNAL_ERROR", origin);
      }

      items.push({
        clientFileName: file.fileName,
        contentType: file.contentType,
        objectKey,
        uploadUrl,
        publicUrl: buildPublicUrl(r2.publicBaseUrl, objectKey),
      });
    }

    console.log(
      JSON.stringify({
        event: "create-r2-upload-urls.success",
        userId: authz.userId,
        category: verifiedCategoryName,
        fileCount: items.length,
      }),
    );

    return jsonResponse(200, { items }, origin);
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "create-r2-upload-urls.internal_error",
        message: error instanceof Error ? error.message : "unknown",
      }),
    );
    return errorResponse(500, "INTERNAL_ERROR", origin);
  }
});
