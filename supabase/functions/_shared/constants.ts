/**
 * Reusable backend constants for ApniPost Edge Functions.
 * Pure configuration values only — no business logic.
 */

/** Number of digits in a generated OTP. */
export const OTP_LENGTH = 6;

/** How long an OTP stays valid after being issued (5 minutes). */
export const OTP_EXPIRY_SECONDS = 5 * 60;

/** Minimum wait before the same phone number can request a new OTP. */
export const RESEND_DELAY_SECONDS = 30;

/** Maximum wrong verification attempts before the challenge is invalidated. */
export const MAX_OTP_ATTEMPTS = 5;
