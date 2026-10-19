"use strict";

const { createHash } = require("node:crypto");

const SAFE_ID = /^[A-Za-z0-9_-]{1,256}$/;
const RECEIPT_NUMBER = /^HP[FC]-[A-F0-9]{12}$/;
const RECEIPT_TYPES = new Set(["wallet_funding", "healthcare_payment"]);

class ReceiptError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "ReceiptError";
    this.code = code;
  }
}

function buildReceiptService({ db, logger = console }) {
  if (!db || typeof db.collection !== "function") {
    throw new TypeError("A Firestore Admin database is required.");
  }
  const receipts = db.collection("receipts");

  async function getReceipt({ userId, receiptNumber }) {
    requireSafeId(userId, "userId");
    requireReceiptNumber(receiptNumber);
    const snapshot = await receipts.doc(receiptNumber).get();
    if (!snapshot.exists) throw notFound();
    const receipt = snapshot.data();
    if (receipt.userId !== userId) throw notFound();
    assertStoredReceipt(receiptNumber, receipt);
    log(logger, "get_receipt", "success");
    return receiptResult(receipt);
  }

  async function getReceiptForTransaction({ userId, transactionType, transactionId }) {
    requireSafeId(userId, "userId");
    requireSafeId(transactionId, "transactionId");
    if (!RECEIPT_TYPES.has(transactionType)) {
      throw new ReceiptError("invalid-argument", "Transaction type is invalid.");
    }
    const receiptNumber = transactionType === "wallet_funding"
      ? receiptNumberForFunding(transactionId)
      : receiptNumberForHealthcare(transactionId);
    return getReceipt({ userId, receiptNumber });
  }

  async function exportReceipt({ userId, receiptNumber, format = "json" }) {
    const receipt = await getReceipt({ userId, receiptNumber });
    if (!new Set(["json", "text"]).has(format)) {
      throw new ReceiptError("invalid-argument", "Receipt export format is invalid.");
    }
    const baseName = `healthpocket-receipt-${receipt.receiptNumber}`;
    if (format === "text") {
      return {
        fileName: `${baseName}.txt`,
        mimeType: "text/plain; charset=utf-8",
        data: receiptText(receipt),
        shareText: receiptShareText(receipt),
      };
    }
    return {
      fileName: `${baseName}.json`,
      mimeType: "application/json",
      data: JSON.stringify(receipt, null, 2),
      shareText: receiptShareText(receipt),
    };
  }

  return { getReceipt, getReceiptForTransaction, exportReceipt };
}

function fundingReceiptDocument(transactionId, transaction) {
  requireCompletedSource(transactionId, transaction, "wallet_funding");
  const receiptNumber = receiptNumberForFunding(transactionId);
  if (transaction.receiptNumber !== receiptNumber) {
    throw integrityError("Funding receipt number does not match its transaction.");
  }
  const issuedAt = requireTimestamp(transaction.completedAt, "completedAt");
  return finalizeReceipt({
    schemaVersion: 1,
    receiptNumber,
    healthPocketReferenceId: receiptNumber,
    userId: transaction.userId,
    transactionId,
    transactionType: "wallet_funding",
    transactionReference: transaction.transactionReference,
    status: "completed",
    amountKobo: transaction.amountKobo,
    currency: transaction.currency,
    provider: {
      id: transaction.provider,
      name: providerDisplayName(transaction.provider),
    },
    recipient: {
      id: "healthpocket_wallet",
      name: "HealthPocket Wallet",
    },
    paymentMethod: {
      type: "payment_gateway",
      provider: transaction.provider,
      channel: transaction.channel,
      externalReference: transaction.providerReference || null,
    },
    description: transaction.description,
    ledgerOperationId: transaction.ledgerOperationId,
    ledgerEntryId: null,
    issuedAt,
    createdAt: issuedAt,
  });
}

function healthcareReceiptDocument(transactionId, transaction) {
  requireCompletedSource(transactionId, transaction, "healthcare_payment");
  const receiptNumber = receiptNumberForHealthcare(transactionId);
  if (transaction.receiptNumber !== receiptNumber) {
    throw integrityError("Healthcare receipt number does not match its transaction.");
  }
  const issuedAt = requireTimestamp(transaction.completedAt, "completedAt");
  return finalizeReceipt({
    schemaVersion: 1,
    receiptNumber,
    healthPocketReferenceId: receiptNumber,
    userId: transaction.userId,
    transactionId,
    transactionType: "healthcare_payment",
    transactionReference: transaction.transactionReference,
    status: "completed",
    amountKobo: transaction.amountKobo,
    currency: transaction.currency,
    provider: {
      id: transaction.providerId,
      name: transaction.providerName,
      category: transaction.providerCategory,
      city: transaction.providerCity,
      state: transaction.providerState,
    },
    recipient: {
      id: transaction.providerId,
      name: transaction.providerName,
    },
    paymentMethod: {
      type: transaction.flowType === "partner" ? "healthpocket_partner" : "bank_transfer",
      provider: transaction.paymentProvider,
      channel: transaction.channel,
      externalReference: transaction.providerReference || null,
    },
    flowType: transaction.flowType,
    description: transaction.description,
    ledgerOperationId: transaction.ledgerOperationId,
    ledgerEntryId: transaction.ledgerEntryId,
    issuedAt,
    createdAt: issuedAt,
  });
}

function assertReceiptCompatible(existing, expected) {
  assertStoredReceipt(expected.receiptNumber, existing);
  if (existing.sourceFingerprint !== expected.sourceFingerprint ||
      existing.transactionId !== expected.transactionId ||
      existing.userId !== expected.userId) {
    throw integrityError("Receipt identity conflicts with the completed transaction.");
  }
}

function assertStoredReceipt(receiptId, receipt) {
  if (!receipt || receipt.receiptNumber !== receiptId ||
      receipt.healthPocketReferenceId !== receiptId ||
      !RECEIPT_NUMBER.test(receiptId) ||
      receipt.schemaVersion !== 1 ||
      !RECEIPT_TYPES.has(receipt.transactionType) ||
      receipt.status !== "completed" ||
      receipt.sourceFingerprint !== receiptFingerprint(receipt)) {
    throw integrityError("Stored receipt failed integrity validation.");
  }
  requireSafeId(receipt.userId, "receipt.userId");
  requireSafeId(receipt.transactionId, "receipt.transactionId");
  requireMoney(receipt.amountKobo, receipt.currency);
  const issuedAt = requireTimestamp(receipt.issuedAt, "receipt.issuedAt");
  const createdAt = requireTimestamp(receipt.createdAt, "receipt.createdAt");
  if (createdAt.toMillis() !== issuedAt.toMillis()) {
    throw integrityError("Receipt timestamps do not match.");
  }
}

function finalizeReceipt(receipt) {
  requireSafeId(receipt.userId, "userId");
  requireSafeId(receipt.transactionId, "transactionId");
  requireSafeId(receipt.transactionReference, "transactionReference");
  requireMoney(receipt.amountKobo, receipt.currency);
  requireBoundedString(receipt.description, "description", 200);
  requireSafeDisplayObject(receipt.provider, "provider");
  requireSafeDisplayObject(receipt.recipient, "recipient");
  requireSafeDisplayObject(receipt.paymentMethod, "paymentMethod");
  return { ...receipt, sourceFingerprint: receiptFingerprint(receipt) };
}

function requireCompletedSource(transactionId, transaction, type) {
  requireSafeId(transactionId, "transactionId");
  if (!transaction || typeof transaction !== "object" ||
      transaction.status !== "completed" ||
      transaction.transactionReference !== transactionId) {
    throw new ReceiptError(
      "receipt-not-eligible",
      `${type} receipt requires an authoritative completed transaction.`,
    );
  }
}

function receiptResult(receipt) {
  return {
    schemaVersion: receipt.schemaVersion,
    receiptNumber: receipt.receiptNumber,
    healthPocketReferenceId: receipt.healthPocketReferenceId,
    transactionId: receipt.transactionId,
    transactionType: receipt.transactionType,
    transactionReference: receipt.transactionReference,
    status: receipt.status,
    amountKobo: receipt.amountKobo,
    currency: receipt.currency,
    provider: receipt.provider,
    recipient: receipt.recipient,
    paymentMethod: receipt.paymentMethod,
    flowType: receipt.flowType || null,
    description: receipt.description,
    issuedAt: receipt.issuedAt.toDate().toISOString(),
  };
}

function receiptText(receipt) {
  return [
    "HealthPocket Receipt",
    `Reference: ${receipt.healthPocketReferenceId}`,
    `Transaction: ${receipt.transactionReference}`,
    `Date: ${receipt.issuedAt}`,
    `Type: ${receipt.transactionType}`,
    `Status: ${receipt.status}`,
    `Amount: ${receipt.currency} ${(receipt.amountKobo / 100).toFixed(2)}`,
    `Provider: ${receipt.provider.name}`,
    `Recipient: ${receipt.recipient.name}`,
    `Payment method: ${receipt.paymentMethod.type}`,
    `Description: ${receipt.description}`,
  ].join("\n");
}

function receiptShareText(receipt) {
  return `HealthPocket receipt ${receipt.healthPocketReferenceId}: ` +
    `${receipt.currency} ${(receipt.amountKobo / 100).toFixed(2)} — ${receipt.status}.`;
}

function receiptNumberForFunding(attemptId) {
  return `HPF-${hash({ attemptId }).slice(0, 12).toUpperCase()}`;
}

function receiptNumberForHealthcare(paymentId) {
  return `HPC-${hash({ paymentId }).slice(0, 12).toUpperCase()}`;
}

function receiptFingerprint(receipt) {
  return hash({
    schemaVersion: receipt.schemaVersion,
    receiptNumber: receipt.receiptNumber,
    healthPocketReferenceId: receipt.healthPocketReferenceId,
    userId: receipt.userId,
    transactionId: receipt.transactionId,
    transactionType: receipt.transactionType,
    transactionReference: receipt.transactionReference,
    status: receipt.status,
    amountKobo: receipt.amountKobo,
    currency: receipt.currency,
    provider: receipt.provider,
    recipient: receipt.recipient,
    paymentMethod: receipt.paymentMethod,
    flowType: receipt.flowType || null,
    description: receipt.description,
    ledgerOperationId: receipt.ledgerOperationId || null,
    ledgerEntryId: receipt.ledgerEntryId || null,
    issuedAtMillis: requireTimestamp(receipt.issuedAt, "issuedAt").toMillis(),
    createdAtMillis: requireTimestamp(receipt.createdAt, "createdAt").toMillis(),
  });
}

function providerDisplayName(value) {
  return value === "mock" ? "HealthPocket mock payment provider" : "Payment provider";
}

function requireReceiptNumber(value) {
  if (typeof value !== "string" || !RECEIPT_NUMBER.test(value)) {
    throw new ReceiptError("invalid-argument", "Receipt number is invalid.");
  }
}

function requireSafeId(value, field) {
  if (typeof value !== "string" || !SAFE_ID.test(value)) {
    throw new ReceiptError("invalid-argument", `${field} is invalid.`);
  }
  return value;
}

function requireMoney(amountKobo, currency) {
  if (!Number.isSafeInteger(amountKobo) || amountKobo <= 0 || currency !== "NGN") {
    throw integrityError("Receipt amount or currency is invalid.");
  }
}

function requireTimestamp(value, field) {
  if (!value || typeof value.toMillis !== "function" || typeof value.toDate !== "function") {
    throw integrityError(`${field} is invalid.`);
  }
  return value;
}

function requireBoundedString(value, field, maxLength) {
  if (typeof value !== "string" || value.trim() !== value ||
      value.length < 1 || value.length > maxLength) {
    throw integrityError(`${field} is invalid.`);
  }
}

function requireSafeDisplayObject(value, field) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw integrityError(`${field} is invalid.`);
  }
  for (const [key, item] of Object.entries(value)) {
    if (item != null && typeof item !== "string") {
      throw integrityError(`${field}.${key} is invalid.`);
    }
    if (typeof item === "string" && (item.length > 256 || /[\r\n\u0000-\u001f]/.test(item))) {
      throw integrityError(`${field}.${key} is invalid.`);
    }
  }
}

function hash(value) {
  return createHash("sha256").update(stableStringify(value)).digest("hex");
}

function stableStringify(value) {
  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(",")}]`;
  }
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) =>
      `${JSON.stringify(key)}:${stableStringify(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

function notFound() {
  return new ReceiptError("not-found", "Receipt was not found.");
}

function integrityError(message) {
  return new ReceiptError("integrity-error", message);
}

function log(logger, event, status) {
  logger.info?.("backend_event", {
    component: "receipts",
    event,
    status,
  });
}

module.exports = {
  buildReceiptService,
  ReceiptError,
  fundingReceiptDocument,
  healthcareReceiptDocument,
  receiptNumberForFunding,
  receiptNumberForHealthcare,
  assertReceiptCompatible,
};
