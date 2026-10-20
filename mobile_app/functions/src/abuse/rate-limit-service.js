"use strict";

const { createHash } = require("node:crypto");
const { Timestamp } = require("firebase-admin/firestore");

const SAFE_OPERATION = /^[a-z][a-z0-9_.]{2,63}$/;
const MAX_RULES = 4;

class RateLimitError extends Error {
  constructor(retryAfterSeconds) {
    super("Too many attempts. Please wait before trying again.");
    this.name = "RateLimitError";
    this.code = "rate-limited";
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

function buildRateLimitService({ db, clock = () => new Date(), logger = console }) {
  if (!db || typeof db.runTransaction !== "function") {
    throw new TypeError("A Firestore Admin database is required.");
  }
  const buckets = db.collection("_rate_limits");

  async function consume({ subjectId, operation, rules }) {
    requireSubject(subjectId);
    if (!SAFE_OPERATION.test(operation || "")) throw new TypeError("Operation is invalid.");
    const normalizedRules = normalizeRules(rules);
    if (normalizedRules.length === 0) return { allowed: true };
    const now = requireDate(clock());
    const subjectHash = hash(subjectId);
    const targets = normalizedRules.map((rule) => {
      const windowStartMs = Math.floor(now.getTime() / rule.windowMs) * rule.windowMs;
      const id = hash(`${subjectHash}:${operation}:${rule.windowMs}:${windowStartMs}`);
      return { rule, windowStartMs, reference: buckets.doc(`rate_${id.slice(0, 56)}`) };
    });

    const result = await db.runTransaction(async (transaction) => {
      const snapshots = await Promise.all(
        targets.map(({ reference }) => transaction.get(reference)),
      );
      let retryAfterSeconds = 0;
      snapshots.forEach((snapshot, index) => {
        const current = snapshot.exists ? snapshot.data().count : 0;
        if (!Number.isSafeInteger(current) || current < 0) {
          throw new TypeError("Rate-limit bucket is corrupt.");
        }
        if (current >= targets[index].rule.maxAttempts) {
          const end = targets[index].windowStartMs + targets[index].rule.windowMs;
          retryAfterSeconds = Math.max(
            retryAfterSeconds,
            Math.max(1, Math.ceil((end - now.getTime()) / 1000)),
          );
        }
      });
      if (retryAfterSeconds > 0) return { allowed: false, retryAfterSeconds };
      targets.forEach(({ rule, windowStartMs, reference }, index) => {
        transaction.set(reference, {
          schemaVersion: 1,
          subjectHash,
          operation,
          windowMs: rule.windowMs,
          windowStartedAt: Timestamp.fromMillis(windowStartMs),
          expiresAt: Timestamp.fromMillis(windowStartMs + rule.windowMs * 2),
          count: (snapshots[index].exists ? snapshots[index].data().count : 0) + 1,
          updatedAt: Timestamp.fromDate(now),
        });
      });
      return { allowed: true };
    });
    if (!result.allowed) {
      logger.warn?.("healthpocket_backend", {
        component: "rate_limit",
        operation,
        outcome: "blocked",
      });
      throw new RateLimitError(result.retryAfterSeconds);
    }
    return result;
  }

  return { consume };
}

function normalizeRules(rules) {
  if (!Array.isArray(rules) || rules.length > MAX_RULES) {
    throw new TypeError("Rate-limit rules are invalid.");
  }
  return rules.map((rule) => {
    if (!rule || !Number.isInteger(rule.maxAttempts) || rule.maxAttempts < 1 ||
        rule.maxAttempts > 10000 || !Number.isInteger(rule.windowSeconds) ||
        rule.windowSeconds < 1 || rule.windowSeconds > 86400 * 31) {
      throw new TypeError("Rate-limit rule is invalid.");
    }
    return { maxAttempts: rule.maxAttempts, windowMs: rule.windowSeconds * 1000 };
  });
}

function requireSubject(value) {
  if (typeof value !== "string" || value.length < 1 || value.length > 256) {
    throw new TypeError("Rate-limit subject is invalid.");
  }
}

function requireDate(value) {
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) {
    throw new TypeError("Rate-limit clock is invalid.");
  }
  return new Date(value.getTime());
}

function hash(value) {
  return createHash("sha256").update(value).digest("hex");
}

module.exports = { buildRateLimitService, RateLimitError };
