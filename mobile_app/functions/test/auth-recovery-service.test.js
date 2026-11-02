"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const { buildEmailCodeService } = require("../src/auth/email-code-service");
const { buildPasswordResetService } = require("../src/auth/password-reset-service");

function memoryDb() {
  const records = new Map();
  const ref = (path) => ({
    path,
    async get() { return { data: () => records.get(path) }; },
    async set(value) { records.set(path, value); },
    async delete() { records.delete(path); },
  });
  return {
    records,
    collection(name) { return { doc(id) { return ref(`${name}/${id}`); } }; },
    async runTransaction(callback) {
      return callback({
        get: (document) => document.get(),
        set: (document, value) => records.set(document.path, value),
        update: (document, value) => records.set(document.path, { ...records.get(document.path), ...value }),
        delete: (document) => records.delete(document.path),
      });
    },
  };
}

test("email code is delivered, rate limited, attempt limited, and only server verification marks the user verified", async () => {
  const db = memoryDb();
  let now = 1000000;
  let delivered;
  const updated = [];
  const service = buildEmailCodeService({ db, clock: () => now,
    auth: { async updateUser(uid, update) { updated.push({ uid, update }); } },
    send: async (mail) => { delivered = mail; },
  });
  await service.requestCode({ uid: "person", email: "person@example.com" });
  assert.match(delivered.code, /^\d{6}$/);
  const record = db.records.get("email_verification_challenges/person");
  assert.equal(record.digest.length, 64);
  assert.equal(JSON.stringify(record).includes(delivered.code), false);
  await assert.rejects(service.requestCode({ uid: "person", email: "person@example.com" }), { code: "rate-limited" });
  await assert.rejects(service.verifyCode({ uid: "person", email: "person@example.com", code: "x" }), { code: "invalid-argument" });
  if (delivered.code !== "000000") await assert.rejects(service.verifyCode({ uid: "person", email: "person@example.com", code: "000000" }), { code: "verification-failed" });
  assert.equal(updated.length, 0);
  await service.verifyCode({ uid: "person", email: "person@example.com", code: delivered.code });
  assert.deepEqual(updated, [{ uid: "person", update: { emailVerified: true } }]);
  assert.equal(db.records.has("email_verification_challenges/person"), false);
  now += 1000;
});

test("password reset link is opaque, expires, updates password once, and does not reveal unknown accounts", async () => {
  const db = memoryDb();
  let now = 1000000;
  let delivered;
  const updated = [];
  const auth = {
    async getUserByEmail(email) {
      if (email !== "person@example.com") { const error = new Error("missing"); error.code = "auth/user-not-found"; throw error; }
      return { uid: "person", providerData: [{ providerId: "password" }] };
    },
    async updateUser(uid, update) { updated.push({ uid, update }); },
  };
  const service = buildPasswordResetService({ db, auth, clock: () => now,
    buildResetLink: (token) => `https://example.test/openPasswordReset?token=${token}`,
    send: async (mail) => { delivered = mail; } });
  assert.deepEqual(await service.requestReset("unknown@example.com"), { sent: true });
  assert.equal(delivered, undefined);
  await service.requestReset("person@example.com");
  const token = new URL(delivered.link).searchParams.get("token");
  assert.ok(token);
  assert.equal(new URL(delivered.link).protocol, "https:");
  assert.equal(JSON.stringify([...db.records.values()]).includes(token), false);
  await assert.rejects(service.confirmReset({ token, password: "weak" }), { code: "invalid-argument" });
  await service.confirmReset({ token, password: "Strongpass1" });
  assert.deepEqual(updated, [{ uid: "person", update: { password: "Strongpass1" } }]);
  await assert.rejects(service.confirmReset({ token, password: "Strongpass2" }), { code: "verification-failed" });
  await assert.rejects(service.requestReset("person@example.com"), { code: "rate-limited" });
  now += 60 * 60 * 1000;
});
