"use strict";

const { randomUUID } = require("node:crypto");
const { HttpsError } = require("firebase-functions/v2/https");

const ERROR_CODES = Object.freeze({
  UNAUTHENTICATED: "unauthenticated",
  PERMISSION_DENIED: "permission-denied",
  INVALID_ARGUMENT: "invalid-argument",
  NOT_FOUND: "not-found",
  OFFLINE: "offline",
  NETWORK_ERROR: "network-error",
  UNAVAILABLE: "unavailable",
  TIMEOUT: "timeout",
  RATE_LIMITED: "rate-limited",
  INSUFFICIENT_BALANCE: "insufficient-balance",
  PROVIDER_NOT_FOUND: "provider-not-found",
  PROVIDER_INACTIVE: "provider-inactive",
  PAYMENT_PENDING: "payment-pending",
  PAYMENT_FAILED: "payment-failed",
  IDEMPOTENCY_CONFLICT: "idempotency-conflict",
  VERIFICATION_FAILED: "verification-failed",
  SAVINGS_FAILED: "savings-failed",
  FAMILY_PERMISSION_DENIED: "family-permission-denied",
  FAMILY_INVITE_INVALID: "family-invite-invalid",
  INTERNAL: "internal",
});

const DEFINITIONS = Object.freeze({
  "unauthenticated": definition("Your session has expired. Sign in again.", false, "sign_in", "unauthenticated"),
  "permission-denied": definition("You do not have permission to perform this action.", false, "go_back", "permission-denied"),
  "invalid-argument": definition("Check the information provided and try again.", false, "correct_input", "invalid-argument"),
  "not-found": definition("The requested record could not be found.", false, "refresh", "not-found"),
  "offline": definition("You appear to be offline. Reconnect and try again.", true, "retry", "unavailable"),
  "network-error": definition("A network error occurred. Check your connection and try again.", true, "retry", "unavailable"),
  "unavailable": definition("This service is temporarily unavailable. Please try again.", true, "retry", "unavailable"),
  "timeout": definition("The request is taking longer than expected. Check its status before retrying.", true, "check_status", "deadline-exceeded"),
  "rate-limited": definition("Too many attempts. Please wait before trying again.", true, "wait_and_retry", "resource-exhausted"),
  "insufficient-balance": definition("Your HealthPocket balance is insufficient for this payment.", false, "add_money", "failed-precondition"),
  "provider-not-found": definition("This healthcare provider could not be found.", false, "choose_provider", "not-found"),
  "provider-inactive": definition("This healthcare provider is currently unavailable.", false, "choose_provider", "failed-precondition"),
  "payment-pending": definition("This payment is still processing. Check its status before retrying.", true, "check_status", "aborted"),
  "payment-failed": definition("The payment was not completed. Review the details and try again.", true, "review_and_retry", "failed-precondition"),
  "idempotency-conflict": definition("This request key was already used for different details.", false, "start_new_request", "already-exists"),
  "verification-failed": definition("The supplied details could not be verified.", false, "review_details", "failed-precondition"),
  "savings-failed": definition("The savings operation could not be completed.", true, "review_and_retry", "failed-precondition"),
  "family-permission-denied": definition("Your Family Pocket role does not allow this action.", false, "contact_pocket_admin", "permission-denied"),
  "family-invite-invalid": definition("This Family Pocket invitation is invalid or no longer available.", false, "request_new_invite", "failed-precondition"),
  "internal": definition("Something went wrong. Please try again.", true, "retry", "internal"),
});

const ALIASES = Object.freeze({
  "user-disabled": "permission-denied",
  "user-not-found": "unauthenticated",
  "invalid-user-token": "unauthenticated",
  "user-token-expired": "unauthenticated",
  "network-request-failed": "network-error",
  "provider-timeout": "timeout",
  "verification-timeout": "timeout",
  "account-resolution-unavailable": "unavailable",
  "healthcare-verification-unavailable": "unavailable",
  "invalid-amount": "invalid-argument",
  "invalid-cursor": "invalid-argument",
  "invalid-state": "invalid-argument",
  "invalid-transition": "invalid-argument",
  "invalid-kind": "invalid-argument",
  "missing-provider-reference": "payment-pending",
  "not-verifiable": "payment-pending",
  "provider-failed": "payment-failed",
  "invalid-provider-response": "payment-failed",
  "account-resolution-failed": "verification-failed",
  "healthcare-verification-failed": "verification-failed",
  "verification-required": "verification-failed",
  "plan-not-found": "not-found",
  "plan-already-exists": "idempotency-conflict",
  "plan-cancelled": "savings-failed",
  "not-due": "savings-failed",
  "pocket-unavailable": "savings-failed",
  "duplicate-invite": "family-invite-invalid",
  "invite-already-created": "family-invite-invalid",
  "invite-not-found": "family-invite-invalid",
  "email-not-verified": "verification-failed",
  "owner-transfer-required": "family-permission-denied",
  "pocket-closed": "family-permission-denied",
  "already-member": "family-invite-invalid",
  "already-reversed": "idempotency-conflict",
  "wallet-not-found": "not-found",
  "wallet-unavailable": "unavailable",
  "operation-not-found": "not-found",
  "token-conflict": "idempotency-conflict",
  "integrity-error": "internal",
  "invalid-signature": "permission-denied",
  "invalid-webhook": "invalid-argument",
  "provider-reference-conflict": "idempotency-conflict",
  "provider-reference-mismatch": "payment-failed",
  "provider-flow-mismatch": "provider-inactive",
  "webhook-conflict": "idempotency-conflict",
  "invalid-bank-details": "verification-failed",
  "not-implemented": "unavailable",
  "receipt-not-eligible": "invalid-argument",
});

class BackendError extends Error {
  constructor(code, { cause = null } = {}) {
    const normalized = normalizeCode(code);
    super(DEFINITIONS[normalized].message, cause ? { cause } : undefined);
    this.name = "BackendError";
    this.code = normalized;
    this.retryable = DEFINITIONS[normalized].retryable;
    this.action = DEFINITIONS[normalized].action;
  }
}

function normalizeError(error) {
  if (error instanceof BackendError) return error;
  const originalCode = typeof error?.code === "string" ? error.code : null;
  return new BackendError(originalCode || ERROR_CODES.INTERNAL, { cause: error });
}

function publicError(error, { correlationId = randomUUID() } = {}) {
  const normalized = normalizeError(error);
  const definitionValue = DEFINITIONS[normalized.code];
  return Object.freeze({
    code: normalized.code,
    message: definitionValue.message,
    retryable: definitionValue.retryable,
    action: definitionValue.action,
    correlationId,
  });
}

function toHttpsError(error, options) {
  const safe = publicError(error, options);
  return new HttpsError(
    DEFINITIONS[safe.code].httpsCode,
    safe.message,
    {
      code: safe.code,
      retryable: safe.retryable,
      action: safe.action,
      correlationId: safe.correlationId,
    },
  );
}

async function runCallable({ operation, logger = console, handler }) {
  const safeOperation = safeLabel(operation);
  logger.info?.("healthpocket_backend", {
    component: "callable",
    operation: safeOperation,
    outcome: "started",
  });
  try {
    const result = await handler();
    logger.info?.("healthpocket_backend", {
      component: "callable",
      operation: safeOperation,
      outcome: "success",
    });
    return result;
  } catch (error) {
    const correlationId = randomUUID();
    const safe = publicError(error, { correlationId });
    logger.error?.("healthpocket_backend", {
      component: "callable",
      operation: safeOperation,
      outcome: "failure",
      errorCode: safe.code,
      errorType: safeLabel(error?.name || "Error"),
      correlationId,
    });
    throw toHttpsError(error, { correlationId });
  }
}

function assertAuthenticated(auth) {
  if (!auth || typeof auth.uid !== "string" || !auth.uid) {
    throw new BackendError(ERROR_CODES.UNAUTHENTICATED);
  }
  return auth.uid;
}

function assertVerifiedGoogleIdentity(auth) {
  const userId = assertAuthenticated(auth);
  const token = auth.token;
  if (!token || token.email_verified !== true ||
      token.firebase?.sign_in_provider !== "google.com") {
    throw new BackendError(ERROR_CODES.PERMISSION_DENIED);
  }
  return Object.freeze({
    userId,
    email: typeof token.email === "string" ? token.email : null,
    displayName: typeof token.name === "string" && token.name.trim()
      ? token.name.trim().slice(0, 100)
      : "HealthPocket user",
  });
}

function assertAuthorized(condition, code = ERROR_CODES.PERMISSION_DENIED) {
  if (condition !== true) throw new BackendError(code);
}

function failureForStatus(domain, status) {
  if (status === "pending" || status === "created" || status === "processing") {
    return new BackendError(ERROR_CODES.PAYMENT_PENDING);
  }
  if (domain === "savings") return new BackendError(ERROR_CODES.SAVINGS_FAILED);
  if (domain === "verification") return new BackendError(ERROR_CODES.VERIFICATION_FAILED);
  return new BackendError(ERROR_CODES.PAYMENT_FAILED);
}

function normalizeCode(code) {
  if (typeof code !== "string") return ERROR_CODES.INTERNAL;
  const stripped = code.includes("/") ? code.split("/").at(-1) : code;
  if (Object.hasOwn(DEFINITIONS, stripped)) return stripped;
  return ALIASES[stripped] || ERROR_CODES.INTERNAL;
}

function definition(message, retryable, action, httpsCode) {
  return Object.freeze({ message, retryable, action, httpsCode });
}

function safeLabel(value) {
  return typeof value === "string" && /^[A-Za-z][A-Za-z0-9_.-]{0,63}$/.test(value)
    ? value
    : "unknown";
}

module.exports = {
  BackendError,
  ERROR_CODES,
  normalizeError,
  normalizeCode,
  publicError,
  toHttpsError,
  runCallable,
  assertAuthenticated,
  assertVerifiedGoogleIdentity,
  assertAuthorized,
  failureForStatus,
};
