"use strict";

const { createHash } = require("node:crypto");
const { FieldValue, Timestamp } = require("firebase-admin/firestore");

const CURRENCY = "NGN";
const MAX_AMOUNT_KOBO = 100000000000;
const SAFE_ID = /^[A-Za-z0-9_-]{1,256}$/;
const REQUEST_KEY = /^[A-Za-z0-9_-]{16,80}$/;
const DIRECTIONS = new Set(["credit", "debit"]);
const SOURCES = new Set([
  "funding",
  "savings_contribution",
  "family_contribution",
  "healthcare_payment",
  "reversal",
  "adjustment",
  "mock",
]);

class LedgerError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "LedgerError";
    this.code = code;
  }
}

function buildLedgerService({ db, logger = console }) {
  if (!db || typeof db.runTransaction !== "function") {
    throw new TypeError("A Firestore Admin database is required.");
  }

  const wallets = db.collection("wallets");
  const operations = db.collection("financial_operations");
  const entries = db.collection("ledger_entries");

  async function ensureWallet(userId) {
    requireSafeId(userId, "userId");
    const walletRef = wallets.doc(userId);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(walletRef);
      if (snapshot.exists) {
        validateWallet(snapshot.data(), userId);
        return;
      }
      const now = Timestamp.now();
      transaction.create(walletRef, {
        schemaVersion: 1,
        userId,
        currency: CURRENCY,
        availableBalanceKobo: 0,
        status: "active",
        version: 0,
        createdAt: now,
        updatedAt: now,
      });
    });
    log(logger, "ensure_wallet", "success");
    return walletRef.id;
  }

  async function createPendingOperation(input) {
    const normalized = normalizeOperation(input);
    const operationId = operationIdFor(
      normalized.userId,
      normalized.idempotencyKey,
    );
    const operationRef = operations.doc(operationId);
    const walletRef = wallets.doc(normalized.userId);
    const fingerprint = fingerprintFor(normalized);

    const result = await db.runTransaction(async (transaction) => {
      const [existing, wallet] = await Promise.all([
        transaction.get(operationRef),
        transaction.get(walletRef),
      ]);
      if (!wallet.exists) {
        throw new LedgerError("wallet-not-found", "Wallet is not provisioned.");
      }
      validateWallet(wallet.data(), normalized.userId);
      if (wallet.data().status !== "active") {
        throw new LedgerError("wallet-unavailable", "Wallet is not active.");
      }
      if (existing.exists) {
        assertSameRequest(existing.data(), fingerprint);
        return operationResult(operationId, existing.data());
      }

      const now = Timestamp.now();
      const document = {
        schemaVersion: 1,
        userId: normalized.userId,
        walletId: normalized.userId,
        direction: normalized.direction,
        amountKobo: normalized.amountKobo,
        currency: CURRENCY,
        source: normalized.source,
        status: "pending",
        requestFingerprint: fingerprint,
        providerReference: normalized.providerReference,
        familyPocketId: normalized.familyPocketId,
        createdAt: now,
        updatedAt: now,
      };
      transaction.create(operationRef, document);
      return operationResult(operationId, document);
    });
    log(logger, "create_operation", result.status, normalized.source);
    return result;
  }

  async function finalizeOperation({ operationId, outcome, failureCode = null }) {
    requireSafeId(operationId, "operationId");
    if (!["completed", "failed", "cancelled"].includes(outcome)) {
      throw new LedgerError("invalid-argument", "Invalid final outcome.");
    }
    if (failureCode !== null) requireBoundedString(failureCode, "failureCode", 64);

    const operationRef = operations.doc(operationId);
    const result = await db.runTransaction(async (transaction) => {
      const operationSnapshot = await transaction.get(operationRef);
      if (!operationSnapshot.exists) {
        throw new LedgerError("operation-not-found", "Operation was not found.");
      }
      const operation = operationSnapshot.data();
      if (operation.status !== "pending") {
        return operationResult(operationId, operation);
      }

      if (outcome !== "completed") {
        const updated = {
          ...operation,
          status: outcome,
          failureCode: outcome === "failed" ? failureCode || "operation-failed" : null,
          updatedAt: Timestamp.now(),
        };
        transaction.update(operationRef, {
          status: updated.status,
          failureCode: updated.failureCode,
          updatedAt: updated.updatedAt,
        });
        return operationResult(operationId, updated);
      }

      const walletRef = wallets.doc(operation.walletId);
      const walletSnapshot = await transaction.get(walletRef);
      if (!walletSnapshot.exists) {
        throw new LedgerError("wallet-not-found", "Wallet is not provisioned.");
      }
      const wallet = walletSnapshot.data();
      validateWallet(wallet, operation.userId);
      if (wallet.status !== "active") {
        throw new LedgerError("wallet-unavailable", "Wallet is not active.");
      }

      const delta = operation.direction === "credit"
        ? operation.amountKobo
        : -operation.amountKobo;
      const nextBalance = wallet.availableBalanceKobo + delta;
      if (nextBalance < 0) {
        const now = Timestamp.now();
        transaction.update(operationRef, {
          status: "failed",
          failureCode: "insufficient-balance",
          updatedAt: now,
        });
        return {
          ...operationResult(operationId, operation),
          status: "failed",
          failureCode: "insufficient-balance",
        };
      }

      const ledgerEntryId = entryIdFor(operationId);
      const ledgerRef = entries.doc(ledgerEntryId);
      const ledgerSnapshot = await transaction.get(ledgerRef);
      if (ledgerSnapshot.exists) {
        throw new LedgerError("integrity-error", "Ledger entry already exists.");
      }
      const now = Timestamp.now();
      transaction.create(ledgerRef, {
        schemaVersion: 1,
        operationId,
        userId: operation.userId,
        walletId: operation.walletId,
        direction: operation.direction,
        amountKobo: operation.amountKobo,
        currency: CURRENCY,
        status: "completed",
        source: operation.source,
        providerReference: operation.providerReference,
        familyPocketId: operation.familyPocketId,
        reversesLedgerEntryId: null,
        createdAt: now,
      });
      transaction.update(walletRef, {
        availableBalanceKobo: nextBalance,
        version: FieldValue.increment(1),
        updatedAt: now,
      });
      transaction.update(operationRef, {
        status: "completed",
        ledgerEntryId,
        failureCode: null,
        updatedAt: now,
      });
      return {
        ...operationResult(operationId, operation),
        status: "completed",
        ledgerEntryId,
      };
    });
    log(logger, "finalize_operation", result.status, result.source);
    return result;
  }

  async function processOperation(input) {
    const pending = await createPendingOperation(input);
    if (pending.status !== "pending") return pending;
    return finalizeOperation({ operationId: pending.operationId, outcome: "completed" });
  }

  async function reverseOperation({ userId, originalOperationId, idempotencyKey }) {
    requireSafeId(userId, "userId");
    requireSafeId(originalOperationId, "originalOperationId");
    requireRequestKey(idempotencyKey);
    const reversalId = operationIdFor(userId, idempotencyKey);
    const reversalRef = operations.doc(reversalId);
    const originalRef = operations.doc(originalOperationId);
    const walletRef = wallets.doc(userId);
    const reversalFingerprint = hash({ userId, originalOperationId, idempotencyKey });

    const result = await db.runTransaction(async (transaction) => {
      const [originalSnapshot, reversalSnapshot, walletSnapshot] = await Promise.all([
        transaction.get(originalRef),
        transaction.get(reversalRef),
        transaction.get(walletRef),
      ]);
      if (!originalSnapshot.exists) {
        throw new LedgerError("operation-not-found", "Original operation was not found.");
      }
      const original = originalSnapshot.data();
      if (original.userId !== userId) {
        throw new LedgerError("permission-denied", "Operation owner mismatch.");
      }
      if (original.status === "reversed") {
        if (original.reversalOperationId !== reversalId) {
          throw new LedgerError("already-reversed", "Operation was already reversed.");
        }
        if (!reversalSnapshot.exists) {
          throw new LedgerError("integrity-error", "Reversal record is missing.");
        }
        return operationResult(reversalId, reversalSnapshot.data());
      }
      if (original.status !== "completed" || !original.ledgerEntryId) {
        throw new LedgerError("invalid-state", "Only completed operations can be reversed.");
      }
      if (reversalSnapshot.exists) {
        assertSameRequest(reversalSnapshot.data(), reversalFingerprint);
        return operationResult(reversalId, reversalSnapshot.data());
      }
      if (!walletSnapshot.exists) {
        throw new LedgerError("wallet-not-found", "Wallet is not provisioned.");
      }
      const wallet = walletSnapshot.data();
      validateWallet(wallet, userId);
      const direction = original.direction === "credit" ? "debit" : "credit";
      const delta = direction === "credit" ? original.amountKobo : -original.amountKobo;
      const nextBalance = wallet.availableBalanceKobo + delta;
      if (nextBalance < 0) {
        throw new LedgerError(
          "insufficient-balance",
          "The reversal would make the wallet negative.",
        );
      }

      const ledgerEntryId = entryIdFor(reversalId);
      const now = Timestamp.now();
      transaction.create(entries.doc(ledgerEntryId), {
        schemaVersion: 1,
        operationId: reversalId,
        userId,
        walletId: userId,
        direction,
        amountKobo: original.amountKobo,
        currency: CURRENCY,
        status: "completed",
        source: "reversal",
        providerReference: null,
        familyPocketId: original.familyPocketId || null,
        reversesLedgerEntryId: original.ledgerEntryId,
        createdAt: now,
      });
      transaction.create(reversalRef, {
        schemaVersion: 1,
        userId,
        walletId: userId,
        direction,
        amountKobo: original.amountKobo,
        currency: CURRENCY,
        source: "reversal",
        status: "completed",
        requestFingerprint: reversalFingerprint,
        providerReference: null,
        familyPocketId: original.familyPocketId || null,
        ledgerEntryId,
        failureCode: null,
        reversesOperationId: originalOperationId,
        createdAt: now,
        updatedAt: now,
      });
      transaction.update(walletRef, {
        availableBalanceKobo: nextBalance,
        version: FieldValue.increment(1),
        updatedAt: now,
      });
      transaction.update(originalRef, {
        status: "reversed",
        reversalOperationId: reversalId,
        updatedAt: now,
      });
      return operationResult(reversalId, {
        userId,
        source: "reversal",
        status: "completed",
        ledgerEntryId,
      });
    });
    log(logger, "reverse_operation", result.status, "reversal");
    return result;
  }

  async function reconcileWallet(userId) {
    requireSafeId(userId, "userId");
    const [walletSnapshot, ledgerSnapshot] = await Promise.all([
      wallets.doc(userId).get(),
      entries.where("userId", "==", userId).where("status", "==", "completed").get(),
    ]);
    if (!walletSnapshot.exists) {
      throw new LedgerError("wallet-not-found", "Wallet is not provisioned.");
    }
    const expectedBalanceKobo = ledgerSnapshot.docs.reduce((total, document) => {
      const entry = document.data();
      return total + (entry.direction === "credit" ? entry.amountKobo : -entry.amountKobo);
    }, 0);
    const actualBalanceKobo = walletSnapshot.data().availableBalanceKobo;
    const result = {
      matches: expectedBalanceKobo === actualBalanceKobo,
      expectedBalanceKobo,
      actualBalanceKobo,
      entryCount: ledgerSnapshot.size,
    };
    log(logger, "reconcile_wallet", result.matches ? "success" : "mismatch");
    return result;
  }

  return {
    ensureWallet,
    createPendingOperation,
    finalizeOperation,
    processOperation,
    reverseOperation,
    reconcileWallet,
  };
}

function normalizeOperation(input) {
  if (!input || typeof input !== "object") {
    throw new LedgerError("invalid-argument", "Operation input is required.");
  }
  requireSafeId(input.userId, "userId");
  requireRequestKey(input.idempotencyKey);
  if (!DIRECTIONS.has(input.direction)) {
    throw new LedgerError("invalid-argument", "Direction must be credit or debit.");
  }
  if (!Number.isSafeInteger(input.amountKobo) || input.amountKobo <= 0 ||
      input.amountKobo > MAX_AMOUNT_KOBO) {
    throw new LedgerError("invalid-amount", "Amount must be positive integer kobo.");
  }
  if (!SOURCES.has(input.source)) {
    throw new LedgerError("invalid-argument", "Unknown financial source.");
  }
  const providerReference = optionalBoundedString(
    input.providerReference,
    "providerReference",
    128,
  );
  const familyPocketId = optionalSafeId(input.familyPocketId, "familyPocketId");
  return {
    userId: input.userId,
    idempotencyKey: input.idempotencyKey,
    direction: input.direction,
    amountKobo: input.amountKobo,
    source: input.source,
    providerReference,
    familyPocketId,
  };
}

function validateWallet(wallet, userId) {
  if (!wallet || wallet.userId !== userId || wallet.currency !== CURRENCY ||
      !Number.isSafeInteger(wallet.availableBalanceKobo) ||
      wallet.availableBalanceKobo < 0 || !Number.isSafeInteger(wallet.version)) {
    throw new LedgerError("integrity-error", "Wallet data is invalid.");
  }
}

function operationResult(operationId, data) {
  return {
    operationId,
    status: data.status,
    source: data.source,
    ledgerEntryId: data.ledgerEntryId || null,
    failureCode: data.failureCode || null,
  };
}

function assertSameRequest(existing, fingerprint) {
  if (!existing || existing.requestFingerprint !== fingerprint) {
    throw new LedgerError(
      "idempotency-conflict",
      "The idempotency key was already used for another request.",
    );
  }
}

function operationIdFor(userId, idempotencyKey) {
  return `op_${hash({ userId, idempotencyKey }).slice(0, 48)}`;
}

function entryIdFor(operationId) {
  return `entry_${operationId.slice(3)}`;
}

function fingerprintFor(input) {
  return hash({
    userId: input.userId,
    idempotencyKey: input.idempotencyKey,
    direction: input.direction,
    amountKobo: input.amountKobo,
    currency: CURRENCY,
    source: input.source,
    providerReference: input.providerReference,
    familyPocketId: input.familyPocketId,
  });
}

function hash(value) {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function requireSafeId(value, name) {
  if (typeof value !== "string" || !SAFE_ID.test(value)) {
    throw new LedgerError("invalid-argument", `${name} is invalid.`);
  }
}

function requireRequestKey(value) {
  if (typeof value !== "string" || !REQUEST_KEY.test(value)) {
    throw new LedgerError("invalid-argument", "Idempotency key is invalid.");
  }
}

function requireBoundedString(value, name, maximum) {
  if (typeof value !== "string" || value.length < 1 || value.length > maximum) {
    throw new LedgerError("invalid-argument", `${name} is invalid.`);
  }
}

function optionalBoundedString(value, name, maximum) {
  if (value === undefined || value === null) return null;
  requireBoundedString(value, name, maximum);
  return value;
}

function optionalSafeId(value, name) {
  if (value === undefined || value === null) return null;
  requireSafeId(value, name);
  return value;
}

function log(logger, operation, outcome, source) {
  logger.info("healthpocket_backend", {
    component: "ledger",
    operation,
    outcome,
    ...(source ? { source } : {}),
  });
}

module.exports = { buildLedgerService, LedgerError };
