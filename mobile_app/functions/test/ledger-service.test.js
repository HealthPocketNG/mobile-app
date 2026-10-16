"use strict";

const { after, before, beforeEach, test } = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { buildLedgerService } = require("../src/ledger-service");

let app;
let db;
let ledger;
const silentLogger = { info() {} };

before(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("Run these tests through the Firebase Firestore emulator.");
  }
  app = initializeApp({ projectId: "demo-healthpocket" }, "ledger-tests");
  db = getFirestore(app);
  ledger = buildLedgerService({ db, logger: silentLogger });
});

beforeEach(async () => {
  await Promise.all([
    db.recursiveDelete(db.collection("wallets")),
    db.recursiveDelete(db.collection("financial_operations")),
    db.recursiveDelete(db.collection("ledger_entries")),
  ]);
});

after(async () => deleteApp(app));

test("provisions one zero-balance wallet idempotently", async () => {
  await Promise.all([
    ledger.ensureWallet("wallet-user"),
    ledger.ensureWallet("wallet-user"),
  ]);
  const snapshot = await db.collection("wallets").doc("wallet-user").get();
  assert.equal(snapshot.data().availableBalanceKobo, 0);
  assert.equal(snapshot.data().currency, "NGN");
  assert.equal(snapshot.data().version, 0);
});

test("concurrent retries create one credit and update balance once", async () => {
  await ledger.ensureWallet("retry-user");
  const request = {
    userId: "retry-user",
    idempotencyKey: "retrycredit000001",
    direction: "credit",
    amountKobo: 50000,
    source: "mock",
  };
  const results = await Promise.all(
    Array.from({ length: 8 }, () => ledger.processOperation(request)),
  );
  assert.ok(results.every((result) => result.status === "completed"));

  const wallet = await db.collection("wallets").doc("retry-user").get();
  const entries = await db.collection("ledger_entries").get();
  const operations = await db.collection("financial_operations").get();
  assert.equal(wallet.data().availableBalanceKobo, 50000);
  assert.equal(entries.size, 1);
  assert.equal(operations.size, 1);
});

test("reusing an idempotency key for different data is rejected", async () => {
  await ledger.ensureWallet("conflict-user");
  const base = {
    userId: "conflict-user",
    idempotencyKey: "conflictkey00001",
    direction: "credit",
    amountKobo: 50000,
    source: "mock",
  };
  await ledger.processOperation(base);
  await assert.rejects(
    ledger.processOperation({ ...base, amountKobo: 60000 }),
    (error) => error.code === "idempotency-conflict",
  );
});

test("an interrupted pending operation resumes and finalizes exactly once", async () => {
  await ledger.ensureWallet("resume-user");
  const pending = await ledger.createPendingOperation({
    userId: "resume-user",
    idempotencyKey: "resumepending0001",
    direction: "credit",
    amountKobo: 12500,
    source: "funding",
  });
  assert.equal(pending.status, "pending");

  const resumed = await ledger.processOperation({
    userId: "resume-user",
    idempotencyKey: "resumepending0001",
    direction: "credit",
    amountKobo: 12500,
    source: "funding",
  });
  const retried = await ledger.finalizeOperation({
    operationId: pending.operationId,
    outcome: "completed",
  });
  assert.equal(resumed.status, "completed");
  assert.equal(retried.status, "completed");
  assert.equal((await db.collection("ledger_entries").get()).size, 1);
  assert.equal(
    (await db.collection("wallets").doc("resume-user").get()).data()
      .availableBalanceKobo,
    12500,
  );
});

test("concurrent debits cannot make a wallet negative", async () => {
  await ledger.ensureWallet("debit-user");
  await ledger.processOperation({
    userId: "debit-user",
    idempotencyKey: "openingcredit0001",
    direction: "credit",
    amountKobo: 100000,
    source: "mock",
  });
  const [first, second] = await Promise.all([
    ledger.processOperation({
      userId: "debit-user",
      idempotencyKey: "concurrentdebit01",
      direction: "debit",
      amountKobo: 70000,
      source: "healthcare_payment",
    }),
    ledger.processOperation({
      userId: "debit-user",
      idempotencyKey: "concurrentdebit02",
      direction: "debit",
      amountKobo: 70000,
      source: "healthcare_payment",
    }),
  ]);
  assert.deepEqual(
    [first.status, second.status].sort(),
    ["completed", "failed"],
  );
  const wallet = await db.collection("wallets").doc("debit-user").get();
  assert.equal(wallet.data().availableBalanceKobo, 30000);
  assert.equal((await db.collection("ledger_entries").get()).size, 2);
});

test("failed and cancelled operations never create ledger entries", async () => {
  await ledger.ensureWallet("terminal-user");
  const insufficient = await ledger.processOperation({
    userId: "terminal-user",
    idempotencyKey: "insufficient00001",
    direction: "debit",
    amountKobo: 1,
    source: "healthcare_payment",
  });
  const pending = await ledger.createPendingOperation({
    userId: "terminal-user",
    idempotencyKey: "cancelpending0001",
    direction: "credit",
    amountKobo: 100,
    source: "funding",
  });
  const cancelled = await ledger.finalizeOperation({
    operationId: pending.operationId,
    outcome: "cancelled",
  });
  assert.equal(insufficient.status, "failed");
  assert.equal(insufficient.failureCode, "insufficient-balance");
  assert.equal(cancelled.status, "cancelled");
  assert.equal((await db.collection("ledger_entries").get()).size, 0);
});

test("a reversal adds a compensating immutable entry only once", async () => {
  await ledger.ensureWallet("reverse-user");
  const credit = await ledger.processOperation({
    userId: "reverse-user",
    idempotencyKey: "reversiblecredit1",
    direction: "credit",
    amountKobo: 90000,
    source: "funding",
  });
  const first = await ledger.reverseOperation({
    userId: "reverse-user",
    originalOperationId: credit.operationId,
    idempotencyKey: "reversalrequest01",
  });
  const retry = await ledger.reverseOperation({
    userId: "reverse-user",
    originalOperationId: credit.operationId,
    idempotencyKey: "reversalrequest01",
  });
  assert.equal(first.status, "completed");
  assert.equal(retry.operationId, first.operationId);
  assert.equal(
    (await db.collection("wallets").doc("reverse-user").get()).data()
      .availableBalanceKobo,
    0,
  );
  assert.equal((await db.collection("ledger_entries").get()).size, 2);
});

test("reconciliation detects cached-balance drift", async () => {
  await ledger.ensureWallet("reconcile-user");
  await ledger.processOperation({
    userId: "reconcile-user",
    idempotencyKey: "reconcilecredit01",
    direction: "credit",
    amountKobo: 40000,
    source: "mock",
  });
  assert.equal((await ledger.reconcileWallet("reconcile-user")).matches, true);

  await db.collection("wallets").doc("reconcile-user").update({
    availableBalanceKobo: 99999,
  });
  const drift = await ledger.reconcileWallet("reconcile-user");
  assert.equal(drift.matches, false);
  assert.equal(drift.expectedBalanceKobo, 40000);
  assert.equal(drift.actualBalanceKobo, 99999);
});

test("invalid, zero and overflowing amounts are rejected", async () => {
  await ledger.ensureWallet("validation-user");
  const base = {
    userId: "validation-user",
    idempotencyKey: "validationkey001",
    direction: "credit",
    source: "mock",
  };
  for (const amountKobo of [0, -1, 1.5, Number.MAX_SAFE_INTEGER]) {
    await assert.rejects(
      ledger.processOperation({ ...base, amountKobo }),
      (error) => error.code === "invalid-amount",
    );
  }
});
