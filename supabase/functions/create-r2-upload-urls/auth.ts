import { isAdminFromAppMetadata } from "./validate.ts";

export type AuthResult =
  | { ok: true; userId: string }
  | { ok: false; status: 401 | 403; error: "UNAUTHENTICATED" | "ADMIN_ACCESS_REQUIRED" };

export interface AuthUserLike {
  id: string;
  app_metadata?: Record<string, unknown> | null;
}

/**
 * Fail-closed authentication + admin authorization.
 * Uses JWT app_metadata.role === "admin" only.
 */
export function authorizeAdminUser(
  user: AuthUserLike | null | undefined,
): AuthResult {
  if (!user || !user.id) {
    return { ok: false, status: 401, error: "UNAUTHENTICATED" };
  }

  if (!isAdminFromAppMetadata(user.app_metadata ?? null)) {
    return { ok: false, status: 403, error: "ADMIN_ACCESS_REQUIRED" };
  }

  return { ok: true, userId: user.id };
}
