"use strict";

const { after, before, beforeEach, test } = require("node:test");
const assert = require("node:assert/strict");
const { deleteApp, initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const {
  buildRateLimitService,
} = require("../src/abuse/rate-limit-service");

let app;
let db;
let now;
let limiter;

before(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("Run through Firestore emulator.");
  app = initializeApp({ projectId: "demo-healthpocket" }, "rate-limit-tests");
  db = getFirestore(app);
});

beforeEach(async () => {
  await db.recursiveDelete(db.collection("_rate_limits"));
  now = new Date("2026-10-20T08:00:00.000Z");
  limiter = buildRateLimitService({
    db,
    clock: () => now,
    logger: { warn() {} },
  });
});

after(async () => deleteApp(app));

test("atomically enforces burst limits without storing the user ID", async () => {
  const request = {
    subjectId: "sensitive-user-1",
    operation: "funding.initialize",
    rules: [{ maxAttempts: 2, windowSeconds: 60 }],
  };
  await limiter.consume(request);
  await limiter.consume(request);
  await assert.rejects(
    limiter.consume(request),
    (error) => error.code === "rate-limited" && error.retryAfterSeconds === 60,
  );
  const buckets = await db.collection("_rate_limits").get();
  assert.equal(buckets.size, 1);
  assert.equal(buckets.docs[0].data().count, 2);
  assert.notEqual(buckets.docs[0].data().subjectHash, request.subjectId);
  assert.doesNotMatch(JSON.stringify(buckets.docs[0].data()), /sensitive-user-1/);
});

test("isolates operations and allows requests after the fixed window", async () => {
  const rule = [{ maxAttempts: 1, windowSeconds: 60 }];
  await limiter.consume({ subjectId: "user-a", operation: "family.invite_create", rules: rule });
  await limiter.consume({ subjectId: "user-a", operation: "funding.initialize", rules: rule });
  await limiter.consume({ subjectId: "user-b", operation: "family.invite_create", rules: rule });
  now = new Date(now.getTime() + 60000);
  await limiter.consume({ subjectId: "user-a", operation: "family.invite_create", rules: rule });
});

test("fails closed for malformed policy definitions", async () => {
  await assert.rejects(
    limiter.consume({
      subjectId: "user-a",
      operation: "funding.initialize",
      rules: [{ maxAttempts: 0, windowSeconds: 60 }],
    }),
    /rule is invalid/,
  );
});
