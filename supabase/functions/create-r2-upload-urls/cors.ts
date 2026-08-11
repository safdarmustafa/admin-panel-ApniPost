/**
 * CORS for the Edge Function (browser → Supabase Functions).
 *
 * R2 bucket CORS is intentionally NOT configured in Phase 4A.
 *
 * Allowed origins:
 * - http://localhost:<any-port>
 * - http://127.0.0.1:<any-port>
 * - PRODUCTION_ADMIN_ORIGIN (optional single origin)
 * - ALLOWED_ADMIN_ORIGINS (optional comma-separated list)
 */

function parseConfiguredOrigins(): string[] {
  const origins = new Set<string>();

  const production = Deno.env.get("PRODUCTION_ADMIN_ORIGIN")?.trim();
  if (production) {
    origins.add(production.replace(/\/+$/, ""));
  }

  const allowList = Deno.env.get("ALLOWED_ADMIN_ORIGINS")?.trim();
  if (allowList) {
    for (const item of allowList.split(",")) {
      const origin = item.trim().replace(/\/+$/, "");
      if (origin.length > 0) {
        origins.add(origin);
      }
    }
  }

  return [...origins];
}

export function isLocalDevOrigin(origin: string): boolean {
  try {
    const url = new URL(origin);
    if (url.protocol !== "http:") return false;
    return url.hostname === "localhost" || url.hostname === "127.0.0.1";
  } catch {
    return false;
  }
}

export function resolveAllowedOrigin(requestOrigin: string | null): string | null {
  if (!requestOrigin) return null;

  if (isLocalDevOrigin(requestOrigin)) {
    return requestOrigin;
  }

  const normalized = requestOrigin.replace(/\/+$/, "");
  const configured = parseConfiguredOrigins();
  if (configured.includes(normalized)) {
    return normalized;
  }

  return null;
}

export function corsHeaders(requestOrigin: string | null): HeadersInit {
  const allowed = resolveAllowedOrigin(requestOrigin);
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    Vary: "Origin",
  };

  if (allowed) {
    headers["Access-Control-Allow-Origin"] = allowed;
  }

  return headers;
}
