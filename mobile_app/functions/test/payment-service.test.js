"use strict";

const { after, before, beforeEach, test } = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { buildLedgerService } = require("../src/ledger-service");
const {
  PaymentGateway,
  PAYMENT_STATUS,
} = require("../src/payments/payment-gateway");
const { MockPaymentGateway } = require("../src/payments/mock-payment-gateway");
const { buildPaymentService } = require("../src/payments/payment-service");
const {
  FUNDING_PRESET_AMOUNTS_KOBO,
  MIN_FUNDING_AMOUNT_KOBO,
  MAX_FUNDING_AMOUNT_KOBO,
} = require("../src/payments/funding-policy");

let app;
let db;
let ledger;
let gateway;
let payments;
const silentLogger = { info() {} };

before(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("Run these tests through the Firebase Firestore emulator.");
  }
  app = initializeApp({ projectId: "demo-healthpocket" }, "payment-tests");
  db = getFirestore(app);
});

beforeEach(async () => {
  await Promise.all([
    db.recursiveDelete(db.collection("wallets")),
    db.recursiveDelete(db.collection("financial_operations")),
    db.recursiveDelete(db.collection("ledger_entries")),
    db.recursiveDelete(db.collection("payment_attempts")),
    db.recursiveDelete(db.collection("provider_events")),
    db.recursiveDelete(db.collection("funding_transactions")),
    db.recursiveDelete(db.collection("receipts")),
    db.recursiveDelete(db.collection("activities")),
    db.recursiveDelete(db.collection("notification_events")),
  ]);
  ledger = buildLedgerService({ db, logger: silentLogger });
  gateway = new MockPaymentGateway({ webhookSecret: "test-secret-at-least-sixteen" });
  payments = buildPaymentService({ db, ledger, gateway, logger: silentLogger });
});

after(async () => deleteApp(app));

test("defines a provider-neutral gateway contract and normalized statuses", () => {
  assert.throws(() => new PaymentGateway({ name: "direct" }), /abstract/);
  assert.deepEqual(
    Object.values(PAYMENT_STATUS).sort(),
    ["cancelled", "created", "failed", "pending", "reversed", "succeeded", "timed_out"],
  );
  for (const operation of [
    "initializeFunding",
    "verifyFunding",
    "resolveBeneficiary",
    "initiateHealthcarePayment",
    "verifyTransaction",
    "queryStatus",
    "verifyWebhookSignature",
    "parseWebhook",
  ]) {
    assert.equal(typeof gateway[operation], "function");
  }
});

test("client-reported success cannot finalize an unverified funding attempt", async () => {
  await ledger.ensureWallet("funding-user");
  gateway.setNextOutcome("initializeFunding", "success");
  const attempt = await payments.initializeFunding({
    userId: "funding-user",
    idempotencyKey: "fundingattempt0001",
    amountKobo: 50000,
    status: "succeeded",
  });

  assert.equal(attempt.status, PAYMENT_STATUS.PENDING);
  assert.match(attempt.providerReference, /^mock_funding_/);
  assert.equal((await db.collection("ledger_entries").get()).size, 0);
  assert.equal(
    (await db.collection("wallets").doc("funding-user").get()).data()
      .availableBalanceKobo,
    0,
  );
});

test("trusted funding verification posts one credit across retries", async () => {
  await ledger.ensureWallet("verified-user");
  const attempt = await payments.initializeFunding({
    userId: "verified-user",
    idempotencyKey: "verifiedfunding01",
    amountKobo: 125000,
  });
  gateway.setNextOutcome("verifyFunding", "success");

  const first = await payments.verifyFunding({ attemptId: attempt.attemptId });
  const retry = await payments.verifyFunding({ attemptId: attempt.attemptId });

  assert.equal(first.status, PAYMENT_STATUS.SUCCEEDED);
  assert.equal(retry.ledgerOperationId, first.ledgerOperationId);
  assert.equal((await db.collection("ledger_entries").get()).size, 1);
  assert.equal(
    (await db.collection("wallets").doc("verified-user").get()).data()
      .availableBalanceKobo,
    125000,
  );
});

test("verification rejects mismatched provider settlement details", async () => {
  await ledger.ensureWallet("provider-mismatch-user");
  const attempt = await payments.initializeFunding({
    userId: "provider-mismatch-user",
    idempotencyKey: "providermismatch01",
    amountKobo: 125000,
  });
  gateway.verifyFunding = async () => ({
    status: PAYMENT_STATUS.SUCCEEDED,
    providerReference: "different_provider_reference",
    amountKobo: 125000,
    currency: "NGN",
    beneficiaryId: null,
  });

  await assert.rejects(
    payments.verifyFunding({ attemptId: attempt.attemptId }),
    (error) => error.code === "provider-transaction-mismatch",
  );
  assert.equal((await db.collection("ledger_entries").get()).size, 0);
  assert.equal(
    (await db.collection("wallets").doc("provider-mismatch-user").get())
      .data().availableBalanceKobo,
    0,
  );
});

test("provider timeout remains ambiguous and non-financial with a safe retry path", async () => {
  await ledger.ensureWallet("timeout-user");
  gateway.setNextOutcome("initializeFunding", "timeout");
  const attempt = await payments.initializeFunding({
    userId: "timeout-user",
    idempotencyKey: "timeoutfunding001",
    amountKobo: 200000,
  });

  assert.equal(attempt.status, PAYMENT_STATUS.TIMED_OUT);
  assert.equal(attempt.providerReference, null);
  assert.equal((await db.collection("ledger_entries").get()).size, 0);
  assert.equal(
    (await db.collection("funding_transactions").doc(attempt.attemptId).get())
      .data().status,
    "pending",
  );
  assert.equal((await db.collection("activities").get()).size, 0);

  const retried = await payments.initializeFunding({
    userId: "timeout-user",
    idempotencyKey: "timeoutfunding001",
    amountKobo: 200000,
  });
  assert.equal(retried.status, PAYMENT_STATUS.PENDING);
  assert.match(retried.providerReference, /^mock_funding_/);
});

test("verification timeout remains non-financial and server reconciliation credits once", async () => {
  await ledger.ensureWallet("verify-timeout-user");
  const attempt = await payments.initializeFunding({
    userId: "verify-timeout-user",
    idempotencyKey: "verifytimeoutfund1",
    amountKobo: 100000,
  });
  gateway.setNextOutcome("verifyFunding", "timeout");
  const timedOut = await payments.verifyFunding({ attemptId: attempt.attemptId });

  assert.equal(timedOut.status, PAYMENT_STATUS.TIMED_OUT);
  assert.equal((await db.collection("ledger_entries").get()).size, 0);
  assert.equal(
    (await db.collection("funding_transactions").doc(attempt.attemptId).get())
      .data().status,
    "pending",
  );

  gateway.setNextOutcome("queryStatus", "success");
  const recovered = await payments.reconcileAttempt({
    attemptId: attempt.attemptId,
  });
  const retry = await payments.reconcileAttempt({
    attemptId: attempt.attemptId,
  });
  assert.equal(recovered.status, PAYMENT_STATUS.SUCCEEDED);
  assert.equal(retry.ledgerOperationId, recovered.ledgerOperationId);
  assert.equal((await db.collection("ledger_entries").get()).size, 1);
});

test("reconciliation timeout stays ambiguous and creates no ledger entry", async () => {
  await ledger.ensureWallet("reconcile-timeout-user");
  const attempt = await payments.initializeFunding({
    userId: "reconcile-timeout-user",
    idempotencyKey: "reconciletimeout01",
    amountKobo: 100000,
  });
  gateway.setNextOutcome("queryStatus", "timeout");

  const reconciled = await payments.reconcileAttempt({
    attemptId: attempt.attemptId,
  });

  assert.equal(reconciled.status, PAYMENT_STATUS.TIMED_OUT);
  assert.equal((await db.collection("ledger_entries").get()).size, 0);
  assert.equal(
    (await db.collection("wallets").doc("reconcile-timeout-user").get())
      .data().availableBalanceKobo,
    0,
  );
});

test("signed duplicate callbacks are idempotent", async () => {
  await ledger.ensureWallet("webhook-user");
  const attempt = await payments.initializeFunding({
    userId: "webhook-user",
    idempotencyKey: "webhookfunding01",
    amountKobo: 73000,
  });
  const deliveries = gateway.buildWebhookCallback({
    eventId: "mock-event-0001",
    attemptId: attempt.attemptId,
    providerReference: attempt.providerReference,
    status: PAYMENT_STATUS.SUCCEEDED,
    duplicate: true,
  });

  const first = await payments.processWebhook(deliveries[0]);
  const duplicate = await payments.processWebhook(deliveries[1]);

  assert.equal(first.status, PAYMENT_STATUS.SUCCEEDED);
  assert.equal(first.duplicate, false);
  assert.equal(duplicate.duplicate, true);
  assert.equal((await db.collection("provider_events").get()).size, 1);
  assert.equal((await db.collection("ledger_entries").get()).size, 1);
  assert.equal(
    (await db.collection("wallets").doc("webhook-user").get()).data()
      .availableBalanceKobo,
    73000,
  );
});

test("invalid webhook signatures are rejected before any state change", async () => {
  await ledger.ensureWallet("signature-user");
  const attempt = await payments.initializeFunding({
    userId: "signature-user",
    idempotencyKey: "signaturefund001",
    amountKobo: 100000,
  });
  const [delivery] = gateway.buildWebhookCallback({
    eventId: "mock-event-invalid-signature",
    attemptId: attempt.attemptId,
    providerReference: attempt.providerReference,
    status: PAYMENT_STATUS.SUCCEEDED,
  });
  delivery.headers["x-healthpocket-mock-signature"] = "0".repeat(64);

  await assert.rejects(
    payments.processWebhook(delivery),
    (error) => error.code === "invalid-signature",
  );
  assert.equal((await db.collection("provider_events").get()).size, 0);
  assert.equal((await db.collection("ledger_entries").get()).size, 0);
});

test("signed callbacks with mismatched settlement details fail closed", async () => {
  await ledger.ensureWallet("mismatch-user");
  const attempt = await payments.initializeFunding({
    userId: "mismatch-user",
    idempotencyKey: "mismatchfunding01",
    amountKobo: 100000,
  });
  const [delivery] = gateway.buildWebhookCallback({
    eventId: "mock-event-mismatched-amount",
    attemptId: attempt.attemptId,
    providerReference: attempt.providerReference,
    status: PAYMENT_STATUS.SUCCEEDED,
    amountKobo: 200000,
  });

  await assert.rejects(
    payments.processWebhook(delivery),
    (error) => error.code === "provider-transaction-mismatch",
  );
  assert.equal((await db.collection("provider_events").get()).size, 0);
  assert.equal((await db.collection("ledger_entries").get()).size, 0);
  assert.equal(
    (await db.collection("wallets").doc("mismatch-user").get())
      .data().availableBalanceKobo,
    0,
  );
});

test("healthcare success and reversal create compensating ledger entries", async () => {
  await ledger.ensureWallet("care-user");
  await ledger.processOperation({
    userId: "care-user",
    idempotencyKey: "openingcarecredit",
    direction: "credit",
    amountKobo: 10000,
    source: "mock",
  });
  const beneficiary = await payments.resolveBeneficiary({
    beneficiaryId: "clinic-demo-01",
  });
  assert.equal(beneficiary.valid, true);
  const attempt = await payments.initiateHealthcarePayment({
    userId: "care-user",
    idempotencyKey: "carepayment00001",
    amountKobo: 4000,
    beneficiaryId: "clinic-demo-01",
  });
  const [success] = gateway.buildWebhookCallback({
    eventId: "mock-care-success",
    attemptId: attempt.attemptId,
    providerReference: attempt.providerReference,
    status: PAYMENT_STATUS.SUCCEEDED,
  });
  const [reversal] = gateway.buildWebhookCallback({
    eventId: "mock-care-reversal",
    attemptId: attempt.attemptId,
    providerReference: attempt.providerReference,
    status: PAYMENT_STATUS.REVERSED,
  });

  await payments.processWebhook(success);
  const reversed = await payments.processWebhook(reversal);

  assert.equal(reversed.status, PAYMENT_STATUS.REVERSED);
  assert.equal((await db.collection("ledger_entries").get()).size, 3);
  assert.equal(
    (await db.collection("wallets").doc("care-user").get()).data()
      .availableBalanceKobo,
    10000,
  );
});

test("mock outcomes cover pending, failure, timeout and reversal", async () => {
  gateway.setNextOutcome("resolveBeneficiary", "failure");
  assert.equal(
    (await payments.resolveBeneficiary({ beneficiaryId: "clinic-demo-02" })).status,
    PAYMENT_STATUS.FAILED,
  );

  await ledger.ensureWallet("outcome-user");
  gateway.setNextOutcome("initializeFunding", "failure");
  const failed = await payments.initializeFunding({
    userId: "outcome-user",
    idempotencyKey: "failedfunding001",
    amountKobo: 50000,
  });
  assert.equal(failed.status, PAYMENT_STATUS.FAILED);

  const pending = await payments.initializeFunding({
    userId: "outcome-user",
    idempotencyKey: "pendingfunding01",
    amountKobo: 50000,
  });
  gateway.setNextOutcome("queryStatus", "reversal");
  assert.equal(
    (await payments.queryStatus({ attemptId: pending.attemptId })).status,
    PAYMENT_STATUS.REVERSED,
  );

  gateway.setNextOutcome("queryStatus", "timeout");
  await assert.rejects(
    payments.queryStatus({ attemptId: pending.attemptId }),
    (error) => error.code === "provider-timeout",
  );
});

test("reusing a payment idempotency key with different data is rejected", async () => {
  await ledger.ensureWallet("conflict-payment-user");
  const request = {
    userId: "conflict-payment-user",
    idempotencyKey: "paymentconflict1",
    amountKobo: 50000,
  };
  await payments.initializeFunding(request);
  await assert.rejects(
    payments.initializeFunding({ ...request, amountKobo: 50100 }),
    (error) => error.code === "idempotency-conflict",
  );
});

test("central funding policy accepts presets and custom amounts within bounds", async () => {
  assert.deepEqual(FUNDING_PRESET_AMOUNTS_KOBO, [
    50000,
    100000,
    200000,
    500000,
    1000000,
  ]);
  await ledger.ensureWallet("amount-policy-user");
  const preset = await payments.initializeFunding({
    userId: "amount-policy-user",
    idempotencyKey: "fundingpreset0001",
    amountKobo: FUNDING_PRESET_AMOUNTS_KOBO[0],
  });
  const custom = await payments.initializeFunding({
    userId: "amount-policy-user",
    idempotencyKey: "fundingcustom0001",
    amountKobo: 123456,
  });

  assert.equal(preset.status, PAYMENT_STATUS.PENDING);
  assert.equal(custom.status, PAYMENT_STATUS.PENDING);
  for (const amountKobo of [
    0,
    MIN_FUNDING_AMOUNT_KOBO - 1,
    MAX_FUNDING_AMOUNT_KOBO + 1,
    50000.5,
  ]) {
    await assert.rejects(
      payments.initializeFunding({
        userId: "amount-policy-user",
        idempotencyKey:
          `invalidfundingamount${String(amountKobo).replaceAll(".", "x")}`,
        amountKobo,
      }),
      (error) => error.code === "invalid-amount",
    );
  }
});

test("completed funding creates a receipt, activity and one notification", async () => {
  await ledger.ensureWallet("receipt-user");
  const attempt = await payments.initializeFunding({
    userId: "receipt-user",
    idempotencyKey: "receiptfunding001",
    amountKobo: 250000,
  });
  gateway.setNextOutcome("verifyFunding", "success");
  const completed = await payments.verifyFunding({ attemptId: attempt.attemptId });
  await payments.verifyFunding({ attemptId: attempt.attemptId });

  const transaction = (
    await db.collection("funding_transactions").doc(attempt.attemptId).get()
  ).data();
  assert.equal(completed.status, PAYMENT_STATUS.SUCCEEDED);
  assert.equal(transaction.status, "completed");
  assert.equal(transaction.amountKobo, 250000);
  assert.equal(transaction.transactionReference, attempt.attemptId);
  assert.match(transaction.receiptNumber, /^HPF-[A-F0-9]{12}$/);
  assert.equal(transaction.description, "HealthPocket wallet funding");
  assert.ok(transaction.completedAt);
  assert.equal((await db.collection("ledger_entries").get()).size, 1);
  assert.equal((await db.collection("activities").get()).size, 1);
  const notifications = await db.collection("notification_events").get();
  assert.equal(notifications.size, 1);
  assert.equal(notifications.docs[0].data().category, "funding");
  assert.equal(notifications.docs[0].data().readState, "unread");
  const receipts = await db.collection("receipts").get();
  assert.equal(receipts.size, 1);
  assert.equal(receipts.docs[0].id, transaction.receiptNumber);
  assert.equal(receipts.docs[0].data().status, "completed");
  assert.equal(receipts.docs[0].data().transactionId, attempt.attemptId);
});

test("delayed success, failure, timeout and cancellation retain safe funding records", async () => {
  await ledger.ensureWallet("lifecycle-funding-user");
  const pending = await payments.initializeFunding({
    userId: "lifecycle-funding-user",
    idempotencyKey: "delayedfunding001",
    amountKobo: 100000,
  });
  assert.equal(
    (await db.collection("funding_transactions").doc(pending.attemptId).get())
      .data().status,
    "pending",
  );
  gateway.setNextOutcome("verifyFunding", "pending");
  assert.equal(
    (await payments.verifyFunding({ attemptId: pending.attemptId })).status,
    PAYMENT_STATUS.PENDING,
  );
  gateway.setNextOutcome("verifyFunding", "success");
  assert.equal(
    (await payments.verifyFunding({ attemptId: pending.attemptId })).status,
    PAYMENT_STATUS.SUCCEEDED,
  );

  gateway.setNextOutcome("initializeFunding", "failure");
  const failed = await payments.initializeFunding({
    userId: "lifecycle-funding-user",
    idempotencyKey: "failurefunding001",
    amountKobo: 100000,
  });
  gateway.setNextOutcome("initializeFunding", "timeout");
  const timedOut = await payments.initializeFunding({
    userId: "lifecycle-funding-user",
    idempotencyKey: "timeoutfunding002",
    amountKobo: 100000,
  });
  const cancelledAttempt = await payments.initializeFunding({
    userId: "lifecycle-funding-user",
    idempotencyKey: "cancelfunding001",
    amountKobo: 100000,
  });
  const [cancellation] = gateway.buildWebhookCallback({
    eventId: "mock-funding-cancelled",
    attemptId: cancelledAttempt.attemptId,
    providerReference: cancelledAttempt.providerReference,
    status: PAYMENT_STATUS.CANCELLED,
  });
  await payments.processWebhook(cancellation);

  const funding = db.collection("funding_transactions");
  assert.equal((await funding.doc(failed.attemptId).get()).data().status, "failed");
  assert.equal((await funding.doc(timedOut.attemptId).get()).data().status, "pending");
  assert.equal(
    (await funding.doc(cancelledAttempt.attemptId).get()).data().status,
    "cancelled",
  );
  assert.equal((await db.collection("ledger_entries").get()).size, 1);
  assert.equal((await db.collection("notification_events").get()).size, 3);
  assert.equal((await db.collection("receipts").get()).size, 1);
});
