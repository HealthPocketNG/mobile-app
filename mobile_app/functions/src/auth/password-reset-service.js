"use strict";

const { createHash, randomBytes } = require("node:crypto");
const { BackendError } = require("../errors/backend-error");

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const TTL_MS = 30 * 60 * 1000;
const WINDOW_MS = 60 * 60 * 1000;

function buildPasswordResetService({ db, auth, send, buildResetLink, clock = () => Date.now() }) {
  if (!db || !auth || typeof send !== "function") throw new TypeError("Password reset dependencies are required.");

  async function requestReset(emailInput) {
    const email = typeof emailInput === "string" ? emailInput.trim().toLowerCase() : "";
    if (email.length > 254 || !EMAIL.test(email)) throw new BackendError("invalid-argument");
    const now = clock();
    const emailHash = hash(email);
    const limitRef = db.collection("password_reset_limits").doc(emailHash);
    await db.runTransaction(async (tx) => {
      const previous = (await tx.get(limitRef)).data();
      const windowStart = previous?.windowStart > now - WINDOW_MS ? previous.windowStart : now;
      const requests = windowStart === previous?.windowStart ? previous.requests + 1 : 1;
      if (requests > 3 || previous?.lastRequestedAt > now - 45 * 1000) throw new BackendError("rate-limited");
      tx.set(limitRef, { windowStart, requests, lastRequestedAt: now });
    });
    let user;
    try { user = await auth.getUserByEmail(email); }
    catch (error) { if (error.code === "auth/user-not-found") return { sent: true }; throw error; }
    if (user.providerData.length > 0 && !user.providerData.some((provider) => provider.providerId === "password")) return { sent: true };
    const token = randomBytes(32).toString("base64url");
    const tokenRef = db.collection("password_reset_tokens").doc(hash(token));
    await tokenRef.set({ uid: user.uid, expiresAt: now + TTL_MS, consumed: false });
    try {
      await send({ to: email, link: buildResetLink ? buildResetLink(token) : `healthpocket://reset-password?token=${encodeURIComponent(token)}` });
    } catch (error) { await tokenRef.delete(); throw error; }
    return { sent: true };
  }

  async function confirmReset({ token, password }) {
    if (typeof token !== "string" || !/^[A-Za-z0-9_-]{40,60}$/.test(token) ||
        typeof password !== "string" || password.length < 8 || password.length > 128 ||
        !/[A-Z]/.test(password) || !/[0-9]/.test(password)) {
      throw new BackendError("invalid-argument");
    }
    const ref = db.collection("password_reset_tokens").doc(hash(token));
    const uid = await db.runTransaction(async (tx) => {
      const data = (await tx.get(ref)).data();
      if (!data || data.consumed || data.expiresAt <= clock()) throw new BackendError("verification-failed");
      tx.update(ref, { consumed: true, consumedAt: clock() });
      return data.uid;
    });
    await auth.updateUser(uid, { password });
    return { updated: true };
  }

  return { requestReset, confirmReset };
}

function hash(value) { return createHash("sha256").update(value).digest("hex"); }

module.exports = { buildPasswordResetService };
