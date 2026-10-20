"use strict";

const { after, before, beforeEach, test } = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const {
  buildCoverageService,
  normalizeItem,
} = require("../src/coverage/coverage-service");

let app;
let db;
let coverage;
const admin = { uid: "coverage-admin", claims: { admin: true } };
const silentLogger = { info() {} };
const userId = "coverage-user";

before(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("Run through the Firestore emulator.");
  app = initializeApp({ projectId: "demo-healthpocket" }, "coverage-tests");
  db = getFirestore(app);
});

beforeEach(async () => {
  await Promise.all([
    db.recursiveDelete(db.collection("coverage_items")),
    db.recursiveDelete(db.collection("wallets")),
  ]);
  coverage = buildCoverageService({
    db,
    logger: silentLogger,
    clock: () => new Date("2026-10-19T14:00:00.000Z"),
  });
});

after(async () => deleteApp(app));

test("requires trusted admin authority for remote catalog maintenance", async () => {
  await assert.rejects(
    coverage.upsertItem({ actor: { uid: userId, claims: {} }, item: item() }),
    (error) => error.code === "permission-denied",
  );
  assert.equal((await db.collection("coverage_items").get()).empty, true);
});

test("validates a canonical indicative-price model in integer kobo", () => {
  const normalized = normalizeItem(item());
  assert.equal(normalized.indicativePriceKobo, 150000);
  assert.equal(normalized.currency, "NGN");
  assert.equal(normalized.priceType, "indicative_estimate");
  assert.match(normalized.disclaimer, /Indicative estimate only/);
  assert.throws(() => normalizeItem(item({ indicativePriceKobo: 12.5 })), /integer kobo/);
  assert.throws(() => normalizeItem(item({ indicativePriceKobo: 0 })), /integer kobo/);
});

test("seeds five remotely maintainable items and deactivates stale pricing", async () => {
  const result = await coverage.seedItems({ actor: admin, entries: fiveItems() });
  assert.deepEqual(result, { itemCount: 5, deactivatedCount: 0 });
  const before = await db.collection("coverage_items").get();
  assert.equal(before.size, 5);
  assert.ok(before.docs.every((document) => document.data().lastUpdatedAt instanceof Timestamp));

  const reduced = await coverage.seedItems({
    actor: admin,
    entries: fiveItems().slice(0, 4),
    deactivateMissing: true,
  });
  assert.deepEqual(reduced, { itemCount: 4, deactivatedCount: 1 });
  const stale = await db.collection("coverage_items").doc("eye-exam").get();
  assert.equal(stale.exists, true);
  assert.equal(stale.data().active, false);
  assert.ok(stale.data().deactivatedAt);
});

test("derives zero-balance encouragement without claiming affordability", async () => {
  await coverage.seedItems({ actor: admin, entries: fiveItems() });
  await seedWallet(0);
  const result = await coverage.evaluateCoverage({ actorId: userId });
  assert.equal(result.state, "zero_balance");
  assert.match(result.message, /Start saving/);
  assert.equal(result.coverageItems.length, 5);
  assert.ok(result.coverageItems.every((entry) => !entry.covered));
  assert.ok(result.coverageItems.every((entry) => entry.amountRemainingKobo === 0));
});

test("calculates low, sufficient, and high balance coverage from the authoritative wallet", async () => {
  await coverage.seedItems({ actor: admin, entries: fiveItems() });
  await seedWallet(200000);
  let result = await coverage.evaluateCoverage({ actorId: userId });
  assert.equal(result.state, "covers_some_listed");
  assert.deepEqual(
    result.coverageItems.map((entry) => [entry.indicativePriceKobo, entry.covered]),
    [[100000, true], [150000, true], [250000, false], [400000, false], [600000, false]],
  );
  assert.equal(result.coverageItems[1].amountRemainingKobo, 50000);
  assert.equal(result.coverageItems[2].shortfallKobo, 50000);

  await db.collection("wallets").doc(userId).update({ availableBalanceKobo: 250000 });
  result = await coverage.evaluateCoverage({ actorId: userId });
  assert.equal(result.coverageItems.find((entry) => entry.indicativePriceKobo === 250000).covered, true);

  await db.collection("wallets").doc(userId).update({ availableBalanceKobo: 1000000 });
  result = await coverage.evaluateCoverage({ actorId: userId });
  assert.equal(result.state, "covers_all_listed");
});

test("excludes inactive prices and returns a clean empty catalog state", async () => {
  const { itemId } = await coverage.upsertItem({ actor: admin, item: item() });
  await seedWallet(500000);
  await coverage.setItemActive({ actor: admin, itemId, active: false });
  const result = await coverage.evaluateCoverage({ actorId: userId });
  assert.equal(result.empty, true);
  assert.equal(result.state, "empty_catalog");
  assert.deepEqual(result.coverageItems, []);
});

test("fails closed for missing, unavailable, or corrupt wallets", async () => {
  await assert.rejects(
    coverage.evaluateCoverage({ actorId: userId }),
    (error) => error.code === "wallet-not-found",
  );
  await seedWallet(100000, "restricted");
  await assert.rejects(
    coverage.evaluateCoverage({ actorId: userId }),
    (error) => error.code === "wallet-unavailable",
  );
  await db.collection("wallets").doc(userId).update({
    status: "active", availableBalanceKobo: -1,
  });
  await assert.rejects(
    coverage.evaluateCoverage({ actorId: userId }),
    (error) => error.code === "integrity-error",
  );
});

function item(overrides = {}) {
  return {
    id: "general-consultation",
    name: "General consultation",
    category: "consultation",
    indicativePriceKobo: 150000,
    sourceName: "Partner supplied MVP catalog",
    sourceReference: "partner-catalog-row-1",
    providerId: "lagos-community-clinic",
    locationContext: { state: "Lagos", city: "Ikeja" },
    active: true,
    ...overrides,
  };
}

function fiveItems() {
  return [
    item({ id: "basic-medication", name: "Basic medication basket", category: "pharmacy", indicativePriceKobo: 100000 }),
    item(),
    item({ id: "basic-lab-panel", name: "Basic laboratory panel", category: "diagnostics", indicativePriceKobo: 250000 }),
    item({ id: "dental-checkup", name: "Dental check-up", category: "dental", indicativePriceKobo: 400000 }),
    item({ id: "eye-exam", name: "Eye examination", category: "vision", indicativePriceKobo: 600000 }),
  ];
}

async function seedWallet(balance, status = "active") {
  await db.collection("wallets").doc(userId).set({
    schemaVersion: 1,
    userId,
    currency: "NGN",
    availableBalanceKobo: balance,
    status,
    version: 1,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });
}
