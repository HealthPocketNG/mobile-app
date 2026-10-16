"use strict";

const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { buildLedgerService, LedgerError } = require("./ledger-service");

initializeApp();
const ledger = buildLedgerService({ db: getFirestore(), logger });
const region = "africa-south1";

exports.createWalletForNewProfile = onDocumentCreated(
  { document: "users/{userId}", region },
  async (event) => ledger.ensureWallet(event.params.userId),
);

// Backfills an authenticated user's wallet idempotently. This is intentionally
// the only client-callable mutation in this foundation; it cannot set balance.
exports.ensureMyWallet = onCall({ region }, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) throw new HttpsError("unauthenticated", "Sign-in is required.");
  try {
    await ledger.ensureWallet(userId);
    return { walletId: userId };
  } catch (error) {
    if (error instanceof LedgerError) {
      throw new HttpsError("failed-precondition", error.message);
    }
    throw error;
  }
});

// No generic credit/debit callable is exported. Future funding, savings and
// healthcare services must import the ledger service after trusted verification.
