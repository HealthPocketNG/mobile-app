"use strict";

const { after, before, beforeEach, test } = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const {
  TransactionalEmailProvider,
  EMAIL_DELIVERY_RESULT,
} = require("../src/email/transactional-email-provider");
const { MockEmailProvider } = require("../src/email/mock-email-provider");
const {
  buildEmailService,
  EMAIL_CLASSIFICATION,
  TEMPLATES,
} = require("../src/email/email-service");

let app;
let db;
let provider;
let emails;
let currentTime;
const recipientEmail = "person@example.com";
const silentLogger = { info() {} };

before(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("Run through the Firestore emulator.");
  app = initializeApp({ projectId: "demo-healthpocket" }, "email-tests");
  db = getFirestore(app);
});

beforeEach(async () => {
  await Promise.all([
    db.recursiveDelete(db.collection("email_outbox")),
    db.recursiveDelete(db.collection("email_rate_limits")),
    db.recursiveDelete(db.collection("email_verification_challenges")),
    db.recursiveDelete(db.collection("funding_transactions")),
  ]);
  currentTime = new Date("2026-10-19T15:00:00.000Z");
  provider = new MockEmailProvider();
  emails = buildEmailService({
    db, provider, logger: silentLogger, clock: () => new Date(currentTime),
  });
});

after(async () => deleteApp(app));

test("defines a replaceable provider and complete MVP event catalog", () => {
  assert.throws(() => new TransactionalEmailProvider("direct"), /abstract/);
  assert.deepEqual(Object.keys(TEMPLATES).sort(), [
    "family_contribution_outcome",
    "family_invitation",
    "funding_outcome",
    "healthcare_payment_outcome",
    "pin_reset_confirmation",
    "product_update",
    "savings_contribution_outcome",
    "security_alert",
    "welcome",
  ]);
  assert.equal(TEMPLATES.security_alert.classification, EMAIL_CLASSIFICATION.SECURITY);
  assert.equal(TEMPLATES.product_update.classification, EMAIL_CLASSIFICATION.MARKETING);
});

test("queues and sends transactional email only through the server provider", async () => {
  const queued = await emails.queueFundingOutcome({
    recipientEmail, transactionId: "funding-1", outcome: "completed",
  });
  assert.equal(queued.status, "queued");
  assert.equal(provider.deliveries.length, 0);

  const result = await emails.dispatchDue();
  assert.equal(result[0].status, "sent");
  assert.equal(provider.deliveries.length, 1);
  assert.equal(provider.deliveries[0].to, recipientEmail);
  assert.doesNotMatch(JSON.stringify(provider.deliveries[0]), /credential|apiKey|secret/i);
});

test("deduplicates financial hooks and rejects conflicting key reuse", async () => {
  const first = await emails.queueFundingOutcome({
    recipientEmail, transactionId: "funding-duplicate", outcome: "completed",
  });
  const retry = await emails.queueFundingOutcome({
    recipientEmail, transactionId: "funding-duplicate", outcome: "completed",
  });
  assert.equal(retry.messageId, first.messageId);
  assert.equal((await db.collection("email_outbox").get()).size, 1);

  await emails.queueEmail({
    recipientEmail,
    eventType: "funding_outcome",
    variables: { outcome: "completed" },
    idempotencyKey: "manualconflictkey1",
  });
  await assert.rejects(
    emails.queueEmail({
      recipientEmail,
      eventType: "funding_outcome",
      variables: { outcome: "failed" },
      idempotencyKey: "manualconflictkey1",
    }),
    (error) => error.code === "idempotency-conflict",
  );
});

test("separates optional marketing consent from essential email", async () => {
  const suppressed = await emails.queueEmail({
    recipientEmail,
    eventType: "product_update",
    variables: { headline: "A new optional feature is available." },
    idempotencyKey: "marketingmessage001",
    marketingConsent: false,
  });
  assert.equal(suppressed.status, "suppressed");

  const essential = await emails.queueEmail({
    recipientEmail,
    eventType: "security_alert",
    variables: { summary: "A new sign-in was detected." },
    idempotencyKey: "securitymessage0001",
    marketingConsent: false,
  });
  assert.equal(essential.status, "queued");
  const delivered = await emails.dispatchDue();
  assert.equal(delivered.length, 1);
  assert.equal(provider.deliveries[0].classification, "security");
});

test("enforces recipient/classification rate limits without consuming duplicates", async () => {
  for (let index = 0; index < 5; index += 1) {
    await emails.queueEmail({
      recipientEmail,
      eventType: "security_alert",
      variables: { summary: `Security event ${index}.` },
      idempotencyKey: `securityratekey${index}0000`,
    });
  }
  const duplicate = await emails.queueEmail({
    recipientEmail,
    eventType: "security_alert",
    variables: { summary: "Security event 0." },
    idempotencyKey: "securityratekey00000",
  });
  assert.equal(duplicate.status, "queued");
  await assert.rejects(
    emails.queueEmail({
      recipientEmail,
      eventType: "security_alert",
      variables: { summary: "One too many." },
      idempotencyKey: "securityrateoverflow",
    }),
    (error) => error.code === "rate-limited",
  );
});

test("retries transient failures with backoff and handles permanent failure", async () => {
  provider.setOutcomes(
    EMAIL_DELIVERY_RESULT.TRANSIENT_FAILURE,
    EMAIL_DELIVERY_RESULT.DELIVERED,
    EMAIL_DELIVERY_RESULT.PERMANENT_FAILURE,
  );
  const first = await emails.queueSavingsOutcome({
    recipientEmail, contributionId: "saving-1", outcome: "failed",
  });
  let result = await emails.dispatchMessage(first.messageId);
  assert.equal(result.status, "retry_scheduled");
  let stored = (await db.collection("email_outbox").doc(first.messageId).get()).data();
  assert.equal(stored.attemptCount, 1);
  assert.equal(stored.nextAttemptAt.toMillis(), currentTime.getTime() + 60000);

  currentTime = new Date(currentTime.getTime() + 60000);
  result = await emails.dispatchMessage(first.messageId);
  assert.equal(result.status, "sent");

  const second = await emails.queueHealthcarePaymentOutcome({
    recipientEmail, paymentId: "payment-1", outcome: "failed",
  });
  result = await emails.dispatchMessage(second.messageId);
  assert.equal(result.status, "permanent_failure");
});

test("recovers an expired sending lease after an interrupted worker", async () => {
  const queued = await emails.queueSecurityAlert({
    recipientEmail, securityEventId: "sign-in-1", summary: "A sign-in was detected.",
  });
  await db.collection("email_outbox").doc(queued.messageId).update({
    status: "sending",
    nextAttemptAt: Timestamp.fromMillis(currentTime.getTime() - 1),
  });
  const result = await emails.dispatchDue();
  assert.equal(result[0].status, "sent");
});

test("email delivery failure never changes an authoritative transaction", async () => {
  await db.collection("funding_transactions").doc("funding-final").set({
    userId: "email-user", status: "succeeded", amountKobo: 50000,
  });
  const queued = await emails.queueFundingOutcome({
    recipientEmail, transactionId: "funding-final", outcome: "completed",
  });
  provider.send = async () => {
    const error = new Error("Provider unavailable");
    error.code = "provider-unavailable";
    throw error;
  };
  const result = await emails.dispatchMessage(queued.messageId);
  assert.equal(result.status, "retry_scheduled");
  assert.equal(
    (await db.collection("funding_transactions").doc("funding-final").get()).data().status,
    "succeeded",
  );
});

test("validates template contracts and secure invitation links", async () => {
  await assert.rejects(
    emails.queueEmail({
      recipientEmail,
      eventType: "funding_outcome",
      variables: { outcome: "completed", amountKobo: "50000" },
      idempotencyKey: "unexpectedvariable01",
    }),
    (error) => error.code === "invalid-argument",
  );
  await assert.rejects(
    emails.queueFamilyInvitation({
      recipientEmail,
      inviteId: "invite-1",
      inviterName: "Ada",
      pocketName: "Family Care",
      inviteUrl: "http://example.com/invite/not-secure",
    }),
    (error) => error.code === "invalid-argument",
  );
});
