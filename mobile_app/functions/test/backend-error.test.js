"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const {
  BackendError,
  ERROR_CODES,
  normalizeCode,
  publicError,
  toHttpsError,
  runCallable,
  assertAuthenticated,
  assertAuthorized,
  failureForStatus,
} = require("../src/errors/backend-error");

test("standardizes core backend failure scenarios", () => {
  const expected = {
    unauthenticated: [false, "sign_in"],
    "permission-denied": [false, "go_back"],
    "invalid-argument": [false, "correct_input"],
    offline: [true, "retry"],
    "network-error": [true, "retry"],
    "insufficient-balance": [false, "add_money"],
    "provider-not-found": [false, "choose_provider"],
    "provider-inactive": [false, "choose_provider"],
    "payment-pending": [true, "check_status"],
    "payment-failed": [true, "review_and_retry"],
    "idempotency-conflict": [false, "start_new_request"],
    "verification-failed": [false, "review_details"],
    "savings-failed": [true, "review_and_retry"],
    "family-permission-denied": [false, "contact_pocket_admin"],
    "family-invite-invalid": [false, "request_new_invite"],
  };
  for (const [code, [retryable, action]] of Object.entries(expected)) {
    const failure = publicError(new BackendError(code), { correlationId: "test-correlation" });
    assert.equal(failure.code, code);
    assert.equal(failure.retryable, retryable);
    assert.equal(failure.action, action);
    assert.ok(failure.message.length > 0);
  }
});

test("maps existing domain aliases into the shared contract", () => {
  assert.equal(normalizeCode("provider-timeout"), "timeout");
  assert.equal(normalizeCode("healthcare-verification-failed"), "verification-failed");
  assert.equal(normalizeCode("plan-cancelled"), "savings-failed");
  assert.equal(normalizeCode("invite-not-found"), "family-invite-invalid");
  assert.equal(normalizeCode("functions/unauthenticated"), "unauthenticated");
  assert.equal(normalizeCode("never-seen-internal-code"), "internal");
});

test("never exposes stack traces, provider messages, or unknown codes", () => {
  const providerError = new Error("Bearer secret-api-key internal stack detail");
  providerError.code = "provider-secret-failure";
  const safe = publicError(providerError, { correlationId: "public-id" });
  assert.deepEqual(safe, {
    code: "internal",
    message: "Something went wrong. Please try again.",
    retryable: true,
    action: "retry",
    correlationId: "public-id",
  });
  assert.doesNotMatch(JSON.stringify(safe), /Bearer|secret-api-key|stack detail/);

  const callable = toHttpsError(providerError, { correlationId: "public-id" });
  assert.equal(callable.code, "internal");
  assert.equal(callable.details.code, "internal");
  assert.doesNotMatch(JSON.stringify(callable.details), /Bearer|secret|stack/);
});

test("enforces authentication and authorization consistently", () => {
  assert.equal(assertAuthenticated({ uid: "user-1" }), "user-1");
  assert.throws(
    () => assertAuthenticated(null),
    (error) => error.code === ERROR_CODES.UNAUTHENTICATED,
  );
  assert.doesNotThrow(() => assertAuthorized(true));
  assert.throws(
    () => assertAuthorized(false),
    (error) => error.code === ERROR_CODES.PERMISSION_DENIED,
  );
});

test("turns lifecycle states into actionable payment, verification and savings failures", () => {
  assert.equal(failureForStatus("payment", "pending").code, "payment-pending");
  assert.equal(failureForStatus("payment", "failed").code, "payment-failed");
  assert.equal(failureForStatus("verification", "failed").code, "verification-failed");
  assert.equal(failureForStatus("savings", "failed").code, "savings-failed");
});

test("callable wrapper logs only safe metadata and returns a public HttpsError", async () => {
  const entries = [];
  const logger = { error(event, fields) { entries.push({ event, fields }); } };
  await assert.rejects(
    runCallable({
      operation: "complete_payment",
      logger,
      handler: async () => {
        const error = new Error("account 1234567890 secret provider response");
        error.code = "provider-timeout";
        throw error;
      },
    }),
    (error) => {
      assert.equal(error.code, "deadline-exceeded");
      assert.equal(error.details.code, "timeout");
      assert.equal(error.details.retryable, true);
      assert.equal(error.details.action, "check_status");
      assert.doesNotMatch(JSON.stringify(error), /1234567890|secret provider/);
      return true;
    },
  );
  assert.equal(entries.length, 1);
  assert.deepEqual(Object.keys(entries[0].fields).sort(), [
    "component", "correlationId", "errorCode", "errorType", "operation", "outcome",
  ]);
  assert.doesNotMatch(JSON.stringify(entries), /1234567890|secret provider/);
});
