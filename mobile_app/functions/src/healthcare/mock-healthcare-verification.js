"use strict";

const { createHash } = require("node:crypto");
const {
  AccountResolutionService,
  HealthcareEligibilityService,
  HealthcareVerificationError,
  VERIFICATION_STATUS,
} = require("./healthcare-verification");

const MOCK_OUTCOMES = new Set([
  VERIFICATION_STATUS.VERIFIED,
  VERIFICATION_STATUS.REJECTED,
  VERIFICATION_STATUS.UNAVAILABLE,
  "timeout",
]);

class MockAccountResolutionService extends AccountResolutionService {
  constructor() {
    super({ name: "mock_account_resolution" });
    this.outcomes = [];
  }

  setNextOutcome(outcome) {
    assertMockOutcome(outcome);
    this.outcomes.push(outcome);
  }

  async resolveAccount({ accountNumber, bankCode }) {
    if (typeof accountNumber !== "string" || !/^\d{10}$/.test(accountNumber) ||
        typeof bankCode !== "string" || !/^\d{3}$/.test(bankCode)) {
      throw new HealthcareVerificationError(
        "invalid-bank-details",
        "Bank account details are invalid.",
      );
    }
    const outcome = this.outcomes.shift() || VERIFICATION_STATUS.VERIFIED;
    if (outcome === "timeout") throw timeoutError();
    if (outcome !== VERIFICATION_STATUS.VERIFIED) {
      return { status: outcome, beneficiary: null };
    }
    const digest = createHash("sha256")
      .update(`${bankCode}:${accountNumber}`)
      .digest("hex");
    return {
      status: VERIFICATION_STATUS.VERIFIED,
      beneficiary: {
        accountNumberLast4: accountNumber.slice(-4),
        bankCode,
        bankName: mockBankName(bankCode),
        accountName: "Mock Verified Healthcare Recipient",
        beneficiaryReference: `mock_beneficiary_${digest.slice(0, 32)}`,
      },
    };
  }
}

class MockHealthcareEligibilityService extends HealthcareEligibilityService {
  constructor() {
    super({ name: "mock_healthcare_eligibility" });
    this.outcomes = [];
  }

  setNextOutcome(outcome) {
    assertMockOutcome(outcome);
    this.outcomes.push(outcome);
  }

  async verifyProvider({ providerId, beneficiary }) {
    if (!providerId || !beneficiary?.beneficiaryReference) {
      throw new HealthcareVerificationError(
        "invalid-argument",
        "Provider verification input is invalid.",
      );
    }
    const outcome = this.outcomes.shift() || VERIFICATION_STATUS.VERIFIED;
    if (outcome === "timeout") throw timeoutError();
    return {
      status: outcome,
      verificationReference: outcome === VERIFICATION_STATUS.VERIFIED
        ? `mock_verification_${createHash("sha256").update(providerId).digest("hex").slice(0, 32)}`
        : null,
      classification: outcome === VERIFICATION_STATUS.VERIFIED
        ? "mock_healthcare_eligible"
        : null,
      productionMccVerified: false,
      reasonCode: outcome === VERIFICATION_STATUS.REJECTED
        ? "mock_not_eligible"
        : outcome === VERIFICATION_STATUS.UNAVAILABLE
          ? "mock_unavailable"
          : null,
    };
  }
}

function assertMockOutcome(outcome) {
  if (!MOCK_OUTCOMES.has(outcome)) {
    throw new HealthcareVerificationError(
      "invalid-argument",
      "Mock verification outcome is invalid.",
    );
  }
}

function mockBankName(bankCode) {
  return {
    "044": "Mock Access Bank",
    "058": "Mock GTBank",
    "033": "Mock UBA",
  }[bankCode] || "Mock Bank";
}

function timeoutError() {
  return new HealthcareVerificationError(
    "provider-timeout",
    "The mock verification provider timed out.",
  );
}

module.exports = {
  MockAccountResolutionService,
  MockHealthcareEligibilityService,
  MOCK_OUTCOMES,
};
