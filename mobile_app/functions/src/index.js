"use strict";

const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { defineSecret } = require("firebase-functions/params");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { buildLedgerService } = require("./ledger-service");
const { buildPaymentService } = require("./payments/payment-service");
const { MockPaymentGateway } = require("./payments/mock-payment-gateway");
const { buildSavingsPlanService } = require("./savings/savings-plan-service");
const { buildFamilyPocketService } = require("./family/family-pocket-service");
const {
  buildHealthcarePaymentService,
} = require("./healthcare/healthcare-payment-service");
const {
  MockAccountResolutionService,
  MockHealthcareEligibilityService,
} = require("./healthcare/mock-healthcare-verification");
const { buildCoverageService } = require("./coverage/coverage-service");
const {
  buildNotificationService,
} = require("./notifications/notification-service");
const {
  MockPushNotificationService,
} = require("./notifications/mock-push-notification-service");
const {
  buildActivityHistoryService,
} = require("./activity/activity-history-service");
const { buildReceiptService } = require("./receipts/receipt-service");
const { buildTrustedBackend } = require("./trusted-backend");
const { buildEmailCodeService } = require("./auth/email-code-service");
const { buildPasswordResetService } = require("./auth/password-reset-service");
require("./config/backend-config");
const {
  BackendError,
  assertVerifiedGoogleIdentity,
  runCallable,
} = require("./errors/backend-error");

initializeApp();
const db = getFirestore();
const ledger = buildLedgerService({ db, logger });
const region = "africa-south1";
const resendKey = defineSecret("HEALTHPOCKET_RESEND_API_KEY");

async function sendViaResend({ to, subject, text }) {
  const key = resendKey.value();
  const from = process.env.HEALTHPOCKET_VERIFICATION_FROM;
  if (!key || !from) throw new BackendError("unavailable");
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from, to: [to], subject, text }),
  });
  if (!response.ok) throw new BackendError("unavailable");
}

function passwordIdentity(request) {
  const uid = request.auth?.uid;
  const email = request.auth?.token?.email;
  if (!uid || typeof email !== "string" ||
      request.auth.token.firebase?.sign_in_provider !== "password") {
    throw new BackendError("unauthenticated");
  }
  return { uid, email: email.trim().toLowerCase() };
}

const emailCodes = buildEmailCodeService({
  db,
  send: ({ to, code }) => sendViaResend({ to, subject: "Verify your HealthPocket email", text: `Your HealthPocket verification code is ${code}. It expires in 10 minutes.` }),
});

const passwordResets = buildPasswordResetService({
  db,
  auth: getAuth(),
  buildResetLink: (token) => {
    const project = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
    if (!project) throw new BackendError("unavailable");
    return `https://${region}-${project}.cloudfunctions.net/openPasswordReset?token=${encodeURIComponent(token)}`;
  },
  send: ({ to, link }) => sendViaResend({ to, subject: "Reset your HealthPocket password", text: `Open this link to create a new password. It expires in 30 minutes: ${link}` }),
});

exports.openPasswordReset = onRequest({ region }, (request, response) => {
  response.set("Cache-Control", "no-store");
  response.set("Referrer-Policy", "no-referrer");
  response.set("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'");
  const token = request.query.token;
  if (typeof token !== "string" || !/^[A-Za-z0-9_-]{40,60}$/.test(token)) {
    response.status(400).send("This password reset link is invalid.");
    return;
  }
  const appLink = `healthpocket://reset-password?token=${encodeURIComponent(token)}`;
  response.type("html").send(`<!doctype html><html lang="en"><head><meta name="viewport" content="width=device-width, initial-scale=1"><title>Reset HealthPocket password</title><style>body{font-family:Arial,sans-serif;background:#f5fbfa;color:#102b42;display:grid;place-items:center;min-height:100vh;margin:0;padding:24px;box-sizing:border-box}main{max-width:360px;text-align:center}a{display:block;background:#10a799;color:white;padding:16px;border-radius:12px;text-decoration:none;font-weight:700;margin-top:24px}</style></head><body><main><h1>Reset your password</h1><p>Open HealthPocket on this device to create a new password. This link expires in 30 minutes.</p><a href="${appLink}">Open HealthPocket</a></main></body></html>`);
});

exports.requestPasswordReset = onCall({ region, secrets: [resendKey] }, async (request) =>
  runCallable({ operation: "request_password_reset", logger, handler: () => passwordResets.requestReset(request.data?.email) }),
);

exports.confirmPasswordReset = onCall({ region }, async (request) =>
  runCallable({ operation: "confirm_password_reset", logger, handler: () => passwordResets.confirmReset({ token: request.data?.token, password: request.data?.password }) }),
);

exports.requestEmailVerificationCode = onCall({ region, secrets: [resendKey] }, async (request) =>
  runCallable({ operation: "request_email_verification_code", logger, handler: async () => {
    const identity = passwordIdentity(request);
    const user = await getAuth().getUser(identity.uid);
    if (user.emailVerified || user.email?.toLowerCase() !== identity.email) throw new BackendError("permission-denied");
    return emailCodes.requestCode(identity);
  } }),
);

exports.verifyEmailCode = onCall({ region }, async (request) =>
  runCallable({ operation: "verify_email_code", logger, handler: async () => {
    const identity = passwordIdentity(request);
    const user = await getAuth().getUser(identity.uid);
    if (user.emailVerified || user.email?.toLowerCase() !== identity.email) throw new BackendError("permission-denied");
    return emailCodes.verifyCode({ ...identity, code: request.data?.code });
  } }),
);

// Mock provider adapters can move only emulator data. The deployed callable
// fails closed for every money action until regulated adapters are selected and
// their Secret Manager bindings are explicitly wired.
const mockMoneyEnabled = process.env.FUNCTIONS_EMULATOR === "true" &&
  process.env.GCLOUD_PROJECT === "demo-healthpocket";
const gateway = new MockPaymentGateway();
const payments = buildPaymentService({ db, ledger, gateway, logger });
const services = {
  ledger,
  payments,
  savings: buildSavingsPlanService({ db, payments, logger }),
  family: buildFamilyPocketService({ db, gateway, logger }),
  healthcare: buildHealthcarePaymentService({
    db,
    payments,
    accountResolver: new MockAccountResolutionService(),
    healthcareVerifier: new MockHealthcareEligibilityService(),
    logger,
  }),
  coverage: buildCoverageService({ db, logger }),
  notifications: buildNotificationService({
    db,
    push: new MockPushNotificationService(),
    logger,
  }),
  activity: buildActivityHistoryService({ db, logger }),
  receipts: buildReceiptService({ db, logger }),
};
const trustedBackend = buildTrustedBackend({
  db,
  services,
  logger,
  moneyEnabled: mockMoneyEnabled,
});

exports.createWalletForNewProfile = onDocumentCreated(
  { document: "users/{userId}", region },
  async (event) => ledger.ensureWallet(event.params.userId),
);

// Backfills an authenticated user's wallet idempotently. This is intentionally
// the only client-callable mutation in this foundation; it cannot set balance.
exports.ensureMyWallet = onCall({ region }, async (request) => {
  return runCallable({
    operation: "ensure_my_wallet",
    logger,
    handler: async () => {
      const { userId } = assertVerifiedGoogleIdentity(request.auth);
      await ledger.ensureWallet(userId);
      return { walletId: userId };
    },
  });
});

// One strict command boundary keeps the callable surface explicit. Every
// command has an allowlisted payload schema and derives user authority from the
// verified Google Auth token rather than accepting user/actor/owner IDs.
exports.trustedBackend = onCall(
  { region, timeoutSeconds: 60, memory: "256MiB" },
  trustedBackend.callable,
);

// No generic credit/debit callable is exported. Future funding, savings and
// healthcare services must import the ledger service after trusted verification.
