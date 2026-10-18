"use strict";

const { after, before, beforeEach, test } = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const {
  buildActivityHistoryService,
} = require("../src/activity/activity-history-service");

let app;
let db;
let history;
const ownerId = "history-owner";
const silentLogger = { info() {} };

before(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("Run these tests through the Firebase Firestore emulator.");
  }
  app = initializeApp({ projectId: "demo-healthpocket" }, "activity-history-tests");
  db = getFirestore(app);
});

beforeEach(async () => {
  await Promise.all([
    "activities",
    "funding_transactions",
    "healthcare_payments",
    "scheduled_contributions",
    "savings_plans",
    "family_contribution_attempts",
    "family_pockets",
  ].map((collection) => db.recursiveDelete(db.collection(collection))));
  history = buildActivityHistoryService({
    db,
    logger: silentLogger,
    clock: () => new Date("2026-02-01T12:00:00.000Z"),
  });
  await seedPersonalHistory();
});

after(async () => deleteApp(app));

test("returns a normalized newest-first page with an opaque cursor", async () => {
  const first = await history.listHistory({ actorId: ownerId, pageSize: 2 });
  assert.deepEqual(first.items.map((item) => item.activityId), [
    "activity-funding",
    "activity-healthcare",
  ]);
  assert.equal(first.items[0].category, "funding");
  assert.equal(first.items[0].status, "completed");
  assert.equal(first.items[0].direction, "credit");
  assert.equal(first.items[1].direction, "debit");
  assert.ok(first.nextCursor);

  const second = await history.listHistory({
    actorId: ownerId,
    pageSize: 2,
    cursor: first.nextCursor,
  });
  assert.deepEqual(second.items.map((item) => item.activityId), [
    "activity-savings-failed",
  ]);
  assert.equal(second.nextCursor, null);
});

test("uses authoritative transaction amounts instead of stale activity metadata", async () => {
  const detail = await history.getTransactionDetail({
    actorId: ownerId,
    activityId: "activity-funding",
  });
  assert.equal(detail.amountKobo, 125000);
  assert.equal(detail.signedAmountKobo, 125000);
  assert.equal(detail.receiptNumber, "HPF-TEST-001");
  assert.deepEqual(detail.metadata, {
    action: null,
    flowType: null,
    receiptNumber: "HPF-TEST-001",
  });
});

test("supports exact activity-type and inclusive date-range filters", async () => {
  const byType = await history.listHistory({
    actorId: ownerId,
    activityType: "healthcare_payment_completed",
  });
  assert.deepEqual(byType.items.map((item) => item.activityId), ["activity-healthcare"]);

  const byDate = await history.listHistory({
    actorId: ownerId,
    startDate: "2026-01-02T00:00:00.000Z",
    endDate: "2026-01-03T23:59:59.999Z",
  });
  assert.deepEqual(byDate.items.map((item) => item.activityId), [
    "activity-healthcare",
    "activity-savings-failed",
  ]);
});

test("rejects a cursor reused with different filters", async () => {
  const page = await history.listHistory({ actorId: ownerId, pageSize: 1 });
  await assert.rejects(
    history.listHistory({
      actorId: ownerId,
      activityType: "funding_completed",
      cursor: page.nextCursor,
    }),
    (error) => error.code === "invalid-cursor",
  );
});

test("returns a clean empty state", async () => {
  const result = await history.listHistory({ actorId: "no-history-user" });
  assert.deepEqual(result, { items: [], nextCursor: null, empty: true });
});

test("normalizes savings-plan lifecycle events as non-financial history", async () => {
  await db.collection("savings_plans").doc("plan-history-1").set({
    userId: ownerId,
    status: "active",
  });
  await writeActivity("activity-plan-created", {
    activityType: "savings_plan_create",
    relatedEntityType: "savings_plan",
    relatedEntityId: "plan-history-1",
    status: "recorded",
    metadata: { action: "create" },
    createdAt: "2026-01-05T12:00:00.000Z",
  });
  const detail = await history.getTransactionDetail({
    actorId: ownerId,
    activityId: "activity-plan-created",
  });
  assert.equal(detail.status, "recorded");
  assert.equal(detail.moneyMovement, false);
  assert.equal(detail.amountKobo, null);
});

test("prevents another user from reading transaction detail", async () => {
  await assert.rejects(
    history.getTransactionDetail({
      actorId: "history-stranger",
      activityId: "activity-funding",
    }),
    (error) => error.code === "permission-denied",
  );
});

test("allows active Family Pocket members and rejects removed members", async () => {
  await seedFamilyHistory();
  const allowed = await history.listHistory({
    actorId: "family-member",
    familyPocketId: "family-history",
  });
  assert.equal(allowed.items.length, 1);
  assert.equal(allowed.items[0].category, "family_pocket");
  assert.equal(allowed.items[0].amountKobo, 50000);

  await db.collection("family_pockets").doc("family-history")
    .collection("members").doc("family-member").update({
      status: "removed",
      removedAt: Timestamp.now(),
    });
  await assert.rejects(
    history.listHistory({
      actorId: "family-member",
      familyPocketId: "family-history",
    }),
    (error) => error.code === "permission-denied",
  );
});

test("exports the owner's Family contribution without leaking another member's", async () => {
  await seedFamilyHistory();
  await db.collection("family_contribution_attempts").doc("family-attempt-other").set({
    contributorUserId: "another-family-member",
    pocketId: "family-history",
    amountKobo: 75000,
    currency: "NGN",
    status: "completed",
  });
  await db.collection("activities").doc("activity-family-other").set({
    userId: "another-family-member",
    familyPocketId: "family-history",
    activityType: "family_contribution_completed",
    relatedEntityType: "family_contribution",
    relatedEntityId: "family-attempt-other",
    metadata: { amountKobo: 75000, currency: "NGN" },
    createdAt: Timestamp.fromDate(new Date("2026-01-01T13:00:00.000Z")),
  });
  const statement = await history.prepareStatement({
    actorId: ownerId,
    startDate: "2026-01-01T00:00:00.000Z",
    endDate: "2026-01-31T23:59:59.999Z",
  });
  assert.equal(statement.scope.type, "personal");
  assert.equal(statement.recordCount, 4);
  assert.match(statement.csv, /^activity_id,occurred_at,type,category,status/);
  assert.match(statement.csv, /activity-healthcare/);
  assert.match(statement.csv, /activity-family,/);
  assert.doesNotMatch(statement.csv, /activity-family-other/);
});

test("requires bounded dates and authorized scope for statement exports", async () => {
  await assert.rejects(
    history.prepareStatement({ actorId: ownerId }),
    (error) => error.code === "invalid-argument",
  );
  await assert.rejects(
    history.prepareStatement({
      actorId: "history-stranger",
      familyPocketId: "family-history",
      startDate: "2026-01-01T00:00:00.000Z",
      endDate: "2026-01-31T23:59:59.999Z",
    }),
    (error) => error.code === "permission-denied",
  );
});

test("fails closed when an activity no longer has its authoritative source", async () => {
  await db.collection("funding_transactions").doc("funding-history-1").delete();
  await assert.rejects(
    history.getTransactionDetail({
      actorId: ownerId,
      activityId: "activity-funding",
    }),
    (error) => error.code === "integrity-error",
  );
});

async function seedPersonalHistory() {
  await db.collection("funding_transactions").doc("funding-history-1").set({
    userId: ownerId,
    amountKobo: 125000,
    currency: "NGN",
    status: "succeeded",
    receiptNumber: "HPF-TEST-001",
  });
  await db.collection("healthcare_payments").doc("health-history-1").set({
    userId: ownerId,
    amountKobo: 40000,
    currency: "NGN",
    status: "completed",
    providerId: "history-clinic",
    providerName: "History Clinic",
    flowType: "partner",
    receiptNumber: "HPC-TEST-001",
  });
  await db.collection("scheduled_contributions").doc("saving-history-1").set({
    userId: ownerId,
    amountKobo: 50000,
    currency: "NGN",
    status: "failed",
  });
  await Promise.all([
    writeActivity("activity-funding", {
      activityType: "funding_completed",
      relatedEntityType: "funding_transaction",
      relatedEntityId: "funding-history-1",
      metadata: { amountKobo: 1, currency: "NGN" },
      createdAt: "2026-01-04T12:00:00.000Z",
    }),
    writeActivity("activity-healthcare", {
      activityType: "healthcare_payment_completed",
      relatedEntityType: "healthcare_payment",
      relatedEntityId: "health-history-1",
      metadata: { amountKobo: 40000, currency: "NGN" },
      createdAt: "2026-01-03T12:00:00.000Z",
    }),
    writeActivity("activity-savings-failed", {
      activityType: "scheduled_savings_contribution",
      relatedEntityType: "scheduled_contribution",
      relatedEntityId: "saving-history-1",
      status: "failed",
      metadata: { amountKobo: 50000, currency: "NGN", status: "failed" },
      createdAt: "2026-01-02T12:00:00.000Z",
    }),
  ]);
}

async function seedFamilyHistory() {
  const pocket = db.collection("family_pockets").doc("family-history");
  await pocket.set({ ownerId, status: "active" });
  await pocket.collection("members").doc("family-member").set({
    userId: "family-member",
    status: "active",
    removedAt: null,
    leftAt: null,
  });
  await db.collection("family_contribution_attempts").doc("family-attempt-1").set({
    contributorUserId: ownerId,
    pocketId: "family-history",
    amountKobo: 50000,
    currency: "NGN",
    status: "completed",
  });
  await writeActivity("activity-family", {
    activityType: "family_contribution_completed",
    relatedEntityType: "family_contribution",
    relatedEntityId: "family-attempt-1",
    familyPocketId: "family-history",
    metadata: { amountKobo: 50000, currency: "NGN" },
    createdAt: "2026-01-01T12:00:00.000Z",
  });
}

async function writeActivity(id, value) {
  await db.collection("activities").doc(id).set({
    userId: ownerId,
    ...value,
    createdAt: Timestamp.fromDate(new Date(value.createdAt)),
  });
}
