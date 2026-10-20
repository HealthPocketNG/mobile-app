"use strict";

const { defineSecret, defineString } = require("firebase-functions/params");

// Secret values must be supplied by Secret Manager and bound only to the
// concrete production adapters that consume them. They are intentionally not
// read by the current mock adapters or written to logs/Firestore.
const PAYMENT_PROVIDER = defineString("PAYMENT_PROVIDER", {
  default: "disabled",
  description: "Production payment adapter identifier; disabled until selected.",
});
const PAYMENT_PROVIDER_API_KEY = defineSecret("PAYMENT_PROVIDER_API_KEY");
const PAYMENT_WEBHOOK_SECRET = defineSecret("PAYMENT_WEBHOOK_SECRET");
const EMAIL_PROVIDER_API_KEY = defineSecret("EMAIL_PROVIDER_API_KEY");
const PUSH_PROVIDER_CREDENTIALS = defineSecret("PUSH_PROVIDER_CREDENTIALS");

const PROVIDER_SECRET_BINDINGS = Object.freeze([
  PAYMENT_PROVIDER_API_KEY,
  PAYMENT_WEBHOOK_SECRET,
  EMAIL_PROVIDER_API_KEY,
  PUSH_PROVIDER_CREDENTIALS,
]);

module.exports = {
  PAYMENT_PROVIDER,
  PAYMENT_PROVIDER_API_KEY,
  PAYMENT_WEBHOOK_SECRET,
  EMAIL_PROVIDER_API_KEY,
  PUSH_PROVIDER_CREDENTIALS,
  PROVIDER_SECRET_BINDINGS,
};
