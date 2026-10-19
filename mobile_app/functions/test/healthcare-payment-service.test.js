"use strict";

const { after, before, beforeEach, test } = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { buildLedgerService } = require("../src/ledger-service");
const { MockPaymentGateway } = require("../src/payments/mock-payment-gateway");
const { buildPaymentService } = require("../src/payments/payment-service");
const {
  AccountResolutionService,
  HealthcareEligibilityService,
  VERIFICATION_STATUS,
} = require("../src/healthcare/healthcare-verification");
const {
  MockAccountResolutionService,
  MockHealthcareEligibilityService,
} = require("../src/healthcare/mock-healthcare-verification");
const {
  buildHealthcarePaymentService,
} = require("../src/healthcare/healthcare-payment-service");

let app;
let db;
let ledger;
let gateway;
let payments;
let accountResolver;
let healthcareVerifier;
let healthcare;
const silentLogger = { info() {} };
const userId = "care-payment-user";

before(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("Run these tests through the Firebase Firestore emulator.");
  }
  app = initializeApp({ projectId: "demo-healthpocket" }, "healthcare-payment-tests");
  db = getFirestore(app);
});

beforeEach(async () => {
  await Promise.all([
    "healthcare_payments",
    "healthcare_providers",
    "wallets",
    "financial_operations",
    "ledger_entries",
    "payment_attempts",
    "provider_events",
    "activities",
    "notification_events",
    "receipts",
  ].map((collection) => db.recursiveDelete(db.collection(collection))));
  ledger = buildLedgerService({ db, logger: silentLogger });
  gateway = new MockPaymentGateway();
  payments = buildPaymentService({ db, ledger, gateway, logger: silentLogger });
  accountResolver = new MockAccountResolutionService();
  healthcareVerifier = new MockHealthcareEligibilityService();
  healthcare = buildHealthcarePaymentService({
    db,
    payments,
    accountResolver,
    healthcareVerifier,
    logger: silentLogger,
  });
  await fundWallet(userId, 1000000);
  await seedProvider("partner-clinic", "partner");
  await seedProvider("local-pharmacy", "non_partner");
});

after(async () => deleteApp(app));

async function fundWallet(ownerId, amountKobo) {
  await ledger.ensureWallet(ownerId);
  await ledger.processOperation({
    userId: ownerId,
    idempotencyKey: `openingbalance${ownerId}`.slice(0, 40),
    direction: "credit",
    amountKobo,
    source: "mock",
  });
}

async function seedProvider(providerId, partnerStatus, active = true) {
  await db.collection("healthcare_providers").doc(providerId).set({
    name: providerId === "partner-clinic" ? "Partner Clinic" : "Local Pharmacy",
    category: providerId === "partner-clinic" ? "clinic" : "pharmacy",
    city: "Ikeja",
    state: "Lagos",
    partnerStatus,
    active,
  });
}

function partnerRequest(overrides = {}) {
  return {
    userId,
    providerId: "partner-clinic",
    idempotencyKey: "partnerpayment0001",
    amountKobo: 250000,
    ...overrides,
  };
}

function nonPartnerRequest(overrides = {}) {
  return {
    userId,
    providerId: "local-pharmacy",
    idempotencyKey: "nonpartnerpay0001",
    amountKobo: 150000,
    bankAccount: { accountNumber: "0123456789", bankCode: "044" },
    ...overrides,
  };
}

test("defines replaceable account and healthcare-verification contracts", () => {
  assert.throws(() => new AccountResolutionService({ name: "direct" }), TypeError);
  assert.throws(() => new HealthcareEligibilityService({ name: "direct" }), TypeError);
  assert.equal(accountResolver.name, "mock_account_resolution");
  assert.equal(healthcareVerifier.name, "mock_healthcare_eligibility");
});

test("partner payment completes one debit with receipt, activity and notification", async () => {
  const pending = await healthcare.initiatePartnerPayment(partnerRequest());
  assert.equal(pending.status, "pending");
  gateway.setNextOutcome("verifyTransaction", "success");
  const completed = await healthcare.verifyPayment({
    paymentId: pending.paymentId,
    userId,
  });
  const retry = await healthcare.verifyPayment({
    paymentId: pending.paymentId,
    userId,
  });
  const document = (await db.collection("healthcare_payments")
    .doc(pending.paymentId).get()).data();
  const wallet = (await db.collection("wallets").doc(userId).get()).data();

  assert.equal(completed.status, "completed");
  assert.equal(retry.receiptNumber, completed.receiptNumber);
  assert.match(completed.receiptNumber, /^HPC-[A-F0-9]{12}$/);
  assert.equal(wallet.availableBalanceKobo, 750000);
  assert.ok(document.ledgerOperationId);
  assert.ok(document.ledgerEntryId);
  assert.equal(document.providerName, "Partner Clinic");
  assert.equal((await db.collection("activities").get()).size, 1);
  const notifications = await db.collection("notification_events").get();
  assert.equal(notifications.size, 1);
  assert.equal(notifications.docs[0].data().category, "payment");
  assert.equal(notifications.docs[0].data().readState, "unread");
  const receipt = (await db.collection("receipts").doc(completed.receiptNumber).get()).data();
  assert.equal(receipt.transactionId, pending.paymentId);
  assert.equal(receipt.provider.name, "Partner Clinic");
  assert.equal(receipt.status, "completed");
});

test("insufficient balance is rejected before any payment record or attempt", async () => {
  await assert.rejects(
    healthcare.initiatePartnerPayment(partnerRequest({ amountKobo: 1000001 })),
    (error) => error.code === "insufficient-balance",
  );
  assert.equal((await db.collection("healthcare_payments").get()).empty, true);
  assert.equal((await db.collection("payment_attempts").get()).empty, true);
});

test("inactive and wrong-flow providers cannot start payments", async () => {
  await seedProvider("closed-clinic", "partner", false);
  await assert.rejects(
    healthcare.initiatePartnerPayment(partnerRequest({
      providerId: "closed-clinic",
      idempotencyKey: "closedprovider0001",
    })),
    (error) => error.code === "provider-inactive",
  );
  await assert.rejects(
    healthcare.initiatePartnerPayment(partnerRequest({
      providerId: "local-pharmacy",
      idempotencyKey: "wrongflowpayment01",
    })),
    (error) => error.code === "provider-flow-mismatch",
  );
});

test("pending and failed partner outcomes never debit the wallet", async () => {
  const pending = await healthcare.initiatePartnerPayment(partnerRequest());
  assert.equal(pending.status, "pending");
  gateway.setNextOutcome("verifyTransaction", "failure");
  const failed = await healthcare.verifyPayment({
    paymentId: pending.paymentId,
    userId,
  });
  assert.equal(failed.status, "failed");
  assert.equal(
    (await db.collection("wallets").doc(userId).get()).data().availableBalanceKobo,
    1000000,
  );
  assert.equal((await db.collection("ledger_entries")
    .where("direction", "==", "debit").get()).empty, true);
  const activity = (await db.collection("activities").get()).docs[0].data();
  assert.equal(activity.activityType, "healthcare_payment_failed");
  assert.equal(activity.moneyMovement, false);
  assert.equal((await db.collection("receipts").get()).empty, true);
});

test("non-partner payment requires both mock verifications before settlement", async () => {
  const pending = await healthcare.initiateNonPartnerPayment(nonPartnerRequest());
  const saved = (await db.collection("healthcare_payments")
    .doc(pending.paymentId).get()).data();
  assert.equal(pending.status, "pending");
  assert.equal(saved.verificationStatus, "verified");
  assert.equal(saved.beneficiary.accountNumberLast4, "6789");
  assert.equal(JSON.stringify(saved).includes("0123456789"), false);
  assert.equal(saved.verificationSource, "mock_healthcare_eligibility");

  gateway.setNextOutcome("verifyTransaction", "success");
  const completed = await healthcare.verifyPayment({
    paymentId: pending.paymentId,
    userId,
  });
  assert.equal(completed.status, "completed");
  assert.equal(completed.flowType, "non_partner");
  assert.equal((await db.collection("receipts").get()).size, 1);
});

test("non-partner eligibility rejection blocks payment and preserves failure", async () => {
  healthcareVerifier.setNextOutcome(VERIFICATION_STATUS.REJECTED);
  const rejected = await healthcare.initiateNonPartnerPayment(nonPartnerRequest());
  assert.equal(rejected.status, "failed");
  assert.equal(rejected.verificationStatus, "rejected");
  assert.equal(rejected.paymentAttemptId, null);
  assert.equal((await db.collection("payment_attempts").get()).empty, true);
  assert.equal(
    (await db.collection("wallets").doc(userId).get()).data().availableBalanceKobo,
    1000000,
  );
  assert.equal(
    (await db.collection("activities").get()).docs[0].data().activityType,
    "healthcare_payment_failed",
  );
  assert.equal((await db.collection("receipts").get()).empty, true);
});

test("mock verification never claims production MCC verification", async () => {
  const beneficiary = (await accountResolver.resolveAccount(
    nonPartnerRequest().bankAccount,
  )).beneficiary;
  const verification = await healthcareVerifier.verifyProvider({
    providerId: "local-pharmacy",
    beneficiary,
  });
  assert.equal(verification.status, "verified");
  assert.equal(verification.productionMccVerified, false);
  assert.equal(Object.hasOwn(verification, "mcc"), false);
});

test("retries are idempotent and conflicting request reuse is rejected", async () => {
  const first = await healthcare.initiatePartnerPayment(partnerRequest());
  const retry = await healthcare.initiatePartnerPayment(partnerRequest());
  assert.equal(retry.paymentId, first.paymentId);
  assert.equal((await db.collection("payment_attempts").get()).size, 1);
  await assert.rejects(
    healthcare.initiatePartnerPayment(partnerRequest({ amountKobo: 300000 })),
    (error) => error.code === "idempotency-conflict",
  );
});

test("payment verification enforces transaction ownership", async () => {
  const pending = await healthcare.initiatePartnerPayment(partnerRequest());
  await assert.rejects(
    healthcare.verifyPayment({ paymentId: pending.paymentId, userId: "other-user" }),
    (error) => error.code === "permission-denied",
  );
});
