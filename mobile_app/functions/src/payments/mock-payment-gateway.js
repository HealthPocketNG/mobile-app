"use strict";

const { createHmac, timingSafeEqual } = require("node:crypto");
const {
  PaymentGateway,
  PaymentGatewayError,
  PAYMENT_STATUS,
  PAYMENT_STATUSES,
} = require("./payment-gateway");

const MOCK_OUTCOMES = new Set([
  "success",
  "pending",
  "failure",
  "timeout",
  "reversal",
]);

class MockPaymentGateway extends PaymentGateway {
  constructor({ webhookSecret = "healthpocket-local-emulator-only" } = {}) {
    super({ name: "mock" });
    if (typeof webhookSecret !== "string" || webhookSecret.length < 16) {
      throw new TypeError("The mock webhook secret must contain at least 16 characters.");
    }
    this.webhookSecret = webhookSecret;
    this.outcomes = new Map();
    this.transactions = new Map();
    this.requests = new Map();
    this.sequence = 0;
  }

  setNextOutcome(operation, outcome) {
    if (!MOCK_OUTCOMES.has(outcome)) {
      throw new PaymentGatewayError("invalid-argument", "Unknown mock outcome.");
    }
    const queue = this.outcomes.get(operation) || [];
    queue.push(outcome);
    this.outcomes.set(operation, queue);
  }

  async initializeFunding(request) {
    return this.#initialize("initializeFunding", "funding", request);
  }

  async verifyFunding({ providerReference }) {
    return this.#verify("verifyFunding", providerReference);
  }

  async resolveBeneficiary({ beneficiaryId }) {
    const outcome = this.#takeOutcome("resolveBeneficiary", "success");
    if (outcome === "timeout") throw providerTimeout();
    return {
      status: outcomeStatus(outcome),
      valid: outcome === "success",
      beneficiary: outcome === "success"
        ? { id: beneficiaryId, displayName: "Mock healthcare beneficiary" }
        : null,
    };
  }

  async initiateHealthcarePayment(request) {
    return this.#initialize(
      "initiateHealthcarePayment",
      "healthcare_payment",
      request,
    );
  }

  async verifyTransaction({ providerReference }) {
    return this.#verify("verifyTransaction", providerReference);
  }

  async queryStatus({ providerReference }) {
    const transaction = this.#transaction(providerReference);
    const outcome = this.#takeOutcome("queryStatus", null);
    if (outcome === "timeout") throw providerTimeout();
    if (outcome) transaction.status = outcomeStatus(outcome);
    return providerResult(transaction);
  }

  async verifyWebhookSignature({ rawBody, headers }) {
    const supplied = headerValue(headers, "x-healthpocket-mock-signature");
    if (!supplied || !/^[a-f0-9]{64}$/.test(supplied)) return false;
    const expected = this.#sign(rawBody);
    return timingSafeEqual(Buffer.from(supplied, "hex"), Buffer.from(expected, "hex"));
  }

  async parseWebhook({ rawBody }) {
    let value;
    try {
      value = JSON.parse(asBuffer(rawBody).toString("utf8"));
    } catch (_) {
      throw new PaymentGatewayError("invalid-webhook", "Webhook JSON is invalid.");
    }
    if (!value || typeof value !== "object" ||
        typeof value.eventId !== "string" ||
        typeof value.attemptId !== "string" ||
        typeof value.providerReference !== "string" ||
        !Number.isSafeInteger(value.amountKobo) || value.amountKobo <= 0 ||
        value.currency !== "NGN" ||
        !(value.beneficiaryId === null || typeof value.beneficiaryId === "string") ||
        !PAYMENT_STATUSES.has(value.status)) {
      throw new PaymentGatewayError("invalid-webhook", "Webhook fields are invalid.");
    }
    return {
      eventId: value.eventId,
      attemptId: value.attemptId,
      providerReference: value.providerReference,
      status: value.status,
      amountKobo: value.amountKobo,
      currency: value.currency,
      beneficiaryId: value.beneficiaryId,
    };
  }

  buildWebhookCallback({
    eventId,
    attemptId,
    providerReference,
    status,
    duplicate = false,
    amountKobo,
    currency,
    beneficiaryId,
  }) {
    if (!PAYMENT_STATUSES.has(status)) {
      throw new PaymentGatewayError("invalid-argument", "Webhook status is invalid.");
    }
    const transaction = this.#transaction(providerReference);
    const rawBody = Buffer.from(JSON.stringify({
      eventId,
      attemptId,
      providerReference,
      status,
      amountKobo: amountKobo ?? transaction.amountKobo,
      currency: currency ?? transaction.currency,
      beneficiaryId: beneficiaryId ?? transaction.beneficiaryId,
    }));
    const delivery = {
      rawBody,
      headers: {
        "x-healthpocket-mock-signature": this.#sign(rawBody),
      },
    };
    return duplicate ? [delivery, { ...delivery }] : [delivery];
  }

  #initialize(operation, kind, request) {
    const existingReference = this.requests.get(request.requestId);
    if (existingReference) return providerResult(this.transactions.get(existingReference));

    const outcome = this.#takeOutcome(operation, "pending");
    if (outcome === "timeout") throw providerTimeout();
    const providerReference = `mock_${kind}_${String(++this.sequence).padStart(6, "0")}`;
    const transaction = {
      providerReference,
      requestId: request.requestId,
      status: outcomeStatus(outcome),
      amountKobo: request.amountKobo,
      currency: request.currency,
      beneficiaryId: request.beneficiaryId ?? null,
    };
    this.requests.set(request.requestId, providerReference);
    this.transactions.set(providerReference, transaction);
    return providerResult(transaction);
  }

  #verify(operation, providerReference) {
    const transaction = this.#transaction(providerReference);
    const outcome = this.#takeOutcome(operation, null);
    if (outcome === "timeout") throw providerTimeout();
    if (outcome) transaction.status = outcomeStatus(outcome);
    return providerResult(transaction);
  }

  #transaction(providerReference) {
    const transaction = this.transactions.get(providerReference);
    if (!transaction) {
      throw new PaymentGatewayError("not-found", "Mock transaction was not found.");
    }
    return transaction;
  }

  #takeOutcome(operation, fallback) {
    const queue = this.outcomes.get(operation);
    if (!queue || queue.length === 0) return fallback;
    return queue.shift();
  }

  #sign(rawBody) {
    return createHmac("sha256", this.webhookSecret)
      .update(asBuffer(rawBody))
      .digest("hex");
  }
}

function outcomeStatus(outcome) {
  return {
    success: PAYMENT_STATUS.SUCCEEDED,
    pending: PAYMENT_STATUS.PENDING,
    failure: PAYMENT_STATUS.FAILED,
    reversal: PAYMENT_STATUS.REVERSED,
  }[outcome];
}

function providerResult(transaction) {
  return {
    status: transaction.status,
    providerReference: transaction.providerReference,
    amountKobo: transaction.amountKobo,
    currency: transaction.currency,
    beneficiaryId: transaction.beneficiaryId,
  };
}

function providerTimeout() {
  return new PaymentGatewayError("provider-timeout", "The mock provider timed out.");
}

function asBuffer(rawBody) {
  if (Buffer.isBuffer(rawBody)) return rawBody;
  if (typeof rawBody === "string") return Buffer.from(rawBody);
  throw new PaymentGatewayError("invalid-webhook", "Webhook body must be raw bytes.");
}

function headerValue(headers, name) {
  if (!headers || typeof headers !== "object") return null;
  const entry = Object.entries(headers).find(
    ([key]) => key.toLowerCase() === name,
  );
  return Array.isArray(entry?.[1]) ? entry[1][0] : entry?.[1] || null;
}

module.exports = { MockPaymentGateway, MOCK_OUTCOMES };
