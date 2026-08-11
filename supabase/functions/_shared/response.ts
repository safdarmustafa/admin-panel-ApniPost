/**
 * Standard JSON response helpers for ApniPost Edge Functions.
 *
 * Success envelope:
 *   { "success": true, "message": "...", "data": {} }
 *
 * Failure envelope:
 *   { "success": false, "message": "...", "error": { "code": "...", "details": "..." } }
 */

import { corsHeaders } from "./cors.ts";
import { ERROR_DEFINITIONS, type ErrorCode } from "./errors.ts";

const jsonHeaders: Record<string, string> = {
  ...corsHeaders,
  "Content-Type": "application/json",
};

/** Builds a successful JSON response in the standard envelope. */
export function successResponse(
  message: string,
  data: Record<string, unknown> = {},
  httpStatus = 200,
): Response {
  return new Response(
    JSON.stringify({ success: true, message, data }),
    { status: httpStatus, headers: jsonHeaders },
  );
}

/**
 * Builds an error JSON response from a centralized error code.
 * [details] is optional server/context info for clients that need it;
 * the user-facing [message] always comes from errors.ts.
 */
export function errorResponse(
  code: ErrorCode,
  details = "",
): Response {
  const definition = ERROR_DEFINITIONS[code];
  return new Response(
    JSON.stringify({
      success: false,
      message: definition.message,
      error: {
        code,
        details,
      },
    }),
    { status: definition.httpStatus, headers: jsonHeaders },
  );
}
