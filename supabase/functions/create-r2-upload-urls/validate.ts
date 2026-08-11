import {
  isAllowedContentType,
  maxBytesForContentType,
  MAX_FILES_PER_REQUEST,
  type AllowedContentType,
} from "./constants.ts";
import type { ErrorCode } from "./types.ts";

export type ValidationSuccess = {
  ok: true;
  category: string;
  files: Array<{
    fileName: string;
    contentType: AllowedContentType;
    sizeBytes: number;
  }>;
};

export type ValidationFailure = {
  ok: false;
  status: number;
  error: ErrorCode;
  message?: string;
  fileName?: string;
};

export type ValidationResult = ValidationSuccess | ValidationFailure;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function validateFile(
  file: unknown,
  index: number,
): ValidationFailure | ValidationSuccess["files"][number] {
  if (!isRecord(file)) {
    return {
      ok: false,
      status: 400,
      error: "INVALID_REQUEST",
      message: `files[${index}] must be an object`,
    };
  }

  const fileName = file.fileName;
  const contentType = file.contentType;
  const sizeBytes = file.sizeBytes;

  if (typeof fileName !== "string" || fileName.trim().length === 0) {
    return {
      ok: false,
      status: 400,
      error: "INVALID_REQUEST",
      message: `files[${index}].fileName is required`,
      fileName: typeof fileName === "string" ? fileName : undefined,
    };
  }

  if (typeof contentType !== "string" || contentType.trim().length === 0) {
    return {
      ok: false,
      status: 400,
      error: "INVALID_REQUEST",
      message: `files[${index}].contentType is required`,
      fileName,
    };
  }

  if (typeof sizeBytes !== "number" || !Number.isFinite(sizeBytes) || sizeBytes < 0) {
    return {
      ok: false,
      status: 400,
      error: "INVALID_REQUEST",
      message: `files[${index}].sizeBytes must be a non-negative number`,
      fileName,
    };
  }

  if (!isAllowedContentType(contentType)) {
    return {
      ok: false,
      status: 400,
      error: "UNSUPPORTED_MEDIA_TYPE",
      message: `Unsupported content type "${contentType}" for file "${fileName}"`,
      fileName,
    };
  }

  const maxBytes = maxBytesForContentType(contentType);
  if (sizeBytes > maxBytes) {
    return {
      ok: false,
      status: 400,
      error: "FILE_TOO_LARGE",
      message:
        `File "${fileName}" exceeds the ${maxBytes} byte limit for ${contentType}`,
      fileName,
    };
  }

  return {
    fileName: fileName.trim(),
    contentType,
    sizeBytes,
  };
}

/**
 * Pure request validation (no DB / R2 access).
 * Fail closed: any invalid file rejects the entire request.
 */
export function validateCreateUploadUrlsRequest(
  body: unknown,
): ValidationResult {
  if (!isRecord(body)) {
    return {
      ok: false,
      status: 400,
      error: "INVALID_REQUEST",
      message: "Request body must be a JSON object",
    };
  }

  const category = body.category;
  if (typeof category !== "string" || category.trim().length === 0) {
    return {
      ok: false,
      status: 400,
      error: "INVALID_REQUEST",
      message: "category is required",
    };
  }

  const files = body.files;
  if (!Array.isArray(files)) {
    return {
      ok: false,
      status: 400,
      error: "INVALID_REQUEST",
      message: "files must be an array",
    };
  }

  if (files.length === 0) {
    return {
      ok: false,
      status: 400,
      error: "INVALID_REQUEST",
      message: "files must not be empty",
    };
  }

  if (files.length > MAX_FILES_PER_REQUEST) {
    return {
      ok: false,
      status: 400,
      error: "TOO_MANY_FILES",
      message: `A maximum of ${MAX_FILES_PER_REQUEST} files is allowed per request`,
    };
  }

  const validatedFiles: ValidationSuccess["files"] = [];
  for (let i = 0; i < files.length; i++) {
    const result = validateFile(files[i], i);
    if ("ok" in result && result.ok === false) {
      return result;
    }
    validatedFiles.push(result as ValidationSuccess["files"][number]);
  }

  return {
    ok: true,
    category: category.trim(),
    files: validatedFiles,
  };
}

/** Pure admin role check against JWT app_metadata. */
export function isAdminFromAppMetadata(
  appMetadata: Record<string, unknown> | null | undefined,
): boolean {
  if (!appMetadata || typeof appMetadata !== "object") {
    return false;
  }
  return appMetadata.role === "admin";
}

/** True when a categories.name lookup returned a usable row. */
export function categoryRowExists(
  row: { name?: string | null } | null | undefined,
): boolean {
  return typeof row?.name === "string" && row.name.trim().length > 0;
}

