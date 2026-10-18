"use strict";

const VERIFICATION_STATUS = Object.freeze({
  VERIFIED: "verified",
  REJECTED: "rejected",
  UNAVAILABLE: "unavailable",
});

const VERIFICATION_STATUSES = new Set(Object.values(VERIFICATION_STATUS));

class HealthcareVerificationError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "HealthcareVerificationError";
    this.code = code;
  }
}

class AccountResolutionService {
  constructor({ name }) {
    if (new.target === AccountResolutionService) {
      throw new TypeError("AccountResolutionService is an abstract contract.");
    }
    requireName(name);
    this.name = name;
  }

  async resolveAccount(_request) {
    throw notImplemented("resolveAccount");
  }
}

class HealthcareEligibilityService {
  constructor({ name }) {
    if (new.target === HealthcareEligibilityService) {
      throw new TypeError("HealthcareEligibilityService is an abstract contract.");
    }
    requireName(name);
    this.name = name;
  }

  async verifyProvider(_request) {
    throw notImplemented("verifyProvider");
  }
}

function assertVerificationStatus(status) {
  if (!VERIFICATION_STATUSES.has(status)) {
    throw new HealthcareVerificationError(
      "invalid-provider-response",
      "The verification adapter returned an unknown status.",
    );
  }
  return status;
}

function requireName(value) {
  if (typeof value !== "string" || value.length < 1 || value.length > 40) {
    throw new TypeError("Verification adapter name is invalid.");
  }
}

function notImplemented(method) {
  return new HealthcareVerificationError(
    "not-implemented",
    `Verification method ${method} is not implemented.`,
  );
}

module.exports = {
  AccountResolutionService,
  HealthcareEligibilityService,
  HealthcareVerificationError,
  VERIFICATION_STATUS,
  VERIFICATION_STATUSES,
  assertVerificationStatus,
};
