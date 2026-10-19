"use strict";

const { after, before, beforeEach, test } = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const {
  buildReceiptService,
  fundingReceiptDocument,
  healthcareReceiptDocument,
  receiptNumberForFunding,
  receiptNumberForHealthcare,
  assertReceiptCompatible,
} = require("../src/receipts/receipt-service");

let app;
let db;
let receipts;
const userId = "receipt-owner";
const silentLogger = { info() {} };

before(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("Run these tests through the Firebase Firestore emulator.");
  }
  app = initializeApp({ projectId: "demo-healthpocket" }, "receipt-tests");
  db = getFirestore(app);
});

beforeEach(async () => {
  await db.recursiveDelete(db.collection("receipts"));
  receipts = buildReceiptService({ db, logger: silentLogger });
});

after(async () => deleteApp(app));

test("builds the canonical funding receipt from a completed transaction", () => {
  const transactionId = "funding-receipt-1";
  const document = fundingReceiptDocument(transactionId, fundingSource(transactionId));

  assert.equal(document.receiptNumber, receiptNumberForFunding(transactionId));
  assert.equal(document.healthPocketReferenceId, document.receiptNumber);
  assert.equal(document.transactionType, "wallet_funding");
  assert.equal(document.status, "completed");
  assert.equal(document.amountKobo, 250000);
  assert.equal(document.recipient.name, "HealthPocket Wallet");
  assert.match(document.sourceFingerprint, /^[a-f0-9]{64}$/);
});

test("builds a historical healthcare provider snapshot", () => {
  const transactionId = "health-receipt-1";
  const source = healthcareSource(transactionId);
  const document = healthcareReceiptDocument(transactionId, source);
  source.providerName = "Renamed Clinic";

  assert.equal(document.receiptNumber, receiptNumberForHealthcare(transactionId));
  assert.equal(document.transactionType, "healthcare_payment");
  assert.deepEqual(document.provider, {
    id: "clinic-original",
    name: "Original Clinic",
    category: "clinic",
    city: "Ikeja",
    state: "Lagos",
  });
  assert.equal(document.paymentMethod.type, "healthpocket_partner");
});

test("pending and failed transactions cannot produce completed receipts", () => {
  const pending = fundingSource("pending-receipt", { status: "pending" });
  const failed = healthcareSource("failed-receipt", { status: "failed" });
  assert.throws(
    () => fundingReceiptDocument("pending-receipt", pending),
    (error) => error.code === "receipt-not-eligible",
  );
  assert.throws(
    () => healthcareReceiptDocument("failed-receipt", failed),
    (error) => error.code === "receipt-not-eligible",
  );
});

test("uses unique receipt document IDs and rejects conflicting reuse", () => {
  const funding = fundingReceiptDocument("shared-transaction", fundingSource("shared-transaction"));
  const healthcare = healthcareReceiptDocument(
    "shared-transaction",
    healthcareSource("shared-transaction"),
  );
  assert.notEqual(funding.receiptNumber, healthcare.receiptNumber);
  assert.doesNotThrow(() => assertReceiptCompatible(funding, funding));
  assert.throws(
    () => assertReceiptCompatible(funding, { ...funding, transactionId: "different" }),
    (error) => error.code === "integrity-error",
  );
});

test("returns owner-only receipt data and supports transaction lookup", async () => {
  const transactionId = "funding-read-1";
  const document = fundingReceiptDocument(transactionId, fundingSource(transactionId));
  await db.collection("receipts").doc(document.receiptNumber).set(document);

  const direct = await receipts.getReceipt({
    userId,
    receiptNumber: document.receiptNumber,
  });
  const byTransaction = await receipts.getReceiptForTransaction({
    userId,
    transactionType: "wallet_funding",
    transactionId,
  });
  assert.deepEqual(byTransaction, direct);
  assert.equal(direct.issuedAt, "2026-01-15T10:00:00.000Z");
  await assert.rejects(
    receipts.getReceipt({ userId: "receipt-stranger", receiptNumber: document.receiptNumber }),
    (error) => error.code === "not-found",
  );
});

test("prepares JSON and text contracts for download and sharing", async () => {
  const transactionId = "health-export-1";
  const document = healthcareReceiptDocument(
    transactionId,
    healthcareSource(transactionId),
  );
  await db.collection("receipts").doc(document.receiptNumber).set(document);

  const json = await receipts.exportReceipt({
    userId,
    receiptNumber: document.receiptNumber,
    format: "json",
  });
  const text = await receipts.exportReceipt({
    userId,
    receiptNumber: document.receiptNumber,
    format: "text",
  });
  assert.equal(json.mimeType, "application/json");
  assert.equal(JSON.parse(json.data).status, "completed");
  assert.match(json.shareText, /HPC-/);
  assert.equal(text.mimeType, "text/plain; charset=utf-8");
  assert.match(text.data, /Provider: Original Clinic/);
});

test("fails closed if an immutable receipt is corrupted", async () => {
  const transactionId = "funding-tamper-1";
  const document = fundingReceiptDocument(transactionId, fundingSource(transactionId));
  await db.collection("receipts").doc(document.receiptNumber).set({
    ...document,
    amountKobo: 99999999,
  });
  await assert.rejects(
    receipts.getReceipt({ userId, receiptNumber: document.receiptNumber }),
    (error) => error.code === "integrity-error",
  );
});

function fundingSource(transactionId, overrides = {}) {
  return {
    userId,
    transactionReference: transactionId,
    amountKobo: 250000,
    currency: "NGN",
    status: "completed",
    provider: "mock",
    providerReference: "mock-funding-reference",
    ledgerOperationId: "operation-funding-1",
    receiptNumber: receiptNumberForFunding(transactionId),
    description: "HealthPocket wallet funding",
    channel: "mock",
    completedAt: Timestamp.fromDate(new Date("2026-01-15T10:00:00.000Z")),
    ...overrides,
  };
}

function healthcareSource(transactionId, overrides = {}) {
  return {
    userId,
    transactionReference: transactionId,
    amountKobo: 40000,
    currency: "NGN",
    status: "completed",
    providerId: "clinic-original",
    providerName: "Original Clinic",
    providerCategory: "clinic",
    providerCity: "Ikeja",
    providerState: "Lagos",
    paymentProvider: "mock",
    providerReference: "mock-health-reference",
    ledgerOperationId: "operation-health-1",
    ledgerEntryId: "entry-health-1",
    receiptNumber: receiptNumberForHealthcare(transactionId),
    description: "Healthcare payment to Original Clinic",
    channel: "mock",
    flowType: "partner",
    completedAt: Timestamp.fromDate(new Date("2026-01-15T10:00:00.000Z")),
    ...overrides,
  };
}
