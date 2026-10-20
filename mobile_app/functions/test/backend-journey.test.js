"use strict";

const { after, before, beforeEach, test } = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { buildLedgerService } = require("../src/ledger-service");
const { buildPaymentService } = require("../src/payments/payment-service");
const { MockPaymentGateway } = require("../src/payments/mock-payment-gateway");
const { buildSavingsPlanService } = require("../src/savings/savings-plan-service");
const { buildFamilyPocketService } = require("../src/family/family-pocket-service");
const {
  buildHealthcarePaymentService,
} = require("../src/healthcare/healthcare-payment-service");
const {
  MockAccountResolutionService,
  MockHealthcareEligibilityService,
} = require("../src/healthcare/mock-healthcare-verification");
const { buildCoverageService } = require("../src/coverage/coverage-service");
const {
  buildNotificationService,
} = require("../src/notifications/notification-service");
const {
  MockPushNotificationService,
} = require("../src/notifications/mock-push-notification-service");
const {
  buildActivityHistoryService,
} = require("../src/activity/activity-history-service");
const { buildReceiptService } = require("../src/receipts/receipt-service");
const {
  buildProviderDirectoryService,
} = require("../src/providers/provider-directory-service");
const { buildTrustedBackend } = require("../src/trusted-backend");

const COLLECTIONS = [
  "_rate_limits",
  "activities",
  "family_contribution_attempts",
  "family_invite_codes",
  "family_invite_keys",
  "family_ledger_entries",
  "family_pockets",
  "financial_operations",
  "funding_transactions",
  "healthcare_payments",
  "healthcare_providers",
  "ledger_entries",
  "notification_devices",
  "notification_events",
  "payment_attempts",
  "personal_health_pockets",
  "provider_events",
  "receipts",
  "savings_plan_operations",
  "savings_plans",
  "scheduled_contributions",
  "coverage_items",
  "wallets",
];

const silentLogger = { info() {}, error() {}, warn() {} };
const adminActor = { uid: "journey-admin", claims: { admin: true } };
let app;
let db;
let gateway;
let healthcareVerifier;
let backend;
let directory;
let services;
let currentTime;

before(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("Run these tests through the Firebase Firestore emulator.");
  }
  app = initializeApp({ projectId: "demo-healthpocket" }, "backend-journey-tests");
  db = getFirestore(app);
});

beforeEach(async () => {
  await Promise.all(COLLECTIONS.map((name) => db.recursiveDelete(db.collection(name))));

  const ledger = buildLedgerService({ db, logger: silentLogger });
  gateway = new MockPaymentGateway();
  const payments = buildPaymentService({ db, ledger, gateway, logger: silentLogger });
  const accountResolver = new MockAccountResolutionService();
  healthcareVerifier = new MockHealthcareEligibilityService();
  currentTime = new Date("2026-10-20T12:00:00.000Z");
  services = {
    ledger,
    payments,
    savings: buildSavingsPlanService({
      db,
      payments,
      clock: () => new Date(currentTime),
      logger: silentLogger,
    }),
    family: buildFamilyPocketService({ db, gateway, logger: silentLogger }),
    healthcare: buildHealthcarePaymentService({
      db,
      payments,
      accountResolver,
      healthcareVerifier,
      logger: silentLogger,
    }),
    coverage: buildCoverageService({ db, logger: silentLogger }),
    notifications: buildNotificationService({
      db,
      push: new MockPushNotificationService(),
      logger: silentLogger,
    }),
    activity: buildActivityHistoryService({ db, logger: silentLogger }),
    receipts: buildReceiptService({ db, logger: silentLogger }),
  };
  directory = buildProviderDirectoryService({ db, logger: silentLogger });
  backend = buildTrustedBackend({
    db,
    services,
    logger: silentLogger,
    moneyEnabled: true,
  });
});

after(async () => deleteApp(app));

function verifiedAuth(uid) {
  return {
    uid,
    token: {
      email: `${uid}@example.com`,
      email_verified: true,
      name: `Test ${uid}`,
      firebase: { sign_in_provider: "google.com" },
    },
  };
}

function call(uid, action, payload = {}) {
  return backend.callable({ auth: verifiedAuth(uid), data: { action, payload } });
}

async function seedProvider({ id, partnerStatus }) {
  await directory.upsertProvider({
    actor: adminActor,
    provider: {
      id,
      name: partnerStatus === "partner" ? "Journey Clinic" : "Journey Pharmacy",
      category: partnerStatus === "partner" ? "clinic" : "pharmacy",
      partnerStatus,
      state: "Lagos",
      city: "Ikeja",
      address: "1 Emulator Road",
      coordinates: { latitude: 6.6018, longitude: 3.3515 },
      contact: {},
      services: ["Primary care"],
      imageUrls: [],
      active: true,
    },
  });
}

async function fundWallet(uid, amountKobo, key) {
  await call(uid, "wallet.ensure");
  const initialized = await call(uid, "funding.initialize", {
    amountKobo,
    idempotencyKey: key,
  });
  gateway.setNextOutcome("verifyFunding", "success");
  const completed = await call(uid, "funding.verify", {
    attemptId: initialized.attemptId,
  });
  return { initialized, completed };
}

async function provisionSavingsUser(uid) {
  const pocketId = `personal-${uid}`;
  await Promise.all([
    call(uid, "wallet.ensure"),
    db.collection("personal_health_pockets").doc(pocketId).set({
      schemaVersion: 1,
      userId: uid,
      currency: "NGN",
      status: "active",
      createdAt: Timestamp.fromDate(currentTime),
      updatedAt: Timestamp.fromDate(currentTime),
    }),
  ]);
  return pocketId;
}

function coverageItems() {
  const item = (id, name, category, indicativePriceKobo) => ({
    id,
    name,
    category,
    indicativePriceKobo,
    sourceName: "Journey partner catalog",
    sourceReference: `journey-${id}`,
    providerId: "journey-clinic",
    locationContext: { state: "Lagos", city: "Ikeja" },
    active: true,
  });
  return [
    item("basic-medication", "Basic medication basket", "pharmacy", 100000),
    item("consultation", "General consultation", "consultation", 150000),
    item("lab-panel", "Basic laboratory panel", "diagnostics", 250000),
    item("dental-check", "Dental check-up", "dental", 400000),
    item("eye-exam", "Eye examination", "vision", 600000),
  ];
}

test("user funds a wallet, safely retries, then reads activity, notification and receipt", async () => {
  const uid = "journey-funding-user";
  const { initialized, completed } = await fundWallet(
    uid,
    500000,
    "journeyfunding0001",
  );
  const retry = await call(uid, "funding.verify", { attemptId: initialized.attemptId });

  assert.equal(completed.status, "succeeded");
  assert.equal(retry.ledgerOperationId, completed.ledgerOperationId);
  assert.equal((await db.collection("ledger_entries").get()).size, 1);
  assert.equal((await db.collection("wallets").doc(uid).get()).data().availableBalanceKobo, 500000);

  const history = await call(uid, "activity.list", { pageSize: 10 });
  assert.equal(history.items.length, 1);
  assert.equal(history.items[0].activityType, "funding_completed");
  assert.equal(history.items[0].signedAmountKobo, 500000);

  const notices = await call(uid, "notifications.list", { pageSize: 10 });
  assert.equal(notices.notifications.length, 1);
  assert.equal(notices.notifications[0].category, "funding");

  const funding = (await db.collection("funding_transactions")
    .doc(initialized.attemptId).get()).data();
  const receipt = await call(uid, "receipt.get", {
    receiptNumber: funding.receiptNumber,
  });
  assert.equal(receipt.transactionId, initialized.attemptId);
  assert.equal(receipt.amountKobo, 500000);
  const exported = await call(uid, "receipt.export", {
    receiptNumber: funding.receiptNumber,
    format: "json",
  });
  assert.equal(exported.mimeType, "application/json");
  assert.equal(JSON.parse(exported.data).receiptNumber, funding.receiptNumber);

  const filtered = await call(uid, "activity.list", {
    activityType: "funding_completed",
    startDate: new Date(Date.now() - 60 * 60 * 1000),
    endDate: new Date(Date.now() + 60 * 60 * 1000),
    pageSize: 10,
  });
  assert.equal(filtered.items.length, 1);
  const statement = await call(uid, "activity.statement", {
    activityType: "funding_completed",
    startDate: new Date(Date.now() - 60 * 60 * 1000),
    endDate: new Date(Date.now() + 60 * 60 * 1000),
    maxRecords: 10,
  });
  assert.equal(statement.recordCount, 1);
  assert.match(statement.csv, /funding_completed/);

  await assert.rejects(
    call("journey-stranger", "funding.verify", { attemptId: initialized.attemptId }),
    (error) => error.code === "not-found",
  );
  await assert.rejects(
    call("journey-stranger", "receipt.get", { receiptNumber: funding.receiptNumber }),
    (error) => error.code === "not-found",
  );
});

test("funded user completes one partner payment and a rejected non-partner pays nothing", async () => {
  const uid = "journey-care-user";
  await Promise.all([
    seedProvider({ id: "journey-clinic", partnerStatus: "partner" }),
    seedProvider({ id: "journey-pharmacy", partnerStatus: "non_partner" }),
  ]);
  await fundWallet(uid, 700000, "journeycarefund001");

  const partner = await call(uid, "healthcare.partner_initialize", {
    providerId: "journey-clinic",
    amountKobo: 200000,
    idempotencyKey: "journeypartnerpay01",
  });
  gateway.setNextOutcome("verifyTransaction", "success");
  const completed = await call(uid, "healthcare.verify", {
    paymentId: partner.paymentId,
  });
  const retry = await call(uid, "healthcare.verify", { paymentId: partner.paymentId });
  const requestRetry = await call(uid, "healthcare.partner_initialize", {
    providerId: "journey-clinic",
    amountKobo: 200000,
    idempotencyKey: "journeypartnerpay01",
  });
  assert.equal(completed.status, "completed");
  assert.equal(retry.receiptNumber, completed.receiptNumber);
  assert.equal(requestRetry.paymentId, completed.paymentId);

  await assert.rejects(
    call(uid, "healthcare.partner_initialize", {
      providerId: "journey-clinic",
      amountKobo: 600000,
      idempotencyKey: "journeyinsufficient1",
    }),
    (error) => error.details?.code === "insufficient-balance",
  );

  healthcareVerifier.setNextOutcome("rejected");
  const rejected = await call(uid, "healthcare.non_partner_initialize", {
    providerId: "journey-pharmacy",
    amountKobo: 150000,
    idempotencyKey: "journeynonpartner1",
    bankAccount: { accountNumber: "0123456789", bankCode: "044" },
  });
  assert.equal(rejected.status, "failed");
  assert.equal(rejected.verificationStatus, "rejected");

  const nonPartner = await call(uid, "healthcare.non_partner_initialize", {
    providerId: "journey-pharmacy",
    amountKobo: 100000,
    idempotencyKey: "journeynonpartnersuccess",
    bankAccount: { accountNumber: "0123456789", bankCode: "044" },
  });
  gateway.setNextOutcome("verifyTransaction", "success");
  const nonPartnerCompleted = await call(uid, "healthcare.verify", {
    paymentId: nonPartner.paymentId,
  });
  assert.equal(nonPartnerCompleted.status, "completed");
  assert.equal(nonPartnerCompleted.verificationStatus, "verified");

  const providers = await db.collection("healthcare_providers")
    .where("active", "==", true).get();
  assert.deepEqual(
    providers.docs.map((document) => document.data().partnerStatus).sort(),
    ["non_partner", "partner"],
  );
  assert.ok(providers.docs.every((document) =>
    Number.isFinite(document.data().coordinates.latitude) &&
    Number.isFinite(document.data().coordinates.longitude)));

  const wallet = (await db.collection("wallets").doc(uid).get()).data();
  assert.equal(wallet.availableBalanceKobo, 400000);
  assert.equal((await db.collection("ledger_entries").get()).size, 3);
  assert.equal((await db.collection("receipts").get()).size, 3);
  assert.equal((await db.collection("activities").get()).size, 4);
  assert.equal((await db.collection("notification_events").get()).size, 4);
  assert.equal((await db.collection("healthcare_payments").get()).size, 3);
});

test("family owner uploads an image, invites a member, and both contribute concurrently", async () => {
  const ownerId = "journey-family-owner";
  const memberId = "journey-family-member";
  const created = await call(ownerId, "family.create", {
    idempotencyKey: "journeyfamilypocket1",
    name: "Journey Family Care",
    description: "Shared health support",
    imagePath: null,
    frequency: "monthly",
    defaultContributionAmountKobo: 50000,
  });
  const imagePath = `family_pockets/${created.pocketId}/profile/0123456789abcdef0123456789abcdef.webp`;
  await call(ownerId, "family.update", { pocketId: created.pocketId, imagePath });
  const invite = await call(ownerId, "family.invite_create", {
    pocketId: created.pocketId,
    idempotencyKey: "journeyfamilyinvite01",
    inviteeName: "Journey Member",
    email: `${memberId}@example.com`,
    role: "member",
    canContribute: true,
  });
  const preview = await call(memberId, "family.invite_resolve", { code: invite.code });
  assert.equal(preview.pocketName, "Journey Family Care");
  const accepted = await call(memberId, "family.invite_respond", {
    code: invite.code,
    accept: true,
  });
  assert.equal(accepted.status, "accepted");

  const [ownerAttempt, memberAttempt] = await Promise.all([
    call(ownerId, "family.contribution_initialize", {
      pocketId: created.pocketId,
      amountKobo: 250000,
      idempotencyKey: "journeyfamilyownerfund",
    }),
    call(memberId, "family.contribution_initialize", {
      pocketId: created.pocketId,
      amountKobo: 350000,
      idempotencyKey: "journeyfamilymemberfund",
    }),
  ]);
  gateway.setNextOutcome("verifyFunding", "success");
  gateway.setNextOutcome("verifyFunding", "success");
  const [ownerCompleted, memberCompleted] = await Promise.all([
    call(ownerId, "family.contribution_verify", { attemptId: ownerAttempt.attemptId }),
    call(memberId, "family.contribution_verify", { attemptId: memberAttempt.attemptId }),
  ]);
  const retry = await call(ownerId, "family.contribution_verify", {
    attemptId: ownerAttempt.attemptId,
  });

  assert.equal(ownerCompleted.status, "completed");
  assert.equal(memberCompleted.status, "completed");
  assert.equal(retry.status, "completed");
  const pocketRef = db.collection("family_pockets").doc(created.pocketId);
  assert.equal((await pocketRef.get()).data().balanceKobo, 600000);
  assert.equal((await pocketRef.get()).data().imagePath, imagePath);
  assert.equal((await pocketRef.collection("members").doc(memberId).get())
    .data().lifetimeContributionKobo, 350000);
  assert.equal((await db.collection("family_ledger_entries").get()).size, 2);
  assert.deepEqual(await services.family.reconcilePocket(created.pocketId), {
    matches: true,
    expectedBalanceKobo: 600000,
    actualBalanceKobo: 600000,
    entryCount: 2,
  });

  const history = await call(ownerId, "activity.list", {
    familyPocketId: created.pocketId,
    activityType: "family_contribution_completed",
    pageSize: 10,
  });
  assert.equal(history.items.length, 2);
  assert.deepEqual(history.items.map((item) => item.signedAmountKobo).sort(), [250000, 350000]);

  await assert.rejects(
    call("journey-outsider", "activity.list", {
      familyPocketId: created.pocketId,
      pageSize: 10,
    }),
    (error) => error.code === "permission-denied",
  );
  await assert.rejects(
    call("journey-outsider", "family.update", {
      pocketId: created.pocketId,
      name: "Hijacked",
    }),
    (error) => error.code === "permission-denied",
  );
});

test("savings lifecycle runs successful and failed schedules without duplication", async () => {
  const successUser = "journey-savings-success";
  const successPocket = await provisionSavingsUser(successUser);
  const created = await call(successUser, "savings.create", {
    personalHealthPocketId: successPocket,
    contributionAmountKobo: 90000,
    frequency: "daily",
    startDate: currentTime,
    idempotencyKey: "journeysavingscreate1",
  });
  const updated = await call(successUser, "savings.update", {
    contributionAmountKobo: 100000,
    frequency: "daily",
    startDate: currentTime,
    idempotencyKey: "journeysavingsupdate1",
  });
  assert.equal(updated.contributionAmountKobo, 100000);
  assert.equal((await call(successUser, "savings.pause", {
    idempotencyKey: "journeysavingspause01",
  })).status, "paused");
  const resumed = await call(successUser, "savings.resume", {
    idempotencyKey: "journeysavingsresume1",
  });
  assert.equal(resumed.status, "active");

  currentTime = resumed.nextContributionDate;
  gateway.setNextOutcome("verifyFunding", "success");
  const succeeded = await services.savings.processDueContribution({
    planId: created.planId,
    scheduledFor: resumed.nextContributionDate,
  });
  const retry = await services.savings.processDueContribution({
    planId: created.planId,
    scheduledFor: resumed.nextContributionDate,
  });
  assert.equal(succeeded.status, "succeeded");
  assert.equal(retry.ledgerOperationId, succeeded.ledgerOperationId);
  assert.equal((await db.collection("ledger_entries")
    .where("userId", "==", successUser).get()).size, 1);
  assert.equal((await db.collection("notification_events")
    .where("userId", "==", successUser).get()).size, 1);

  const failedUser = "journey-savings-failure";
  const failedPocket = await provisionSavingsUser(failedUser);
  const failedPlan = await call(failedUser, "savings.create", {
    personalHealthPocketId: failedPocket,
    contributionAmountKobo: 75000,
    frequency: "daily",
    startDate: currentTime,
    idempotencyKey: "journeysavingsfailed1",
  });
  gateway.setNextOutcome("initializeFunding", "failure");
  const failed = await services.savings.processDueContribution({
    planId: failedPlan.planId,
    scheduledFor: failedPlan.nextContributionDate,
  });
  assert.equal(failed.status, "failed");
  assert.equal((await db.collection("ledger_entries")
    .where("userId", "==", failedUser).get()).size, 0);
  assert.equal((await db.collection("wallets").doc(failedUser).get())
    .data().availableBalanceKobo, 0);
  assert.equal((await db.collection("notification_events")
    .where("userId", "==", failedUser).get()).size, 1);
});

test("coverage follows zero, low, sufficient and high ledger-backed balances", async () => {
  const uid = "journey-coverage-user";
  await call(uid, "wallet.ensure");
  await services.coverage.seedItems({ actor: adminActor, entries: coverageItems() });

  let result = await call(uid, "coverage.evaluate", { limit: 20 });
  assert.equal(result.state, "zero_balance");

  await services.ledger.processOperation({
    userId: uid,
    idempotencyKey: "coveragejourneylow1",
    direction: "credit",
    amountKobo: 50000,
    source: "mock",
  });
  result = await call(uid, "coverage.evaluate", { limit: 20 });
  assert.equal(result.state, "below_all_estimates");

  await services.ledger.processOperation({
    userId: uid,
    idempotencyKey: "coveragejourneysufficient",
    direction: "credit",
    amountKobo: 200000,
    source: "mock",
  });
  result = await call(uid, "coverage.evaluate", { limit: 20 });
  assert.equal(result.state, "covers_some_listed");
  assert.equal(result.coverageItems.find((item) =>
    item.indicativePriceKobo === 250000).covered, true);

  await services.ledger.processOperation({
    userId: uid,
    idempotencyKey: "coveragejourneyhigh1",
    direction: "credit",
    amountKobo: 750000,
    source: "mock",
  });
  result = await call(uid, "coverage.evaluate", { limit: 20 });
  assert.equal(result.state, "covers_all_listed");
  assert.equal((await services.ledger.reconcileWallet(uid)).matches, true);
});
