"use strict";

const { after, before, beforeEach, test } = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const {
  buildProviderDirectoryService,
} = require("../src/providers/provider-directory-service");

let app;
let db;
let directory;
const admin = { uid: "directory-admin", claims: { admin: true } };
const silentLogger = { info() {} };

before(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("Run these tests through the Firebase Firestore emulator.");
  }
  app = initializeApp({ projectId: "demo-healthpocket" }, "provider-tests");
  db = getFirestore(app);
});

beforeEach(async () => {
  await db.recursiveDelete(db.collection("healthcare_providers"));
  directory = buildProviderDirectoryService({ db, logger: silentLogger });
});

after(async () => deleteApp(app));

function provider(overrides = {}) {
  return {
    id: "lagos-community-clinic",
    name: "Lagos Community Clinic",
    category: "clinic",
    partnerStatus: "partner",
    address: "10 Care Road",
    state: "Lagos",
    city: "Ikeja",
    coordinates: { latitude: 6.6018, longitude: 3.3515 },
    contact: {
      phone: "+2348000000000",
      email: "care@example.test",
      website: "https://example.test/clinic",
    },
    openingInformation: "Open daily, 8am–8pm",
    logoUrl: "https://example.test/logo.png",
    imageUrls: ["https://example.test/provider.jpg"],
    services: ["Consultation", "Diagnostics"],
    active: true,
    ...overrides,
  };
}

test("requires an explicit trusted-admin claim for every mutation", async () => {
  await assert.rejects(
    directory.upsertProvider({
      actor: { uid: "ordinary-user", claims: {} },
      provider: provider(),
    }),
    (error) => error.code === "permission-denied",
  );
  assert.equal((await db.collection("healthcare_providers").get()).empty, true);
});

test("writes the canonical searchable provider document idempotently", async () => {
  const first = await directory.upsertProvider({ actor: admin, provider: provider() });
  const firstSnapshot = await db.collection("healthcare_providers").doc(first.providerId).get();
  await directory.upsertProvider({
    actor: admin,
    provider: provider({ openingInformation: "Open 24 hours" }),
  });
  const saved = (await firstSnapshot.ref.get()).data();

  assert.equal(first.providerId, "lagos-community-clinic");
  assert.equal(saved.schemaVersion, 1);
  assert.equal(saved.normalizedName, "lagos community clinic");
  assert.equal(saved.partnerStatus, "partner");
  assert.deepEqual(saved.locationCell, ["g_386_733"]);
  assert.ok(saved.searchPrefixes.includes("clin"));
  assert.equal(saved.openingInformation, "Open 24 hours");
  assert.equal(saved.createdAt.toMillis(), firstSnapshot.data().createdAt.toMillis());
  assert.ok(saved.updatedAt.toMillis() >= saved.createdAt.toMillis());
});

test("supports every approved category plus non-partner providers", async () => {
  for (const category of ["hospital", "clinic", "pharmacy", "diagnostics", "other"]) {
    await directory.upsertProvider({
      actor: admin,
      provider: provider({
        id: `${category}-provider`,
        name: `${category} provider`,
        category,
        partnerStatus: "non_partner",
      }),
    });
  }
  const snapshot = await db.collection("healthcare_providers").get();
  assert.deepEqual(
    new Set(snapshot.docs.map((document) => document.data().category)),
    new Set(["hospital", "clinic", "pharmacy", "diagnostics", "other"]),
  );
  assert.ok(snapshot.docs.every((document) =>
    document.data().partnerStatus === "non_partner"));
});

test("rejects invalid coordinates, contact URLs and unsupported categories", async () => {
  await assert.rejects(
    directory.upsertProvider({
      actor: admin,
      provider: provider({ coordinates: { latitude: 91, longitude: 3 } }),
    }),
    (error) => error.code === "invalid-argument",
  );
  await assert.rejects(
    directory.upsertProvider({
      actor: admin,
      provider: provider({ logoUrl: "http://insecure.example/logo.png" }),
    }),
    (error) => error.code === "invalid-argument",
  );
  await assert.rejects(
    directory.upsertProvider({
      actor: admin,
      provider: provider({ category: "spa" }),
    }),
    (error) => error.code === "invalid-argument",
  );
});

test("deactivates and reactivates without deleting provider history", async () => {
  const { providerId } = await directory.upsertProvider({ actor: admin, provider: provider() });
  await directory.setProviderActive({ actor: admin, providerId, active: false });
  let saved = (await db.collection("healthcare_providers").doc(providerId).get()).data();
  assert.equal(saved.active, false);
  assert.ok(saved.deactivatedAt);
  assert.equal(saved.name, "Lagos Community Clinic");

  await directory.setProviderActive({ actor: admin, providerId, active: true });
  saved = (await db.collection("healthcare_providers").doc(providerId).get()).data();
  assert.equal(saved.active, true);
  assert.equal(saved.deactivatedAt, null);
  assert.equal(saved.name, "Lagos Community Clinic");
});

test("seed can deactivate missing records while preserving them", async () => {
  await directory.upsertProvider({ actor: admin, provider: provider() });
  const result = await directory.seedProviders({
    actor: admin,
    deactivateMissing: true,
    entries: [provider({
      id: "abuja-diagnostics",
      name: "Abuja Diagnostics",
      category: "diagnostics",
      state: "FCT",
      city: "Abuja",
      coordinates: { latitude: 9.0765, longitude: 7.3986 },
    })],
  });
  assert.deepEqual(result, { providerCount: 1, deactivatedCount: 1 });
  const old = await db.collection("healthcare_providers")
    .doc("lagos-community-clinic").get();
  assert.equal(old.exists, true);
  assert.equal(old.data().active, false);
});
