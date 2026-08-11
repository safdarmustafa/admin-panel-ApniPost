/**
 * Centralized error codes and messages for ApniPost Edge Functions.
 * Every user-facing error must come from here so clients can rely on
 * stable, machine-readable codes.
 */

export const ERROR_CODES = {
  PHONE_INVALID: "PHONE_INVALID",
  OTP_INVALID: "OTP_INVALID",
  OTP_EXPIRED: "OTP_EXPIRED",
  OTP_ALREADY_USED: "OTP_ALREADY_USED",
  TOO_MANY_REQUESTS: "TOO_MANY_REQUESTS",
  SMS_DELIVERY_FAILED: "SMS_DELIVERY_FAILED",
  METHOD_NOT_ALLOWED: "METHOD_NOT_ALLOWED",
  BAD_REQUEST: "BAD_REQUEST",
  INTERNAL_SERVER_ERROR: "INTERNAL_SERVER_ERROR",
} as const;

export type ErrorCode = (typeof ERROR_CODES)[keyof typeof ERROR_CODES];

interface ErrorDefinition {
  /** Human-readable message safe to show to end users. */
  message: string;
  /** HTTP status the error should be served with. */
  httpStatus: number;
}

export const ERROR_DEFINITIONS: Record<ErrorCode, ErrorDefinition> = {
  [ERROR_CODES.PHONE_INVALID]: {
    message: "Please enter a valid Indian mobile number.",
    httpStatus: 400,
  },
  [ERROR_CODES.OTP_INVALID]: {
    message: "The OTP you entered is incorrect.",
    httpStatus: 400,
  },
  [ERROR_CODES.OTP_EXPIRED]: {
    message: "This OTP has expired. Please request a new one.",
    httpStatus: 400,
  },
  [ERROR_CODES.OTP_ALREADY_USED]: {
    message: "This OTP has already been used. Please request a new one.",
    httpStatus: 400,
  },
  [ERROR_CODES.TOO_MANY_REQUESTS]: {
    message: "Too many requests. Please wait before trying again.",
    httpStatus: 429,
  },
  [ERROR_CODES.SMS_DELIVERY_FAILED]: {
    message: "We could not send the OTP right now. Please try again.",
    httpStatus: 502,
  },
  [ERROR_CODES.METHOD_NOT_ALLOWED]: {
    message: "This HTTP method is not allowed on this endpoint.",
    httpStatus: 405,
  },
  [ERROR_CODES.BAD_REQUEST]: {
    message: "The request is malformed or missing required fields.",
    httpStatus: 400,
  },
  [ERROR_CODES.INTERNAL_SERVER_ERROR]: {
    message: "Something went wrong on our side. Please try again later.",
    httpStatus: 500,
  },
};
