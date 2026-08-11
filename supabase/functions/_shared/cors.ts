/**
 * Reusable CORS headers for all ApniPost Edge Functions.
 * Every function should call [handleCorsPreflight] first and attach
 * [corsHeaders] (already included by response.ts helpers) to responses.
 */

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

/**
 * Handles CORS preflight. Returns a 204 response for OPTIONS,
 * or null when the request should be processed normally.
 */
export function handleCorsPreflight(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  return null;
}
