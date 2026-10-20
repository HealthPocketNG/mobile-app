"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const { buildTrustedBackend } = require("../src/trusted-backend");
const {
  assertVerifiedGoogleIdentity,
} = require("../src/errors/backend-error");

const verifiedAuth = (uid = "user-1") => ({
  uid,
  token: {
    email: `${uid}@example.com`,
    email_verified: true,
    name: "Amara Health",
    firebase: { sign_in_provider: "google.com" },
  },
});

function harness({ moneyEnabled = true, records = {}, rateLimiter } = {}) {
  const calls = [];
  const method = (name) => async (input) => {
    calls.push({ name, input });
    return { name, input };
  };
  const services = {
    ledger: { ensureWallet: method("ensureWallet") },
    payments: {
      initializeFunding: method("initializeFunding"),
      verifyFunding: method("verifyFunding"),
    },
    savings: {
      createPlan: method("createPlan"), updatePlan: method("updatePlan"),
      pausePlan: method("pausePlan"), resumePlan: method("resumePlan"),
      cancelPlan: method("cancelPlan"),
    },
    family: {
      createPocket: method("createPocket"), updatePocket: method("updatePocket"),
      createInvite: method("createInvite"), resolveInviteCode: method("resolveInviteCode"),
      respondToInvite: method("respondToInvite"),
      changeMembership: method("changeMembership"),
      transferOwnership: method("transferOwnership"), closePocket: method("closePocket"),
      initializeContribution: method("initializeContribution"),
      verifyContribution: method("verifyContribution"),
    },
    healthcare: {
      initiatePartnerPayment: method("initiatePartnerPayment"),
      initiateNonPartnerPayment: method("initiateNonPartnerPayment"),
      verifyPayment: method("verifyPayment"),
    },
    coverage: { evaluateCoverage: method("evaluateCoverage") },
    notifications: {
      list: method("notificationList"), markRead: method("markRead"),
      markAllRead: method("markAllRead"), registerDevice: method("registerDevice"),
      removeDevice: method("removeDevice"), refreshDevice: method("refreshDevice"),
    },
    activity: {
      listHistory: method("listHistory"),
      getTransactionDetail: method("getTransactionDetail"),
      prepareStatement: method("prepareStatement"),
    },
    receipts: { getReceipt: method("getReceipt"), exportReceipt: method("exportReceipt") },
  };
  const db = {
    collection(collection) {
      return {
        doc(id) {
          return {
            async get() {
              const data = records[`${collection}/${id}`];
              return { exists: data !== undefined, data: () => data };
            },
          };
        },
      };
    },
  };
  const logs = [];
  const logger = {
    info(event, fields) { logs.push({ level: "info", event, fields }); },
    error(event, fields) { logs.push({ level: "error", event, fields }); },
  };
  return {
    backend: buildTrustedBackend({ db, services, logger, moneyEnabled, rateLimiter }),
    calls,
    logs,
  };
}

test("requires a verified Google identity", async () => {
  const { backend } = harness();
  const request = { data: { action: "wallet.ensure", payload: {} } };
  await assert.rejects(backend.callable(request), (error) => error.code === "unauthenticated");
  await assert.rejects(
    backend.callable({
      ...request,
      auth: { uid: "phone-user", token: {
        email_verified: true,
        firebase: { sign_in_provider: "phone" },
      } },
    }),
    (error) => error.code === "permission-denied",
  );
  assert.equal(assertVerifiedGoogleIdentity(verifiedAuth()).userId, "user-1");
});

test("rate-limits sensitive commands after authentication and validation", async () => {
  const consumed = [];
  const rateLimiter = {
    async consume(input) {
      consumed.push(input);
      const error = new Error("limited");
      error.code = "rate-limited";
      throw error;
    },
  };
  const { backend, calls } = harness({ rateLimiter });
  await assert.rejects(
    backend.callable({
      auth: verifiedAuth("limited-user"),
      data: {
        action: "funding.initialize",
        payload: { amountKobo: 50000, idempotencyKey: "limitedfunding01" },
      },
    }),
    (error) => error.code === "resource-exhausted" &&
      error.details.code === "rate-limited",
  );
  assert.equal(consumed[0].subjectId, "limited-user");
  assert.equal(consumed[0].operation, "funding.initialize");
  assert.equal(calls.length, 0);
});

test("rejects unknown commands, outer pollution and payload mass assignment", async () => {
  const { backend } = harness();
  const auth = verifiedAuth();
  for (const data of [
    { action: "ledger.finalize", payload: {} },
    { action: "wallet.ensure", payload: {}, admin: true },
    { action: "funding.initialize", payload: {
      userId: "victim", amountKobo: 50000, idempotencyKey: "fundingrequest0001",
    } },
  ]) {
    await assert.rejects(
      backend.callable({ auth, data }),
      (error) => error.code === "invalid-argument",
    );
  }
});

test("derives financial ownership from Auth and preserves idempotency input", async () => {
  const { backend, calls } = harness();
  await backend.callable({
    auth: verifiedAuth("owner-1"),
    data: {
      action: "funding.initialize",
      payload: { amountKobo: 50000, idempotencyKey: "fundingrequest0001" },
    },
  });
  assert.deepEqual(calls[0], {
    name: "initializeFunding",
    input: {
      userId: "owner-1",
      amountKobo: 50000,
      idempotencyKey: "fundingrequest0001",
      ledgerSource: "funding",
    },
  });
});

test("money commands fail closed when no regulated adapter is enabled", async () => {
  const { backend, calls } = harness({ moneyEnabled: false });
  await assert.rejects(
    backend.callable({
      auth: verifiedAuth(),
      data: {
        action: "funding.initialize",
        payload: { amountKobo: 50000, idempotencyKey: "fundingrequest0001" },
      },
    }),
    (error) => error.code === "unavailable",
  );
  assert.equal(calls.length, 0);
});

test("invite responses use verified token identity instead of client identity", async () => {
  const { backend, calls } = harness();
  await backend.callable({
    auth: verifiedAuth("invitee-1"),
    data: {
      action: "family.invite_respond",
      payload: { code: "opaque-invite-code", accept: true },
    },
  });
  assert.deepEqual(calls[0].input, {
    code: "opaque-invite-code",
    accept: true,
    userId: "invitee-1",
    userName: "Amara Health",
    email: "invitee-1@example.com",
    emailVerified: true,
  });
});

test("status verification hides other users records and allows the owner", async () => {
  const records = {
    "payment_attempts/owned": { userId: "owner-1" },
    "payment_attempts/foreign": { userId: "other-user" },
  };
  const { backend, calls } = harness({ records });
  await backend.callable({
    auth: verifiedAuth("owner-1"),
    data: { action: "funding.verify", payload: { attemptId: "owned" } },
  });
  assert.equal(calls[0].name, "verifyFunding");
  await assert.rejects(
    backend.callable({
      auth: verifiedAuth("owner-1"),
      data: { action: "funding.verify", payload: { attemptId: "foreign" } },
    }),
    (error) => error.code === "not-found",
  );
});

test("exposes only user-safe actions and writes privacy-safe lifecycle logs", async () => {
  const { backend, logs } = harness();
  assert.ok(backend.actions.length >= 25);
  assert.equal(backend.actions.some((action) =>
    /finalize|reconcile|webhook|seed|admin|dispatch|run_due/.test(action)), false);
  assert.equal(backend.actions.some((action) => /verification.?code/.test(action)), false);
  await backend.callable({
    auth: verifiedAuth(),
    data: { action: "wallet.ensure", payload: {} },
  });
  assert.deepEqual(logs.map((entry) => entry.fields.outcome), ["started", "success"]);
  assert.doesNotMatch(JSON.stringify(logs), /user-1@example|opaque|token|amountKobo/);
});
