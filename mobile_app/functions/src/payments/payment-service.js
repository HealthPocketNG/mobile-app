"use strict";

const { createHash } = require("node:crypto");
const { Timestamp } = require("firebase-admin/firestore");
const {
  PaymentGatewayError,
  PAYMENT_STATUS,
  assertNormalizedStatus,
} = require("./payment-gateway");
const {
  MIN_FUNDING_AMOUNT_KOBO,
  MAX_FUNDING_AMOUNT_KOBO,
  isValidFundingAmount,
} = require("./funding-policy");

const CURRENCY = "NGN";
const MAX_AMOUNT_KOBO = 100000000000;
const SAFE_ID = /^[A-Za-z0-9_-]{1,256}$/;
const REQUEST_KEY = /^[A-Za-z0-9_-]{16,80}$/;
const ATTEMPT_KINDS = new Set(["funding", "healthcare_payment"]);

class PaymentServiceError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "PaymentServiceError";
    this.code = code;
  }
}

function buildPaymentService({ db, ledger, gateway, logger = console }) {
  if (!db || typeof db.runTransaction !== "function") {
    throw new TypeError("A Firestore Admin database is required.");
  }
  if (!ledger || typeof ledger.processOperation !== "function" ||
      typeof ledger.reverseOperation !== "function") {
    throw new TypeError("The trusted ledger service is required.");
  }
  if (!gateway || typeof gateway.verifyWebhookSignature !== "function") {
    throw new TypeError("A payment gateway adapter is required.");
  }

  const attempts = db.collection("payment_attempts");
  const events = db.collection("provider_events");
  const fundingTransactions = db.collection("funding_transactions");
  const activities = db.collection("activities");
  const notificationEvents = db.collection("notification_events");

  async function initializeFunding(input) {
    return createAttempt("funding", input, (request) =>
      gateway.initializeFunding(request));
  }

  async function initiateHealthcarePayment(input) {
    requireSafeId(input?.beneficiaryId, "beneficiaryId");
    return createAttempt("healthcare_payment", input, (request) =>
      gateway.initiateHealthcarePayment({
        ...request,
        beneficiaryId: input.beneficiaryId,
      }));
  }

  async function createAttempt(kind, input, initialize) {
    const normalized = normalizeAttempt(kind, input);
    const attemptId = attemptIdFor(normalized);
    const attemptRef = attempts.doc(attemptId);
    const requestFingerprint = hash(normalized);

    const existing = await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(attemptRef);
      if (snapshot.exists) {
        assertSameAttempt(snapshot.data(), requestFingerprint);
        return snapshot.data();
      }
      const now = Timestamp.now();
      const document = {
        schemaVersion: 1,
        userId: normalized.userId,
        kind,
        amountKobo: normalized.amountKobo,
        currency: CURRENCY,
        beneficiaryId: normalized.beneficiaryId,
        ledgerSource: normalized.ledgerSource,
        status: PAYMENT_STATUS.CREATED,
        provider: gateway.name,
        providerReference: null,
        requestFingerprint,
        ledgerOperationId: null,
        failureCode: null,
        createdAt: now,
        updatedAt: now,
      };
      transaction.create(attemptRef, document);
      if (isWalletFunding(document)) {
        transaction.create(
          fundingTransactions.doc(attemptId),
          fundingTransactionDocument(attemptId, document),
        );
      }
      return null;
    });

    if (existing && existing.status !== PAYMENT_STATUS.CREATED) {
      return attemptResult(attemptId, existing);
    }

    let providerResult;
    try {
      providerResult = normalizeProviderResult(await initialize({
        requestId: attemptId,
        userId: normalized.userId,
        amountKobo: normalized.amountKobo,
        currency: CURRENCY,
      }));
    } catch (error) {
      if (error instanceof PaymentGatewayError && error.code === "provider-timeout") {
        await updateAttemptStatus(attemptId, PAYMENT_STATUS.TIMED_OUT, {
          failureCode: "provider-timeout",
        });
        const timedOut = (await attemptRef.get()).data();
        await syncFundingOutcome(attemptId, timedOut);
        return attemptResult(attemptId, timedOut);
      }
      throw error;
    }

    // Initialization never moves money. Even if an adapter reports immediate
    // success, trusted verification or a signed webhook must finalize it.
    const initialStatus = providerResult.status === PAYMENT_STATUS.SUCCEEDED
      ? PAYMENT_STATUS.PENDING
      : providerResult.status;
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(attemptRef);
      const attempt = snapshot.data();
      assertSameAttempt(attempt, requestFingerprint);
      if (attempt.providerReference && providerResult.providerReference &&
          attempt.providerReference !== providerResult.providerReference) {
        throw new PaymentServiceError(
          "provider-reference-conflict",
          "The provider returned a different reference for the same request.",
        );
      }
      transaction.update(attemptRef, {
        status: initialStatus,
        providerReference: providerResult.providerReference,
        failureCode: initialStatus === PAYMENT_STATUS.FAILED
          ? "provider-failed"
          : null,
        updatedAt: Timestamp.now(),
      });
    });
    await syncFundingOutcome(attemptId, (await attemptRef.get()).data());
    log(logger, "initialize", initialStatus, kind);
    return attemptResult(attemptId, (await attemptRef.get()).data());
  }

  async function verifyFunding({ attemptId }) {
    const attempt = await getAttempt(attemptId, "funding");
    try {
      const result = await gateway.verifyFunding({
        requestId: attemptId,
        providerReference: requireProviderReference(attempt),
      });
      return applyTrustedStatus(attemptId, normalizeProviderResult(result).status);
    } catch (error) {
      if (error instanceof PaymentGatewayError && error.code === "provider-timeout") {
        return applyTrustedStatus(attemptId, PAYMENT_STATUS.TIMED_OUT);
      }
      throw error;
    }
  }

  async function verifyTransaction({ attemptId }) {
    const attempt = await getAttempt(attemptId, "healthcare_payment");
    const result = await gateway.verifyTransaction({
      requestId: attemptId,
      providerReference: requireProviderReference(attempt),
    });
    return applyTrustedStatus(attemptId, normalizeProviderResult(result).status);
  }

  async function resolveBeneficiary({ beneficiaryId }) {
    requireSafeId(beneficiaryId, "beneficiaryId");
    const result = await gateway.resolveBeneficiary({ beneficiaryId });
    assertNormalizedStatus(result?.status);
    return result;
  }

  async function queryStatus({ attemptId }) {
    const attempt = await getAttempt(attemptId);
    return normalizeProviderResult(await gateway.queryStatus({
      requestId: attemptId,
      providerReference: requireProviderReference(attempt),
    }));
  }

  async function processWebhook({ rawBody, headers }) {
    if (!await gateway.verifyWebhookSignature({ rawBody, headers })) {
      throw new PaymentServiceError(
        "invalid-signature",
        "Provider webhook signature verification failed.",
      );
    }
    const event = await gateway.parseWebhook({ rawBody, headers });
    validateEvent(event);
    const eventDocumentId = `event_${hash({
      provider: gateway.name,
      eventId: event.eventId,
    }).slice(0, 48)}`;
    const eventRef = events.doc(eventDocumentId);
    const fingerprint = hash(event);

    const claim = await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(eventRef);
      if (snapshot.exists) {
        if (snapshot.data().eventFingerprint !== fingerprint) {
          throw new PaymentServiceError(
            "webhook-conflict",
            "A provider event ID was reused with different data.",
          );
        }
        return { duplicate: true, processed: snapshot.data().status === "processed" };
      }
      const now = Timestamp.now();
      transaction.create(eventRef, {
        schemaVersion: 1,
        provider: gateway.name,
        providerEventId: event.eventId,
        paymentAttemptId: event.attemptId,
        providerReference: event.providerReference,
        normalizedStatus: event.status,
        eventFingerprint: fingerprint,
        status: "processing",
        createdAt: now,
        updatedAt: now,
      });
      return { duplicate: false, processed: false };
    });

    if (claim.processed) {
      const attempt = await getAttempt(event.attemptId);
      return { ...attemptResult(event.attemptId, attempt), duplicate: true };
    }

    const attempt = await getAttempt(event.attemptId);
    if (attempt.provider !== gateway.name ||
        attempt.providerReference !== event.providerReference) {
      throw new PaymentServiceError(
        "provider-reference-mismatch",
        "Webhook does not match the server-created payment attempt.",
      );
    }

    const result = await applyTrustedStatus(event.attemptId, event.status);
    await eventRef.update({
      status: "processed",
      outcomeStatus: result.status,
      updatedAt: Timestamp.now(),
    });
    log(logger, "process_webhook", result.status, attempt.kind);
    return { ...result, duplicate: claim.duplicate };
  }

  async function applyTrustedStatus(attemptId, incomingStatus) {
    assertNormalizedStatus(incomingStatus);
    const attemptRef = attempts.doc(attemptId);
    let attempt = await getAttempt(attemptId);

    if (attempt.status === PAYMENT_STATUS.REVERSED ||
        (attempt.status === PAYMENT_STATUS.SUCCEEDED &&
          incomingStatus !== PAYMENT_STATUS.REVERSED)) {
      await syncFundingOutcome(attemptId, attempt);
      return attemptResult(attemptId, attempt);
    }

    if (incomingStatus === PAYMENT_STATUS.SUCCEEDED) {
      const ledgerResult = await ledger.processOperation({
        userId: attempt.userId,
        idempotencyKey: `payment_${hash({ attemptId, action: "complete" }).slice(0, 40)}`,
        direction: attempt.kind === "funding" ? "credit" : "debit",
        amountKobo: attempt.amountKobo,
        source: attempt.kind === "funding"
          ? attempt.ledgerSource || "funding"
          : "healthcare_payment",
        providerReference: attempt.providerReference,
      });
      const succeeded = ledgerResult.status === "completed";
      await attemptRef.update({
        status: succeeded ? PAYMENT_STATUS.SUCCEEDED : PAYMENT_STATUS.FAILED,
        ledgerOperationId: ledgerResult.operationId,
        failureCode: ledgerResult.failureCode,
        verifiedAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      });
    } else if (incomingStatus === PAYMENT_STATUS.REVERSED) {
      if (!attempt.ledgerOperationId || attempt.status !== PAYMENT_STATUS.SUCCEEDED) {
        throw new PaymentServiceError(
          "invalid-transition",
          "Only a succeeded payment attempt can be reversed.",
        );
      }
      const reversal = await ledger.reverseOperation({
        userId: attempt.userId,
        originalOperationId: attempt.ledgerOperationId,
        idempotencyKey: `payment_${hash({ attemptId, action: "reverse" }).slice(0, 40)}`,
      });
      await attemptRef.update({
        status: PAYMENT_STATUS.REVERSED,
        reversalOperationId: reversal.operationId,
        failureCode: null,
        verifiedAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      });
    } else {
      await updateAttemptStatus(attemptId, incomingStatus, {
        failureCode: incomingStatus === PAYMENT_STATUS.FAILED
          ? "provider-failed"
          : incomingStatus === PAYMENT_STATUS.TIMED_OUT
            ? "provider-timeout"
            : null,
        verifiedAt: Timestamp.now(),
      });
    }

    attempt = (await attemptRef.get()).data();
    await syncFundingOutcome(attemptId, attempt);
    return attemptResult(attemptId, attempt);
  }

  async function updateAttemptStatus(attemptId, status, extra = {}) {
    assertNormalizedStatus(status);
    await attempts.doc(attemptId).update({
      status,
      ...extra,
      updatedAt: Timestamp.now(),
    });
  }

  async function syncFundingOutcome(attemptId, attempt) {
    if (!isWalletFunding(attempt)) return;
    const now = Timestamp.now();
    const fundingRef = fundingTransactions.doc(attemptId);
    const terminalEvent = fundingTerminalEvent(attempt.status);
    const activityRef = terminalEvent?.activity
      ? activities.doc(`activity_${hash({ attemptId, event: terminalEvent.type }).slice(0, 48)}`)
      : null;
    const notificationRef = terminalEvent
      ? notificationEvents.doc(
        `notification_${hash({ attemptId, event: terminalEvent.type }).slice(0, 48)}`,
      )
      : null;

    await db.runTransaction(async (transaction) => {
      const references = [fundingRef];
      if (activityRef) references.push(activityRef);
      if (notificationRef) references.push(notificationRef);
      const snapshots = await Promise.all(
        references.map((reference) => transaction.get(reference)),
      );
      transaction.set(
        fundingRef,
        fundingTransactionDocument(attemptId, attempt),
      );
      let snapshotIndex = 1;
      if (activityRef) {
        const activitySnapshot = snapshots[snapshotIndex++];
        if (!activitySnapshot.exists) {
          transaction.create(activityRef, {
            userId: attempt.userId,
            activityType: terminalEvent.type,
            metadata: {
              amountKobo: attempt.amountKobo,
              currency: attempt.currency,
              receiptNumber: attempt.status === PAYMENT_STATUS.SUCCEEDED
                ? receiptNumberFor(attemptId)
                : null,
            },
            relatedEntityType: "funding_transaction",
            relatedEntityId: attemptId,
            status: fundingTransactionStatus(attempt.status),
            moneyMovement: attempt.status === PAYMENT_STATUS.SUCCEEDED,
            amountKobo: attempt.amountKobo,
            currency: attempt.currency,
            createdAt: now,
          });
        }
      }
      if (notificationRef) {
        const notificationSnapshot = snapshots[snapshotIndex];
        if (!notificationSnapshot.exists) {
          transaction.create(notificationRef, {
            userId: attempt.userId,
            type: terminalEvent.type,
            title: terminalEvent.title,
            body: terminalEvent.body,
            status: "queued",
            relatedEntityType: "funding_transaction",
            relatedEntityId: attemptId,
            createdAt: now,
          });
        }
      }
    });
  }

  async function getAttempt(attemptId, expectedKind) {
    requireSafeId(attemptId, "attemptId");
    const snapshot = await attempts.doc(attemptId).get();
    if (!snapshot.exists) {
      throw new PaymentServiceError("not-found", "Payment attempt was not found.");
    }
    const attempt = snapshot.data();
    if (!ATTEMPT_KINDS.has(attempt.kind) ||
        (expectedKind && attempt.kind !== expectedKind)) {
      throw new PaymentServiceError("invalid-kind", "Payment attempt type is invalid.");
    }
    return attempt;
  }

  return {
    initializeFunding,
    verifyFunding,
    resolveBeneficiary,
    initiateHealthcarePayment,
    verifyTransaction,
    queryStatus,
    processWebhook,
  };
}

function normalizeAttempt(kind, input) {
  if (!ATTEMPT_KINDS.has(kind) || !input || typeof input !== "object") {
    throw new PaymentServiceError("invalid-argument", "Payment request is invalid.");
  }
  requireSafeId(input.userId, "userId");
  if (typeof input.idempotencyKey !== "string" ||
      !REQUEST_KEY.test(input.idempotencyKey)) {
    throw new PaymentServiceError("invalid-argument", "Idempotency key is invalid.");
  }
  if (!Number.isSafeInteger(input.amountKobo) || input.amountKobo <= 0 ||
      input.amountKobo > MAX_AMOUNT_KOBO) {
    throw new PaymentServiceError("invalid-amount", "Amount must be positive integer kobo.");
  }
  const beneficiaryId = kind === "healthcare_payment" ? input.beneficiaryId : null;
  if (beneficiaryId !== null) requireSafeId(beneficiaryId, "beneficiaryId");
  const ledgerSource = kind === "funding"
    ? input.ledgerSource || "funding"
    : "healthcare_payment";
  if (kind === "funding" &&
      !["funding", "savings_contribution"].includes(ledgerSource)) {
    throw new PaymentServiceError("invalid-argument", "Ledger source is invalid.");
  }
  if (kind === "funding" && ledgerSource === "funding" &&
      !isValidFundingAmount(input.amountKobo)) {
    throw new PaymentServiceError(
      "invalid-amount",
      `Funding amount must be between ${MIN_FUNDING_AMOUNT_KOBO} and ` +
        `${MAX_FUNDING_AMOUNT_KOBO} kobo.`,
    );
  }
  return {
    userId: input.userId,
    idempotencyKey: input.idempotencyKey,
    kind,
    amountKobo: input.amountKobo,
    currency: CURRENCY,
    beneficiaryId,
    ledgerSource,
  };
}

function normalizeProviderResult(result) {
  if (!result || typeof result !== "object") {
    throw new PaymentServiceError(
      "invalid-provider-response",
      "Payment provider response is invalid.",
    );
  }
  assertNormalizedStatus(result.status);
  const providerReference = result.providerReference ?? null;
  if (providerReference !== null) {
    requireBoundedString(providerReference, "providerReference", 128);
  }
  return { status: result.status, providerReference };
}

function validateEvent(event) {
  if (!event || typeof event !== "object") {
    throw new PaymentServiceError("invalid-webhook", "Webhook event is invalid.");
  }
  requireBoundedString(event.eventId, "eventId", 200);
  requireSafeId(event.attemptId, "attemptId");
  requireBoundedString(event.providerReference, "providerReference", 128);
  assertNormalizedStatus(event.status);
}

function attemptIdFor(input) {
  return `pay_${hash({
    userId: input.userId,
    idempotencyKey: input.idempotencyKey,
    kind: input.kind,
  }).slice(0, 48)}`;
}

function attemptResult(attemptId, attempt) {
  return {
    attemptId,
    kind: attempt.kind,
    status: attempt.status,
    provider: attempt.provider,
    providerReference: attempt.providerReference ?? null,
    ledgerOperationId: attempt.ledgerOperationId ?? null,
    failureCode: attempt.failureCode ?? null,
  };
}

function isWalletFunding(attempt) {
  return attempt?.kind === "funding" && attempt.ledgerSource === "funding";
}

function fundingTransactionDocument(attemptId, attempt) {
  const completed = attempt.status === PAYMENT_STATUS.SUCCEEDED;
  return {
    schemaVersion: 1,
    userId: attempt.userId,
    paymentAttemptId: attemptId,
    amountKobo: attempt.amountKobo,
    currency: attempt.currency,
    status: fundingTransactionStatus(attempt.status),
    provider: attempt.provider,
    providerReference: attempt.providerReference ?? null,
    ledgerOperationId: attempt.ledgerOperationId ?? null,
    failureCode: attempt.failureCode ?? null,
    transactionReference: attemptId,
    receiptNumber: completed ? receiptNumberFor(attemptId) : null,
    description: "HealthPocket wallet funding",
    channel: attempt.provider === "mock" ? "mock" : "provider",
    completedAt: completed ? attempt.verifiedAt ?? attempt.updatedAt : null,
    createdAt: attempt.createdAt,
    updatedAt: attempt.updatedAt,
  };
}

function fundingTransactionStatus(paymentStatus) {
  return {
    [PAYMENT_STATUS.CREATED]: "created",
    [PAYMENT_STATUS.PENDING]: "pending",
    [PAYMENT_STATUS.SUCCEEDED]: "completed",
    [PAYMENT_STATUS.FAILED]: "failed",
    [PAYMENT_STATUS.TIMED_OUT]: "failed",
    [PAYMENT_STATUS.CANCELLED]: "cancelled",
    [PAYMENT_STATUS.REVERSED]: "reversed",
  }[paymentStatus];
}

function fundingTerminalEvent(paymentStatus) {
  if (paymentStatus === PAYMENT_STATUS.SUCCEEDED) {
    return {
      type: "funding_completed",
      title: "Money added",
      body: "Your HealthPocket balance has been updated.",
      activity: true,
    };
  }
  if ([PAYMENT_STATUS.FAILED, PAYMENT_STATUS.TIMED_OUT].includes(paymentStatus)) {
    return {
      type: "funding_failed",
      title: "Add Money unsuccessful",
      body: "No money was added. You can safely try again.",
      activity: true,
    };
  }
  if (paymentStatus === PAYMENT_STATUS.CANCELLED) {
    return {
      type: "funding_cancelled",
      title: "Add Money cancelled",
      body: "The funding attempt was cancelled and no money was added.",
      activity: true,
    };
  }
  return null;
}

function receiptNumberFor(attemptId) {
  return `HPF-${hash({ attemptId }).slice(0, 12).toUpperCase()}`;
}

function assertSameAttempt(attempt, fingerprint) {
  if (!attempt || attempt.requestFingerprint !== fingerprint) {
    throw new PaymentServiceError(
      "idempotency-conflict",
      "The idempotency key was already used for another payment request.",
    );
  }
}

function requireProviderReference(attempt) {
  if (!attempt.providerReference) {
    throw new PaymentServiceError(
      "missing-provider-reference",
      "Payment attempt does not have a provider reference.",
    );
  }
  return attempt.providerReference;
}

function requireSafeId(value, name) {
  if (typeof value !== "string" || !SAFE_ID.test(value)) {
    throw new PaymentServiceError("invalid-argument", `${name} is invalid.`);
  }
}

function requireBoundedString(value, name, maximum) {
  if (typeof value !== "string" || value.length < 1 || value.length > maximum) {
    throw new PaymentServiceError("invalid-argument", `${name} is invalid.`);
  }
}

function hash(value) {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function log(logger, operation, outcome, kind) {
  logger.info("healthpocket_backend", {
    component: "payments",
    operation,
    outcome,
    ...(kind ? { kind } : {}),
  });
}

module.exports = { buildPaymentService, PaymentServiceError };
