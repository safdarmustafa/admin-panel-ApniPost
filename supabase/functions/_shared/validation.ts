/**
 * Input validation helpers for ApniPost Edge Functions.
 * Validation and normalization only — no HTTP, DB, or hashing.
 */

import { OTP_LENGTH } from "./constants.ts";
import { ERROR_CODES, type ErrorCode } from "./errors.ts";

export interface ValidationResult {
  valid: boolean;
  /** Present only when valid is false. */
  error?: ErrorCode;
  /** Canonical value to use downstream (e.g. phone without +91). */
  normalized?: string;
}

/** Indian mobile numbers: 10 digits starting with 6-9. */
const INDIAN_MOBILE_REGEX = /^[6-9]\d{9}$/;

/**
 * Normalizes an Indian mobile number to the bare 10-digit form.
 * Strips whitespace, dashes, and optional "+91" / "91" / "0" prefixes.
 * Returns null when the input cannot be reduced to 10 digits.
 */
export function normalizeIndianPhone(input: string): string | null {
  let digits = input.trim().replace(/[\s-]/g, "");

  if (digits.startsWith("+91")) {
    digits = digits.slice(3);
  } else if (digits.startsWith("91") && digits.length === 12) {
    digits = digits.slice(2);
  } else if (digits.startsWith("0") && digits.length === 11) {
    digits = digits.slice(1);
  }

  return INDIAN_MOBILE_REGEX.test(digits) ? digits : null;
}

/**
 * Validates an Indian mobile number and returns the normalized 10-digit form.
 */
export function validateIndianPhone(input: unknown): ValidationResult {
  if (typeof input !== "string") {
    return { valid: false, error: ERROR_CODES.PHONE_INVALID };
  }

  const normalized = normalizeIndianPhone(input);
  if (!normalized) {
    return { valid: false, error: ERROR_CODES.PHONE_INVALID };
  }

  return { valid: true, normalized };
}

/** Validates an OTP: exactly OTP_LENGTH numeric digits. */
export function validateOtpFormat(input: unknown): ValidationResult {
  if (typeof input !== "string") {
    return { valid: false, error: ERROR_CODES.OTP_INVALID };
  }

  const otp = input.trim();
  const otpRegex = new RegExp(`^\\d{${OTP_LENGTH}}$`);

  if (!otpRegex.test(otp)) {
    return { valid: false, error: ERROR_CODES.OTP_INVALID };
  }

  return { valid: true, normalized: otp };
}
