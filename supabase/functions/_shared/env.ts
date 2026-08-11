/**
 * Centralized environment variable access for ApniPost Edge Functions.
 * Reads secrets via Deno.env.get() only — never hardcodes values.
 *
 * Configure via:
 *   supabase secrets set FAST2SMS_API_KEY=... FAST2SMS_SENDER_ID=... \
 *     FAST2SMS_ENTITY_ID=... FAST2SMS_TEMPLATE_ID=...
 */

/** Reads a required environment variable; throws when missing. */
export function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

/** Reads an optional environment variable. */
export function optionalEnv(name: string): string | undefined {
  return Deno.env.get(name) ?? undefined;
}

export interface Fast2SmsConfig {
  apiKey: string;
  senderId: string;
  entityId: string;
  templateId: string;
}

/**
 * Fast2SMS DLT credentials. Resolved lazily so functions that never send SMS
 * (e.g. health-check) can boot without these secrets being set.
 */
export function getFast2SmsConfig(): Fast2SmsConfig {
  return {
    apiKey: requireEnv("FAST2SMS_API_KEY"),
    senderId: requireEnv("FAST2SMS_SENDER_ID"),
    entityId: requireEnv("FAST2SMS_ENTITY_ID"),
    templateId: requireEnv("FAST2SMS_TEMPLATE_ID"),
  };
}
