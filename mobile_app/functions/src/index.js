"use strict";

const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall } = require("firebase-functions/v2/https");
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
require("./config/backend-config");
const {
  assertVerifiedGoogleIdentity,
  runCallable,
} = require("./errors/backend-error");

initializeApp();
const db = getFirestore();
const ledger = buildLedgerService({ db, logger });
const region = "africa-south1";

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
