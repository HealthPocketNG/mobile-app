"use strict";

const PAYMENT_STATUS = Object.freeze({
  CREATED: "created",
  PENDING: "pending",
  SUCCEEDED: "succeeded",
  FAILED: "failed",
  CANCELLED: "cancelled",
  TIMED_OUT: "timed_out",
  REVERSED: "reversed",
});

const PAYMENT_STATUSES = new Set(Object.values(PAYMENT_STATUS));

class PaymentGatewayError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "PaymentGatewayError";
    this.code = code;
  }
}

// Provider-neutral contract. A regulated provider adapter must implement every
// method and translate its proprietary states into PAYMENT_STATUS values.
class PaymentGateway {
  constructor({ name }) {
    if (new.target === PaymentGateway) {
      throw new TypeError("PaymentGateway is an abstract contract.");
    }
    requireBoundedString(name, "name", 40);
    this.name = name;
  }

  async initializeFunding(_request) {
    throw notImplemented("initializeFunding");
  }

  async verifyFunding(_request) {
    throw notImplemented("verifyFunding");
  }

  async resolveBeneficiary(_request) {
    throw notImplemented("resolveBeneficiary");
  }

  async initiateHealthcarePayment(_request) {
    throw notImplemented("initiateHealthcarePayment");
  }

  async verifyTransaction(_request) {
    throw notImplemented("verifyTransaction");
  }

  async queryStatus(_request) {
    throw notImplemented("queryStatus");
  }

  async verifyWebhookSignature(_request) {
    throw notImplemented("verifyWebhookSignature");
  }

  async parseWebhook(_request) {
    throw notImplemented("parseWebhook");
  }
}

function assertNormalizedStatus(status) {
  if (!PAYMENT_STATUSES.has(status)) {
    throw new PaymentGatewayError(
      "invalid-provider-response",
      "The adapter returned an unknown normalized payment status.",
    );
  }
  return status;
}

function notImplemented(method) {
  return new PaymentGatewayError(
    "not-implemented",
    `Payment gateway method ${method} is not implemented.`,
  );
}

function requireBoundedString(value, name, maximum) {
  if (typeof value !== "string" || value.length < 1 || value.length > maximum) {
    throw new PaymentGatewayError("invalid-argument", `${name} is invalid.`);
  }
}

module.exports = {
  PaymentGateway,
  PaymentGatewayError,
  PAYMENT_STATUS,
  PAYMENT_STATUSES,
  assertNormalizedStatus,
};
