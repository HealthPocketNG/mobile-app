"use strict";

const { createHash, randomBytes, timingSafeEqual } = require("node:crypto");
const { getAuth } = require("firebase-admin/auth");
const { BackendError } = require("../errors/backend-error");

const CODE_LIFETIME_MS = 10 * 60 * 1000;
const RESEND_COOLDOWN_MS = 45 * 1000;
const MAX_REQUESTS_PER_HOUR = 5;
const MAX_ATTEMPTS = 5;

function buildEmailCodeService({ db, auth = getAuth(), send, clock = () => Date.now() }) {
  if (!db || !auth || typeof send !== "function") throw new TypeError("Email verification dependencies are required.");

  async function requestCode({ uid, email }) {
    const now = clock();
    const code = String(randomBytes(4).readUInt32BE() % 1000000).padStart(6, "0");
    const salt = randomBytes(16).toString("hex");
    const ref = db.collection("email_verification_challenges").doc(uid);
    await db.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      const previous = snapshot.data();
      if (previous?.resendAvailableAt > now) throw new BackendError("rate-limited");
      const windowStart = previous?.windowStart > now - 60 * 60 * 1000 ? previous.windowStart : now;
      const requests = windowStart === previous?.windowStart ? previous.requests + 1 : 1;
      if (requests > MAX_REQUESTS_PER_HOUR) throw new BackendError("rate-limited");
      tx.set(ref, {
        email,
        salt,
        digest: digest(uid, code, salt),
        expiresAt: now + CODE_LIFETIME_MS,
        resendAvailableAt: now + RESEND_COOLDOWN_MS,
        attempts: 0,
        requests,
        windowStart,
      });
    });
    try {
      await send({ to: email, code });
    } catch (error) {
      await ref.delete();
      throw error;
    }
    return { expiresAt: now + CODE_LIFETIME_MS, resendAvailableAt: now + RESEND_COOLDOWN_MS };
  }

  async function verifyCode({ uid, email, code }) {
    if (!/^\d{6}$/.test(code)) throw new BackendError("invalid-argument");
    const ref = db.collection("email_verification_challenges").doc(uid);
    const result = await db.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      const challenge = snapshot.data();
      if (!challenge || challenge.email !== email || challenge.expiresAt <= clock() || challenge.attempts >= MAX_ATTEMPTS) {
        throw new BackendError("verification-failed");
      }
      const expected = Buffer.from(challenge.digest, "hex");
      const candidate = Buffer.from(digest(uid, code, challenge.salt), "hex");
      if (!timingSafeEqual(expected, candidate)) {
        tx.update(ref, { attempts: challenge.attempts + 1 });
        return false;
      }
      return true;
    });
    if (!result) throw new BackendError("verification-failed");
    await auth.updateUser(uid, { emailVerified: true });
    await ref.delete();
    return { verified: true };
  }

  return { requestCode, verifyCode };
}

function digest(uid, code, salt) {
  return createHash("sha256").update(`${uid}:${salt}:${code}`).digest("hex");
}

module.exports = { buildEmailCodeService };
