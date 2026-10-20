"use strict";

const { createHash } = require("node:crypto");
const { Timestamp } = require("firebase-admin/firestore");
const {
  HealthcareVerificationError,
  VERIFICATION_STATUS,
  assertVerificationStatus,
} = require("./healthcare-verification");
const {
  healthcareReceiptDocument,
  receiptNumberForHealthcare,
  assertReceiptCompatible,
} = require("../receipts/receipt-service");
const {
  notificationDocument: canonicalNotificationDocument,
} = require("../notifications/notification-model");
const { TRANSACTION_POLICY } = require("../config/transaction-policy");

const CURRENCY = "NGN";
const MIN_AMOUNT_KOBO = TRANSACTION_POLICY.healthcarePayment.minimumKobo;
const MAX_AMOUNT_KOBO = TRANSACTION_POLICY.healthcarePayment.maximumSingleKobo;
const SAFE_ID = /^[A-Za-z0-9_-]{1,256}$/;
const REQUEST_KEY = /^[A-Za-z0-9_-]{16,80}$/;
const FLOW_TYPES = new Set(["partner", "non_partner"]);

class HealthcarePaymentError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "HealthcarePaymentError";
    this.code = code;
  }
}

function buildHealthcarePaymentService({
  db,
  payments,
  accountResolver,
  healthcareVerifier,
  logger = console,
}) {
  if (!db || typeof db.runTransaction !== "function") {
    throw new TypeError("A Firestore Admin database is required.");
  }
  if (!payments || typeof payments.initiateHealthcarePayment !== "function" ||
      typeof payments.verifyTransaction !== "function") {
    throw new TypeError("The trusted payment service is required.");
  }
  if (!accountResolver || typeof accountResolver.resolveAccount !== "function") {
    throw new TypeError("An account-resolution adapter is required.");
  }
  if (!healthcareVerifier ||
      typeof healthcareVerifier.verifyProvider !== "function") {
    throw new TypeError("A healthcare-eligibility adapter is required.");
  }

  const transactions = db.collection("healthcare_payments");
  const providers = db.collection("healthcare_providers");
  const wallets = db.collection("wallets");
  const operations = db.collection("financial_operations");
  const receipts = db.collection("receipts");
  const activities = db.collection("activities");
  const notifications = db.collection("notification_events");

  async function initiatePartnerPayment(input) {
    const request = normalizeRequest(input, "partner");
    const created = await createTransaction(request);
    if (["completed", "failed", "cancelled", "reversed"].includes(
      created.document.status,
    )) {
      return result(created.paymentId, created.document);
    }
    return initiateTrustedPayment(created.paymentId, created.document);
  }

  async function initiateNonPartnerPayment(input) {
    const request = normalizeRequest(input, "non_partner");
    request.bankAccount = normalizeBankAccount(input?.bankAccount);
    request.requestFingerprint = fingerprint(request);
    const created = await createTransaction(request);
    if (["completed", "failed", "cancelled", "reversed"].includes(
      created.document.status,
    )) {
      return result(created.paymentId, created.document);
    }

    let resolution;
    try {
      resolution = await accountResolver.resolveAccount(request.bankAccount);
    } catch (error) {
      if (isVerificationTimeout(error)) {
        return rejectVerification(
          created.paymentId,
          "unavailable",
          accountResolver.name,
          "account-resolution-unavailable",
        );
      }
      throw error;
    }
    assertVerificationStatus(resolution?.status);
    if (resolution.status !== VERIFICATION_STATUS.VERIFIED ||
        !resolution.beneficiary) {
      return rejectVerification(
        created.paymentId,
        resolution.status,
        accountResolver.name,
        "account-resolution-failed",
      );
    }
    const beneficiary = normalizeBeneficiary(resolution.beneficiary);

    let verification;
    try {
      verification = await healthcareVerifier.verifyProvider({
        providerId: request.providerId,
        beneficiary,
      });
    } catch (error) {
      if (isVerificationTimeout(error)) {
        return rejectVerification(
          created.paymentId,
          "unavailable",
          healthcareVerifier.name,
          "healthcare-verification-unavailable",
          beneficiary,
        );
      }
      throw error;
    }
    assertVerificationStatus(verification?.status);
    if (verification.productionMccVerified === true) {
      throw new HealthcarePaymentError(
        "invalid-provider-response",
        "The MVP mock adapter cannot claim production MCC verification.",
      );
    }
    if (verification.status !== VERIFICATION_STATUS.VERIFIED) {
      return rejectVerification(
        created.paymentId,
        verification.status,
        healthcareVerifier.name,
        verification.reasonCode || "healthcare-verification-failed",
        beneficiary,
      );
    }
    const verificationReference = boundedNullableString(
      verification.verificationReference,
      "verificationReference",
      128,
    );
    await transactions.doc(created.paymentId).update({
      beneficiary,
      verificationStatus: "verified",
      verificationSource: healthcareVerifier.name,
      verificationReference,
      failureCode: null,
      updatedAt: Timestamp.now(),
    });
    return initiateTrustedPayment(
      created.paymentId,
      (await transactions.doc(created.paymentId).get()).data(),
    );
  }

  async function createTransaction(request) {
    const paymentId = paymentIdFor(request.userId, request.idempotencyKey);
    const reference = transactions.doc(paymentId);
    const document = await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(reference);
      if (existing.exists) {
        assertSameRequest(existing.data(), request.requestFingerprint);
        return existing.data();
      }
      const providerRef = providers.doc(request.providerId);
      const walletRef = wallets.doc(request.userId);
      const [providerSnapshot, walletSnapshot] = await Promise.all([
        transaction.get(providerRef),
        transaction.get(walletRef),
      ]);
      const provider = requireEligibleProvider(
        providerSnapshot,
        request.providerId,
        request.flowType,
      );
      requireAvailableBalance(walletSnapshot, request.userId, request.amountKobo);
      const now = Timestamp.now();
      const value = {
        schemaVersion: 1,
        userId: request.userId,
        paymentAttemptId: null,
        flowType: request.flowType,
        providerId: request.providerId,
        providerName: provider.name,
        providerCategory: provider.category,
        providerCity: provider.city,
        providerState: provider.state,
        amountKobo: request.amountKobo,
        currency: CURRENCY,
        status: "created",
        verificationStatus: request.flowType === "partner"
          ? "not_required"
          : "pending",
        verificationSource: null,
        verificationReference: null,
        failureCode: null,
        paymentProvider: "mock",
        providerReference: null,
        ledgerOperationId: null,
        ledgerEntryId: null,
        transactionReference: paymentId,
        receiptNumber: null,
        description: `Healthcare payment to ${provider.name}`,
        channel: "mock",
        beneficiary: null,
        requestFingerprint: request.requestFingerprint,
        createdAt: now,
        updatedAt: now,
        completedAt: null,
      };
      transaction.create(reference, value);
      return value;
    });
    return { paymentId, document };
  }

  async function initiateTrustedPayment(paymentId, payment) {
    if (payment.flowType === "non_partner" &&
        payment.verificationStatus !== "verified") {
      throw new HealthcarePaymentError(
        "verification-required",
        "Non-partner healthcare verification is required before payment.",
      );
    }
    const beneficiaryId = payment.flowType === "partner"
      ? payment.providerId
      : payment.beneficiary.beneficiaryReference;
    const attempt = await payments.initiateHealthcarePayment({
      userId: payment.userId,
      idempotencyKey: `healthcare_${hash({ paymentId }).slice(0, 32)}`,
      amountKobo: payment.amountKobo,
      beneficiaryId,
    });
    const projection = await syncOutcome(paymentId, attempt);
    log(logger, "initiate", projection.status, payment.flowType);
    return result(paymentId, projection);
  }

  async function verifyPayment({ paymentId, userId }) {
    requireSafeId(paymentId, "paymentId");
    requireSafeId(userId, "userId");
    const snapshot = await transactions.doc(paymentId).get();
    if (!snapshot.exists) throw notFound();
    const payment = snapshot.data();
    if (payment.userId !== userId) {
      throw new HealthcarePaymentError(
        "permission-denied",
        "Healthcare payment owner mismatch.",
      );
    }
    if (payment.status === "completed" || payment.status === "reversed") {
      return result(paymentId, payment);
    }
    if (!payment.paymentAttemptId) {
      throw new HealthcarePaymentError(
        "invalid-state",
        "Healthcare payment has not been initialized.",
      );
    }
    if (payment.flowType === "non_partner" &&
        payment.verificationStatus !== "verified") {
      throw new HealthcarePaymentError(
        "verification-required",
        "Non-partner healthcare verification is required before payment.",
      );
    }
    const attempt = await payments.verifyTransaction({
      attemptId: payment.paymentAttemptId,
    });
    const projection = await syncOutcome(paymentId, attempt);
    log(logger, "verify", projection.status, payment.flowType);
    return result(paymentId, projection);
  }

  async function syncOutcome(paymentId, attempt) {
    const reference = transactions.doc(paymentId);
    const snapshot = await reference.get();
    if (!snapshot.exists) throw notFound();
    const current = snapshot.data();
    const status = projectionStatus(attempt.status);
    const operationSnapshot = attempt.ledgerOperationId
      ? await operations.doc(attempt.ledgerOperationId).get()
      : null;
    const ledgerEntryId = operationSnapshot?.data()?.ledgerEntryId || null;
    const completed = status === "completed";
    const reversed = status === "reversed";
    const terminal = completed || reversed || status === "failed" ||
      status === "cancelled";
    const eventName = completed
      ? "healthcare_payment_completed"
      : reversed
        ? "healthcare_payment_reversed"
        : status === "cancelled"
          ? "healthcare_payment_cancelled"
          : status === "failed"
            ? "healthcare_payment_failed"
            : null;
    const receiptRef = completed
      ? receipts.doc(receiptNumberForHealthcare(paymentId))
      : null;
    const activityRef = terminal
      ? activities.doc(`activity_${hash({ paymentId, eventName }).slice(0, 48)}`)
      : null;
    const notificationRef = terminal
      ? notifications.doc(
        `notification_${hash({ paymentId, eventName }).slice(0, 48)}`,
      )
      : null;
    const references = [reference];
    if (receiptRef) references.push(receiptRef);
    if (activityRef) references.push(activityRef);
    if (notificationRef) references.push(notificationRef);
    const now = Timestamp.now();
    await db.runTransaction(async (transaction) => {
      const snapshots = await Promise.all(
        references.map((item) => transaction.get(item)),
      );
      const snapshotsByPath = new Map(
        references.map((item, index) => [item.path, snapshots[index]]),
      );
      const latest = snapshotsByPath.get(reference.path).data();
      const update = {
        paymentAttemptId: attempt.attemptId,
        status,
        paymentProvider: attempt.provider,
        providerReference: attempt.providerReference,
        ledgerOperationId: attempt.ledgerOperationId,
        ledgerEntryId,
        failureCode: attempt.failureCode,
        receiptNumber: completed
          ? latest.receiptNumber || receiptNumberForHealthcare(paymentId)
          : latest.receiptNumber,
        completedAt: completed ? latest.completedAt || now : latest.completedAt,
        updatedAt: now,
      };
      transaction.update(reference, update);
      if (receiptRef) {
        const receiptDocument = healthcareReceiptDocument(
          paymentId,
          { ...latest, ...update },
        );
        const receiptSnapshot = snapshotsByPath.get(receiptRef.path);
        if (receiptSnapshot.exists) {
          assertReceiptCompatible(receiptSnapshot.data(), receiptDocument);
        } else {
          transaction.create(receiptRef, receiptDocument);
        }
      }
      if (activityRef) {
        if (!snapshotsByPath.get(activityRef.path).exists) {
          transaction.create(activityRef, {
            userId: latest.userId,
            activityType: eventName,
            metadata: {
              amountKobo: latest.amountKobo,
              currency: latest.currency,
              providerId: latest.providerId,
              providerName: latest.providerName,
              flowType: latest.flowType,
              receiptNumber: completed ? receiptNumberForHealthcare(paymentId) : null,
            },
            relatedEntityType: "healthcare_payment",
            relatedEntityId: paymentId,
            status,
            moneyMovement: completed || reversed,
            amountKobo: latest.amountKobo,
            currency: latest.currency,
            createdAt: now,
          });
        }
      }
      if (notificationRef && !snapshotsByPath.get(notificationRef.path).exists) {
        transaction.create(notificationRef, notificationDocument(
          latest,
          paymentId,
          eventName,
          now,
        ));
      }
    });
    return (await reference.get()).data();
  }

  async function rejectVerification(
    paymentId,
    verificationStatus,
    verificationSource,
    failureCode,
    beneficiary = null,
  ) {
    const now = Timestamp.now();
    const reference = transactions.doc(paymentId);
    if (verificationStatus === "unavailable") {
      await reference.update({
        status: "created",
        verificationStatus,
        verificationSource,
        beneficiary,
        failureCode,
        updatedAt: now,
      });
      return result(paymentId, (await reference.get()).data());
    }
    const activityRef = activities.doc(
      `activity_${hash({ paymentId, eventName: "healthcare_payment_failed" }).slice(0, 48)}`,
    );
    const notificationRef = notifications.doc(
      `notification_${hash({ paymentId, eventName: "verification_failed" }).slice(0, 48)}`,
    );
    await db.runTransaction(async (transaction) => {
      const [payment, activity, notification] = await Promise.all([
        transaction.get(reference),
        transaction.get(activityRef),
        transaction.get(notificationRef),
      ]);
      if (!payment.exists) throw notFound();
      transaction.update(reference, {
        status: "failed",
        verificationStatus,
        verificationSource,
        beneficiary,
        failureCode,
        updatedAt: now,
      });
      if (!activity.exists) {
        transaction.create(activityRef, {
          userId: payment.data().userId,
          activityType: "healthcare_payment_failed",
          metadata: {
            amountKobo: payment.data().amountKobo,
            currency: payment.data().currency,
            providerId: payment.data().providerId,
            providerName: payment.data().providerName,
            flowType: payment.data().flowType,
            receiptNumber: null,
          },
          relatedEntityType: "healthcare_payment",
          relatedEntityId: paymentId,
          status: "failed",
          moneyMovement: false,
          amountKobo: payment.data().amountKobo,
          currency: payment.data().currency,
          createdAt: now,
        });
      }
      if (!notification.exists) {
        transaction.create(notificationRef, canonicalNotificationDocument({
          userId: payment.data().userId,
          type: "healthcare_verification_failed",
          category: "payment",
          title: "Provider verification unsuccessful",
          body: "No payment was made. Check the provider details before trying again.",
          relatedEntityType: "healthcare_payment",
          relatedEntityId: paymentId,
          now,
        }));
      }
    });
    return result(paymentId, (await reference.get()).data());
  }

  return {
    initiatePartnerPayment,
    initiateNonPartnerPayment,
    verifyPayment,
  };
}

function normalizeRequest(input, flowType) {
  if (!FLOW_TYPES.has(flowType) || !input || typeof input !== "object") {
    invalid("Healthcare payment request is invalid.");
  }
  requireSafeId(input.userId, "userId");
  requireSafeId(input.providerId, "providerId");
  if (typeof input.idempotencyKey !== "string" ||
      !REQUEST_KEY.test(input.idempotencyKey)) {
    invalid("idempotencyKey is invalid.");
  }
  if (!Number.isSafeInteger(input.amountKobo) || input.amountKobo < MIN_AMOUNT_KOBO ||
      input.amountKobo > MAX_AMOUNT_KOBO) {
    throw new HealthcarePaymentError(
      "invalid-amount",
      "Healthcare payment amount must be positive integer kobo within the MVP limit.",
    );
  }
  const value = {
    userId: input.userId,
    providerId: input.providerId,
    idempotencyKey: input.idempotencyKey,
    amountKobo: input.amountKobo,
    flowType,
    bankAccount: null,
  };
  value.requestFingerprint = fingerprint(value);
  return value;
}

function normalizeBankAccount(value) {
  if (!value || typeof value !== "object" || Array.isArray(value) ||
      typeof value.accountNumber !== "string" ||
      !/^\d{10}$/.test(value.accountNumber) ||
      typeof value.bankCode !== "string" || !/^\d{3}$/.test(value.bankCode)) {
    invalid("Bank account details are invalid.");
  }
  return { accountNumber: value.accountNumber, bankCode: value.bankCode };
}

function normalizeBeneficiary(value) {
  if (!value || typeof value !== "object" || Array.isArray(value) ||
      typeof value.accountNumberLast4 !== "string" ||
      !/^\d{4}$/.test(value.accountNumberLast4) ||
      typeof value.bankCode !== "string" || !/^\d{3}$/.test(value.bankCode)) {
    throw new HealthcarePaymentError(
      "invalid-provider-response",
      "Resolved beneficiary data is invalid.",
    );
  }
  return {
    accountNumberLast4: value.accountNumberLast4,
    bankCode: value.bankCode,
    bankName: boundedString(value.bankName, "bankName", 100),
    accountName: boundedString(value.accountName, "accountName", 160),
    beneficiaryReference: safeId(value.beneficiaryReference, "beneficiaryReference"),
  };
}

function requireEligibleProvider(snapshot, providerId, flowType) {
  if (!snapshot.exists) {
    throw new HealthcarePaymentError("provider-not-found", "Provider was not found.");
  }
  const provider = snapshot.data();
  if (provider.active !== true) {
    throw new HealthcarePaymentError("provider-inactive", "Provider is not active.");
  }
  const expected = flowType === "partner" ? "partner" : "non_partner";
  if (provider.partnerStatus !== expected) {
    throw new HealthcarePaymentError(
      "provider-flow-mismatch",
      "Provider is not eligible for the selected payment flow.",
    );
  }
  for (const field of ["name", "category", "city", "state"]) {
    boundedString(provider[field], `provider.${field}`, field === "name" ? 160 : 100);
  }
  requireSafeId(providerId, "providerId");
  return provider;
}

function requireAvailableBalance(snapshot, userId, amountKobo) {
  if (!snapshot.exists || snapshot.data().userId !== userId) {
    throw new HealthcarePaymentError("wallet-not-found", "Wallet is not provisioned.");
  }
  const wallet = snapshot.data();
  if (wallet.status !== "active") {
    throw new HealthcarePaymentError("wallet-unavailable", "Wallet is not active.");
  }
  if (!Number.isSafeInteger(wallet.availableBalanceKobo) ||
      wallet.availableBalanceKobo < amountKobo) {
    throw new HealthcarePaymentError(
      "insufficient-balance",
      "Available balance is insufficient for this payment.",
    );
  }
}

function projectionStatus(status) {
  const value = {
    created: "created",
    pending: "pending",
    succeeded: "completed",
    failed: "failed",
    timed_out: "pending",
    cancelled: "cancelled",
    reversed: "reversed",
  }[status];
  if (!value) {
    throw new HealthcarePaymentError(
      "invalid-provider-response",
      "Payment status is invalid.",
    );
  }
  return value;
}

function notificationDocument(payment, paymentId, eventName, now) {
  const content = {
    healthcare_payment_completed: {
      title: "Healthcare payment completed",
      body: "Your healthcare payment was completed successfully.",
    },
    healthcare_payment_reversed: {
      title: "Healthcare payment reversed",
      body: "Your healthcare payment was reversed to your HealthPocket balance.",
    },
    healthcare_payment_failed: {
      title: "Healthcare payment unsuccessful",
      body: "No healthcare payment was completed. You can safely review and retry.",
    },
    healthcare_payment_cancelled: {
      title: "Healthcare payment cancelled",
      body: "The healthcare payment was cancelled and no debit was completed.",
    },
  }[eventName];
  return canonicalNotificationDocument({
    userId: payment.userId,
    type: eventName,
    category: "payment",
    title: content.title,
    body: content.body,
    relatedEntityType: "healthcare_payment",
    relatedEntityId: paymentId,
    now,
  });
}

function result(paymentId, payment) {
  return {
    paymentId,
    status: payment.status,
    flowType: payment.flowType,
    paymentAttemptId: payment.paymentAttemptId,
    verificationStatus: payment.verificationStatus,
    receiptNumber: payment.receiptNumber,
    failureCode: payment.failureCode,
  };
}

function paymentIdFor(userId, idempotencyKey) {
  return `health_${hash({ userId, idempotencyKey }).slice(0, 48)}`;
}

function assertSameRequest(payment, requestFingerprint) {
  if (!payment || payment.requestFingerprint !== requestFingerprint) {
    throw new HealthcarePaymentError(
      "idempotency-conflict",
      "The idempotency key was already used for another healthcare payment.",
    );
  }
}

function fingerprint(value) {
  return hash({
    userId: value.userId,
    providerId: value.providerId,
    idempotencyKey: value.idempotencyKey,
    amountKobo: value.amountKobo,
    flowType: value.flowType,
    bankAccount: value.bankAccount,
  });
}

function hash(value) {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function requireSafeId(value, field) {
  safeId(value, field);
}

function safeId(value, field) {
  if (typeof value !== "string" || !SAFE_ID.test(value)) invalid(`${field} is invalid.`);
  return value;
}

function boundedString(value, field, maximum) {
  if (typeof value !== "string" || value.length < 1 || value.length > maximum) {
    invalid(`${field} is invalid.`);
  }
  return value;
}

function boundedNullableString(value, field, maximum) {
  if (value === null || value === undefined) return null;
  return boundedString(value, field, maximum);
}

function isVerificationTimeout(error) {
  return error instanceof HealthcareVerificationError &&
    error.code === "provider-timeout";
}

function invalid(message) {
  throw new HealthcarePaymentError("invalid-argument", message);
}

function notFound() {
  return new HealthcarePaymentError("not-found", "Healthcare payment was not found.");
}

function log(logger, operation, outcome, flowType) {
  logger.info?.("healthcare_payment", {
    component: "healthcare_payments",
    operation,
    outcome,
    flowType,
  });
}

module.exports = {
  HealthcarePaymentError,
  buildHealthcarePaymentService,
};
