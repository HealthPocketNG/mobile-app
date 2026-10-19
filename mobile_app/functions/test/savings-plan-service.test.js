"use strict";

const { after, before, beforeEach, test } = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { buildLedgerService } = require("../src/ledger-service");
const { MockPaymentGateway } = require("../src/payments/mock-payment-gateway");
const { buildPaymentService } = require("../src/payments/payment-service");
const {
  buildSavingsPlanService,
  calculateNextContributionDate,
  DEFAULT_CONTRIBUTION_AMOUNT_KOBO,
} = require("../src/savings/savings-plan-service");

let app;
let db;
let ledger;
let gateway;
let payments;
let savings;
let currentTime;
const silentLogger = { info() {} };

before(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("Run these tests through the Firebase Firestore emulator.");
  }
  app = initializeApp({ projectId: "demo-healthpocket" }, "savings-tests");
  db = getFirestore(app);
});

beforeEach(async () => {
  await Promise.all([
    "activities",
    "financial_operations",
    "ledger_entries",
    "notification_events",
    "payment_attempts",
    "personal_health_pockets",
    "provider_events",
    "savings_plan_operations",
    "savings_plans",
    "scheduled_contributions",
    "wallets",
  ].map((collection) => db.recursiveDelete(db.collection(collection))));
  currentTime = new Date("2026-01-31T09:30:00.000Z");
  ledger = buildLedgerService({ db, logger: silentLogger });
  gateway = new MockPaymentGateway({ webhookSecret: "savings-test-secret-value" });
  payments = buildPaymentService({ db, ledger, gateway, logger: silentLogger });
  savings = buildSavingsPlanService({
    db,
    payments,
    clock: () => new Date(currentTime),
    logger: silentLogger,
  });
});

after(async () => deleteApp(app));

async function provisionUser(userId) {
  await Promise.all([
    ledger.ensureWallet(userId),
    db.collection("personal_health_pockets").doc(`personal-${userId}`).set({
      userId,
      currency: "NGN",
      status: "active",
      createdAt: Timestamp.fromDate(currentTime),
      updatedAt: Timestamp.fromDate(currentTime),
    }),
  ]);
}

async function createPlan(userId, overrides = {}) {
  await provisionUser(userId);
  return savings.createPlan({
    userId,
    frequency: "monthly",
    startDate: currentTime,
    idempotencyKey: `create_${userId}_0001`,
    ...overrides,
  });
}

test("calendar scheduling supports daily, weekly and clamped monthly dates", () => {
  const start = new Date("2026-01-31T09:30:00.000Z");
  assert.equal(
    calculateNextContributionDate({
      startDate: start,
      frequency: "daily",
      after: new Date("2026-02-02T09:29:00.000Z"),
    }).toISOString(),
    "2026-02-02T09:30:00.000Z",
  );
  assert.equal(
    calculateNextContributionDate({
      startDate: start,
      frequency: "weekly",
      after: new Date("2026-02-07T09:31:00.000Z"),
    }).toISOString(),
    "2026-02-14T09:30:00.000Z",
  );
  assert.equal(
    calculateNextContributionDate({
      startDate: start,
      frequency: "monthly",
      after: new Date("2026-02-01T00:00:00.000Z"),
    }).toISOString(),
    "2026-02-28T09:30:00.000Z",
  );
});

test("creates one plan with the N500 default and records an idempotent activity", async () => {
  await provisionUser("default-user");
  const request = {
    userId: "default-user",
    frequency: "weekly",
    startDate: new Date("2026-02-07T09:30:00.000Z"),
    idempotencyKey: "defaultplancreate1",
  };
  const first = await savings.createPlan(request);
  const retry = await savings.createPlan(request);

  assert.equal(first.planId, "personal-plan-default-user");
  assert.equal(first.contributionAmountKobo, DEFAULT_CONTRIBUTION_AMOUNT_KOBO);
  assert.equal(first.nextContributionDate.toISOString(), "2026-02-07T09:30:00.000Z");
  assert.deepEqual(retry, first);
  assert.equal((await db.collection("savings_plans").get()).size, 1);
  assert.equal((await db.collection("activities").get()).size, 1);

  await assert.rejects(
    savings.createPlan({ ...request, idempotencyKey: "anothercreatekey1" }),
    (error) => error.code === "plan-already-exists",
  );
});

test("updates amount and frequency, pauses, resumes, then cancels terminally", async () => {
  await createPlan("lifecycle-user");
  currentTime = new Date("2026-02-01T10:00:00.000Z");
  const updated = await savings.updatePlan({
    userId: "lifecycle-user",
    contributionAmountKobo: 75000,
    frequency: "weekly",
    idempotencyKey: "updateplan000001",
  });
  assert.equal(updated.contributionAmountKobo, 75000);
  assert.equal(updated.frequency, "weekly");

  const paused = await savings.pausePlan({
    userId: "lifecycle-user",
    idempotencyKey: "pauseplan0000001",
  });
  assert.equal(paused.status, "paused");
  assert.equal(paused.nextContributionDate, null);

  const resumed = await savings.resumePlan({
    userId: "lifecycle-user",
    idempotencyKey: "resumeplan000001",
  });
  assert.equal(resumed.status, "active");
  assert.ok(resumed.nextContributionDate > currentTime);

  const cancelled = await savings.cancelPlan({
    userId: "lifecycle-user",
    idempotencyKey: "cancelplan000001",
  });
  assert.equal(cancelled.status, "cancelled");
  assert.equal(cancelled.nextContributionDate, null);
  await assert.rejects(
    savings.resumePlan({
      userId: "lifecycle-user",
      idempotencyKey: "resumecancelled01",
    }),
    (error) => error.code === "invalid-state",
  );
  await assert.rejects(
    savings.updatePlan({
      userId: "lifecycle-user",
      contributionAmountKobo: 80000,
      idempotencyKey: "updatecancelled01",
    }),
    (error) => error.code === "plan-cancelled",
  );
  assert.equal((await db.collection("activities").get()).size, 5);
});

test("a pending mock contribution advances safely without crediting the ledger", async () => {
  const plan = await createPlan("pending-user", {
    contributionAmountKobo: 60000,
    frequency: "daily",
  });
  const result = await savings.processDueContribution({
    planId: plan.planId,
    scheduledFor: plan.nextContributionDate,
  });

  assert.equal(result.status, "pending");
  assert.equal((await db.collection("scheduled_contributions").get()).size, 1);
  assert.equal((await db.collection("ledger_entries").get()).size, 0);
  assert.equal(
    (await db.collection("wallets").doc("pending-user").get()).data()
      .availableBalanceKobo,
    0,
  );
  const advanced = await savings.getPlan("pending-user");
  assert.equal(advanced.nextContributionDate.toISOString(), "2026-02-01T09:30:00.000Z");
});

test("trusted mock success posts one savings credit across recurring-job retries", async () => {
  const plan = await createPlan("success-user", {
    contributionAmountKobo: 90000,
    frequency: "weekly",
  });
  gateway.setNextOutcome("verifyFunding", "success");
  const first = await savings.processDueContribution({
    planId: plan.planId,
    scheduledFor: plan.nextContributionDate,
  });
  const retry = await savings.processDueContribution({
    planId: plan.planId,
    scheduledFor: plan.nextContributionDate,
  });

  assert.equal(first.status, "succeeded");
  assert.equal(retry.ledgerOperationId, first.ledgerOperationId);
  assert.equal((await db.collection("scheduled_contributions").get()).size, 1);
  const entries = await db.collection("ledger_entries").get();
  assert.equal(entries.size, 1);
  assert.equal(entries.docs[0].data().source, "savings_contribution");
  assert.equal(
    (await db.collection("wallets").doc("success-user").get()).data()
      .availableBalanceKobo,
    90000,
  );
  const notifications = await db.collection("notification_events").get();
  assert.equal(notifications.size, 1);
  assert.equal(notifications.docs[0].data().category, "savings");
  assert.equal(notifications.docs[0].data().readState, "unread");
});

test("failed mock funding never creates a completed ledger credit", async () => {
  const plan = await createPlan("failed-user", {
    contributionAmountKobo: 45000,
  });
  gateway.setNextOutcome("initializeFunding", "failure");
  const result = await savings.processDueContribution({
    planId: plan.planId,
    scheduledFor: plan.nextContributionDate,
  });

  assert.equal(result.status, "failed");
  assert.equal(result.ledgerOperationId, null);
  assert.equal((await db.collection("ledger_entries").get()).size, 0);
  assert.equal(
    (await db.collection("wallets").doc("failed-user").get()).data()
      .availableBalanceKobo,
    0,
  );
  const notifications = await db.collection("notification_events").get();
  assert.equal(notifications.size, 1);
  assert.equal(notifications.docs[0].data().type, "scheduled_savings_contribution_failed");
});

test("a pending contribution can be verified later without duplication", async () => {
  const plan = await createPlan("delayed-user", { frequency: "daily" });
  const pending = await savings.processDueContribution({
    planId: plan.planId,
    scheduledFor: plan.nextContributionDate,
  });
  assert.equal(pending.status, "pending");

  gateway.setNextOutcome("verifyFunding", "success");
  const succeeded = await savings.processDueContribution({
    planId: plan.planId,
    scheduledFor: plan.nextContributionDate,
  });
  assert.equal(succeeded.status, "succeeded");
  assert.equal((await db.collection("scheduled_contributions").get()).size, 1);
  assert.equal((await db.collection("ledger_entries").get()).size, 1);
});

test("due-plan orchestration finds active work and records contribution activity", async () => {
  const plan = await createPlan("runner-user", { frequency: "daily" });
  gateway.setNextOutcome("verifyFunding", "success");
  const due = await savings.listDuePlans({ asOf: currentTime });
  assert.deepEqual(due.map((item) => item.planId), [plan.planId]);

  const results = await savings.runDueContributions({ asOf: currentTime });
  assert.equal(results.length, 1);
  assert.equal(results[0].status, "succeeded");
  const activities = await db.collection("activities")
    .where("activityType", "==", "scheduled_savings_contribution")
    .get();
  assert.equal(activities.size, 1);
  assert.equal(activities.docs[0].data().moneyMovement, true);
});

test("plan change idempotency keys reject conflicting reuse", async () => {
  await createPlan("conflict-savings-user");
  const request = {
    userId: "conflict-savings-user",
    contributionAmountKobo: 70000,
    idempotencyKey: "savingsconflict1",
  };
  await savings.updatePlan(request);
  await assert.rejects(
    savings.updatePlan({ ...request, contributionAmountKobo: 71000 }),
    (error) => error.code === "idempotency-conflict",
  );
});
