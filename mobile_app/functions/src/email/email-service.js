"use strict";

const { createHash } = require("node:crypto");
const { Timestamp } = require("firebase-admin/firestore");
const { EMAIL_DELIVERY_RESULT } = require("./transactional-email-provider");

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const IDEMPOTENCY_KEY = /^[A-Za-z0-9_-]{16,100}$/;
const MAX_ATTEMPTS = 5;
const MAX_BATCH = 100;

const EMAIL_CLASSIFICATION = Object.freeze({
  TRANSACTIONAL: "transactional",
  SECURITY: "security",
  MARKETING: "marketing",
});

const TEMPLATES = Object.freeze({
  welcome: template("transactional", ["firstName"], "Welcome to HealthPocket", ({ firstName }) =>
    `Hi ${firstName}, your HealthPocket account is ready.`),
  funding_outcome: template("transactional", ["outcome"], "HealthPocket funding update", ({ outcome }) =>
    `Your HealthPocket funding request is ${outcome}. Open the app for details.`),
  healthcare_payment_outcome: template("transactional", ["outcome"], "Healthcare payment update", ({ outcome }) =>
    `Your healthcare payment is ${outcome}. Open HealthPocket for details.`),
  savings_contribution_outcome: template("transactional", ["outcome"], "Savings contribution update", ({ outcome }) =>
    `Your scheduled savings contribution is ${outcome}. Open the app for details.`),
  family_invitation: template("transactional", ["inviterName", "pocketName", "inviteUrl"], "You were invited to a Family Pocket", (v) =>
    `${v.inviterName} invited you to ${v.pocketName}. Open this secure link: ${v.inviteUrl}`),
  family_contribution_outcome: template("transactional", ["outcome"], "Family Pocket contribution update", ({ outcome }) =>
    `Your Family Pocket contribution is ${outcome}. Open the app for details.`),
  security_alert: template("security", ["summary"], "HealthPocket security alert", ({ summary }) =>
    `${summary} If this was not you, secure your account immediately.`),
  pin_reset_confirmation: template("security", [], "Your HealthPocket PIN was reset", () =>
    "Your HealthPocket app PIN was reset. If this was not you, secure your account immediately."),
  product_update: template("marketing", ["headline"], "What’s new in HealthPocket", ({ headline }) => headline),
});

const RATE_POLICIES = Object.freeze({
  transactional: { maximum: 50, windowMs: 60 * 60 * 1000 },
  security: { maximum: 5, windowMs: 60 * 60 * 1000 },
  marketing: { maximum: 2, windowMs: 24 * 60 * 60 * 1000 },
});

class EmailServiceError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "EmailServiceError";
    this.code = code;
  }
}

function buildEmailService({ db, provider, clock = () => new Date(), logger = console }) {
  if (!db || typeof db.runTransaction !== "function") {
    throw new TypeError("A Firestore Admin database is required.");
  }
  if (!provider || typeof provider.send !== "function") {
    throw new TypeError("A transactional email provider is required.");
  }
  const outbox = db.collection("email_outbox");
  const limits = db.collection("email_rate_limits");

  async function queueEmail(input) {
    const recipientEmail = normalizeEmail(input?.recipientEmail);
    const eventType = requireTemplate(input?.eventType);
    requireIdempotencyKey(input?.idempotencyKey);
    const definition = TEMPLATES[eventType];
    const variables = normalizeVariables(definition, input.variables || {});
    const classification = definition.classification;
    const consent = input.marketingConsent === true;
    const messageId = `email_${hash({ recipientEmail, eventType, key: input.idempotencyKey }).slice(0, 48)}`;
    const reference = outbox.doc(messageId);
    const fingerprint = hash({ recipientEmail, eventType, variables, classification });
    let result;

    await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(reference);
      if (existing.exists) {
        if (existing.data().requestFingerprint !== fingerprint) {
          throw new EmailServiceError("idempotency-conflict", "Email request key was reused.");
        }
        result = emailResult(messageId, existing.data());
        return;
      }
      const nowDate = nowFrom(clock);
      const now = Timestamp.fromDate(nowDate);
      if (classification === EMAIL_CLASSIFICATION.MARKETING && !consent) {
        const document = outboxDocument({
          recipientEmail, eventType, classification, variables, fingerprint,
          status: "suppressed", now,
        });
        transaction.create(reference, document);
        result = emailResult(messageId, document);
        return;
      }

      const policy = RATE_POLICIES[classification];
      const windowStartMs = Math.floor(nowDate.getTime() / policy.windowMs) * policy.windowMs;
      const bucketId = `email_limit_${hash({ recipientEmail, classification, windowStartMs }).slice(0, 48)}`;
      const bucketRef = limits.doc(bucketId);
      const bucket = await transaction.get(bucketRef);
      const count = bucket.exists ? bucket.data().count : 0;
      if (!Number.isInteger(count) || count < 0) {
        throw new EmailServiceError("integrity-error", "Email rate-limit data is invalid.");
      }
      if (count >= policy.maximum) {
        throw new EmailServiceError("rate-limited", "Email request limit was reached.");
      }
      transaction.set(bucketRef, {
        schemaVersion: 1,
        recipientHash: hash(recipientEmail),
        classification,
        windowStartedAt: Timestamp.fromMillis(windowStartMs),
        windowEndsAt: Timestamp.fromMillis(windowStartMs + policy.windowMs),
        count: count + 1,
        updatedAt: now,
      });
      const document = outboxDocument({
        recipientEmail, eventType, classification, variables, fingerprint,
        status: "queued", now,
      });
      transaction.create(reference, document);
      result = emailResult(messageId, document);
    });
    log(logger, "queue", result.status, { messageId, eventType, classification });
    return result;
  }

  async function dispatchDue({ limit = 50 } = {}) {
    if (!Number.isInteger(limit) || limit < 1 || limit > MAX_BATCH) {
      invalid("limit must be between 1 and 100.");
    }
    const now = Timestamp.fromDate(nowFrom(clock));
    const snapshot = await outbox
      .where("status", "in", ["queued", "retry_scheduled", "sending"])
      .where("nextAttemptAt", "<=", now)
      .orderBy("nextAttemptAt", "asc")
      .limit(limit)
      .get();
    const results = [];
    for (const document of snapshot.docs) {
      results.push(await dispatchMessage(document.id));
    }
    return results;
  }

  async function dispatchMessage(messageId) {
    if (typeof messageId !== "string" || !/^email_[a-f0-9]{48}$/.test(messageId)) {
      invalid("messageId is invalid.");
    }
    const reference = outbox.doc(messageId);
    let claimed = null;
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw new EmailServiceError("not-found", "Email was not found.");
      const message = snapshot.data();
      if (!["queued", "retry_scheduled", "sending"].includes(message.status) ||
          message.nextAttemptAt.toMillis() > nowFrom(clock).getTime()) return;
      const attemptCount = (message.attemptCount || 0) + 1;
      transaction.update(reference, {
        status: "sending",
        attemptCount,
        nextAttemptAt: Timestamp.fromMillis(nowFrom(clock).getTime() + 5 * 60 * 1000),
        updatedAt: Timestamp.fromDate(nowFrom(clock)),
      });
      claimed = { ...message, attemptCount };
    });
    if (!claimed) return { messageId, status: "not_due" };

    const rendered = renderTemplate(claimed.eventType, claimed.variables);
    let delivery;
    try {
      delivery = await provider.send({
        to: claimed.recipientEmail,
        subject: rendered.subject,
        text: rendered.text,
        classification: claimed.classification,
        metadata: { messageId, eventType: claimed.eventType },
      });
    } catch (error) {
      delivery = {
        status: EMAIL_DELIVERY_RESULT.TRANSIENT_FAILURE,
        errorCode: safeErrorCode(error?.code),
      };
    }
    const completedAt = Timestamp.fromDate(nowFrom(clock));
    if (delivery.status === EMAIL_DELIVERY_RESULT.DELIVERED) {
      await reference.update({
        status: "sent",
        provider: provider.name,
        providerMessageId: optionalSafeString(delivery.providerMessageId, 200),
        lastErrorCode: null,
        sentAt: completedAt,
        updatedAt: completedAt,
      });
      log(logger, "dispatch", "sent", { messageId, eventType: claimed.eventType });
      return { messageId, status: "sent" };
    }

    const retryable = delivery.status === EMAIL_DELIVERY_RESULT.TRANSIENT_FAILURE &&
      claimed.attemptCount < MAX_ATTEMPTS;
    const status = retryable ? "retry_scheduled" : "permanent_failure";
    await reference.update({
      status,
      provider: provider.name,
      providerMessageId: null,
      lastErrorCode: safeErrorCode(delivery.errorCode),
      nextAttemptAt: retryable
        ? Timestamp.fromMillis(completedAt.toMillis() + retryDelayMs(claimed.attemptCount))
        : completedAt,
      updatedAt: completedAt,
    });
    log(logger, "dispatch", status, { messageId, eventType: claimed.eventType });
    return { messageId, status };
  }

  function queueFundingOutcome({ recipientEmail, transactionId, outcome }) {
    return queueEmail({ recipientEmail, eventType: "funding_outcome", variables: { outcome }, idempotencyKey: hookKey("funding", transactionId, outcome) });
  }

  function queueHealthcarePaymentOutcome({ recipientEmail, paymentId, outcome }) {
    return queueEmail({ recipientEmail, eventType: "healthcare_payment_outcome", variables: { outcome }, idempotencyKey: hookKey("healthcare", paymentId, outcome) });
  }

  function queueSavingsOutcome({ recipientEmail, contributionId, outcome }) {
    return queueEmail({ recipientEmail, eventType: "savings_contribution_outcome", variables: { outcome }, idempotencyKey: hookKey("savings", contributionId, outcome) });
  }

  function queueFamilyInvitation({ recipientEmail, inviteId, inviterName, pocketName, inviteUrl }) {
    return queueEmail({ recipientEmail, eventType: "family_invitation", variables: { inviterName, pocketName, inviteUrl }, idempotencyKey: hookKey("family_invite", inviteId, "created") });
  }

  function queueFamilyContributionOutcome({ recipientEmail, contributionId, outcome }) {
    return queueEmail({ recipientEmail, eventType: "family_contribution_outcome", variables: { outcome }, idempotencyKey: hookKey("family_contribution", contributionId, outcome) });
  }

  function queueSecurityAlert({ recipientEmail, securityEventId, summary }) {
    return queueEmail({ recipientEmail, eventType: "security_alert", variables: { summary }, idempotencyKey: hookKey("security", securityEventId, "created") });
  }

  return {
    queueEmail,
    dispatchDue,
    dispatchMessage,
    queueFundingOutcome,
    queueHealthcarePaymentOutcome,
    queueSavingsOutcome,
    queueFamilyInvitation,
    queueFamilyContributionOutcome,
    queueSecurityAlert,
  };
}

function template(classification, variables, subject, renderText) {
  return Object.freeze({ classification, variables: Object.freeze(variables), subject, renderText });
}

function renderTemplate(eventType, variables) {
  const definition = TEMPLATES[requireTemplate(eventType)];
  return { subject: definition.subject, text: definition.renderText(variables) };
}

function outboxDocument({ recipientEmail, eventType, classification, variables, fingerprint, status, now }) {
  return {
    schemaVersion: 1,
    recipientEmail,
    eventType,
    classification,
    variables,
    requestFingerprint: fingerprint,
    status,
    attemptCount: 0,
    maxAttempts: MAX_ATTEMPTS,
    nextAttemptAt: now,
    provider: null,
    providerMessageId: null,
    lastErrorCode: null,
    createdAt: now,
    updatedAt: now,
    sentAt: null,
  };
}

function normalizeVariables(definition, variables) {
  if (!variables || typeof variables !== "object" || Array.isArray(variables)) {
    invalid("variables must be an object.");
  }
  const allowed = new Set(definition.variables);
  if (Object.keys(variables).some((key) => !allowed.has(key)) ||
      definition.variables.some((key) => !Object.hasOwn(variables, key))) {
    invalid("Template variables do not match the event contract.");
  }
  const normalized = {};
  for (const key of definition.variables) {
    normalized[key] = boundedString(variables[key], key, key === "inviteUrl" ? 2048 : 200);
  }
  if (Object.hasOwn(normalized, "inviteUrl")) {
    let url;
    try { url = new URL(normalized.inviteUrl); } catch (_) { invalid("inviteUrl is invalid."); }
    if (url.protocol !== "https:") invalid("inviteUrl must use HTTPS.");
    normalized.inviteUrl = url.toString();
  }
  return normalized;
}

function emailResult(messageId, data) {
  return {
    messageId,
    eventType: data.eventType,
    classification: data.classification,
    status: data.status,
    attemptCount: data.attemptCount,
    nextAttemptAt: data.nextAttemptAt.toDate(),
  };
}

function hookKey(namespace, entityId, outcome) {
  const value = `${namespace}_${entityId}_${outcome}`;
  return `hook_${hash(value).slice(0, 48)}`;
}

function retryDelayMs(attemptCount) {
  return Math.min(60 * 60 * 1000, 60 * 1000 * (2 ** Math.max(0, attemptCount - 1)));
}

function requireTemplate(value) {
  if (typeof value !== "string" || !Object.hasOwn(TEMPLATES, value)) {
    invalid("eventType is invalid.");
  }
  return value;
}

function normalizeEmail(value) {
  if (typeof value !== "string") invalid("recipientEmail is invalid.");
  const email = value.trim().toLowerCase();
  if (email.length > 254 || !EMAIL.test(email)) invalid("recipientEmail is invalid.");
  return email;
}

function requireIdempotencyKey(value) {
  if (typeof value !== "string" || !IDEMPOTENCY_KEY.test(value)) invalid("idempotencyKey is invalid.");
}

function boundedString(value, field, maximum) {
  if (typeof value !== "string" || value.trim().length < 1 || value.trim().length > maximum) {
    invalid(`${field} is invalid.`);
  }
  return value.trim();
}

function optionalSafeString(value, maximum) {
  if (value === undefined || value === null) return null;
  return typeof value === "string" && value.length <= maximum ? value : null;
}

function safeErrorCode(value) {
  return typeof value === "string" && /^[A-Za-z0-9_.-]{1,80}$/.test(value)
    ? value
    : "email-provider-error";
}

function nowFrom(clock) {
  const value = clock();
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) throw new TypeError("Clock is invalid.");
  return value;
}

function hash(value) {
  return createHash("sha256").update(typeof value === "string" ? value : JSON.stringify(value)).digest("hex");
}

function invalid(message) {
  throw new EmailServiceError("invalid-argument", message);
}

function log(logger, operation, outcome, details) {
  logger.info?.("healthpocket_backend", {
    component: "email", operation, outcome, ...details,
  });
}

module.exports = {
  buildEmailService,
  EmailServiceError,
  EMAIL_CLASSIFICATION,
  TEMPLATES,
  RATE_POLICIES,
  renderTemplate,
  retryDelayMs,
};
