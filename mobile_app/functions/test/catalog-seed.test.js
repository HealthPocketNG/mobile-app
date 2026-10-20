"use strict";

const { after, before, beforeEach, test } = require("node:test");
const assert = require("node:assert/strict");
const { deleteApp, initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const {
  applyManifest,
  canonicalChecksum,
  parseArgs,
  validateManifest,
} = require("../scripts/seed-catalogs");

let app;
let db;
const silentLogger = { info() {} };

before(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("Run through Firestore emulator.");
  app = initializeApp({ projectId: "demo-healthpocket" }, "catalog-seed-tests");
  db = getFirestore(app);
});

beforeEach(async () => Promise.all([
  "healthcare_providers",
  "coverage_items",
  "_backend_migrations",
].map((name) => db.recursiveDelete(db.collection(name)))));

after(async () => deleteApp(app));

test("validates manifests without connecting or writing", () => {
  const manifest = validateManifest(sampleManifest());
  assert.deepEqual(manifest.providerIds, ["catalog-clinic"]);
  assert.deepEqual(manifest.itemIds, ["consultation"]);
  assert.equal(canonicalChecksum(manifest).length, 64);
  assert.throws(() => validateManifest({ ...sampleManifest(), releaseId: "BAD ID" }));
  assert.throws(() => validateManifest({
    ...sampleManifest(),
    providers: [provider(), provider()],
  }), /unique/);
});

test("defaults to dry-run arguments and requires explicit apply for deactivation", () => {
  assert.deepEqual(parseArgs(["--file", "catalog.json"]), {
    apply: false,
    deactivateMissing: false,
    file: "catalog.json",
  });
  assert.throws(
    () => parseArgs(["--file", "catalog.json", "--deactivate-missing"]),
    /only valid with --apply/,
  );
});

test("applies a catalog release idempotently and rejects release ID reuse", async () => {
  const manifest = validateManifest(sampleManifest());
  const first = await applyManifest({ db, manifest, logger: silentLogger });
  assert.equal(first.alreadyApplied, false);
  assert.equal((await db.collection("healthcare_providers").get()).size, 1);
  assert.equal((await db.collection("coverage_items").get()).size, 1);

  const repeated = await applyManifest({ db, manifest, logger: silentLogger });
  assert.equal(repeated.alreadyApplied, true);
  await assert.rejects(
    applyManifest({
      db,
      logger: silentLogger,
      manifest: validateManifest({
        ...sampleManifest(),
        coverageItems: [coverageItem({ indicativePriceKobo: 250000 })],
      }),
    }),
    /different catalog data/,
  );
});

function sampleManifest() {
  return {
    schemaVersion: 1,
    releaseId: "catalog-2026-10-20",
    providers: [provider()],
    coverageItems: [coverageItem()],
  };
}

function provider() {
  return {
    id: "catalog-clinic",
    name: "Catalog Clinic",
    category: "clinic",
    partnerStatus: "partner",
    address: "1 Test Road",
    state: "Lagos",
    city: "Ikeja",
    coordinates: { latitude: 6.6018, longitude: 3.3515 },
    contact: {},
    services: ["Consultation"],
    active: true,
  };
}

function coverageItem(overrides = {}) {
  return {
    id: "consultation",
    name: "Consultation",
    category: "consultation",
    indicativePriceKobo: 150000,
    sourceName: "Partner supplied test fixture",
    providerId: "catalog-clinic",
    active: true,
    ...overrides,
  };
}
