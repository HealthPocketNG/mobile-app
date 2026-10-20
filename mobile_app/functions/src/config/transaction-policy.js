"use strict";

// Placeholder ceilings for the mock MVP. They are deliberately centralized so
// compliance/provider onboarding can lower them without rewriting workflows.
// They are not a substitute for provider-side or regulatory velocity controls.
const TRANSACTION_POLICY = Object.freeze({
  currency: "NGN",
  funding: Object.freeze({
    minimumKobo: 50000,
    maximumSingleKobo: 100000000,
    futureDailyAggregateKobo: 500000000,
  }),
  healthcarePayment: Object.freeze({
    minimumKobo: 10000,
    maximumSingleKobo: 100000000,
    futureDailyAggregateKobo: 500000000,
  }),
  familyContribution: Object.freeze({
    minimumKobo: 50000,
    maximumSingleKobo: 100000000,
    futureDailyAggregateKobo: 500000000,
  }),
});

module.exports = { TRANSACTION_POLICY };
