"use strict";

const {
  PushNotificationService,
  PUSH_RESULT,
} = require("./push-notification-service");

class MockPushNotificationService extends PushNotificationService {
  constructor({ outcomes = {}, throwCode = null } = {}) {
    super("mock-push");
    this.outcomes = { ...outcomes };
    this.throwCode = throwCode;
    this.deliveries = [];
  }

  async sendBatch({ tokens, payload }) {
    this.deliveries.push({ tokens: [...tokens], payload: structuredClone(payload) });
    if (this.throwCode) {
      const error = new Error("Mock push provider failed.");
      error.code = this.throwCode;
      throw error;
    }
    return tokens.map((token) => ({
      token,
      status: this.outcomes[token] || PUSH_RESULT.DELIVERED,
      errorCode: this.outcomes[token] === PUSH_RESULT.FAILED
        ? "mock-delivery-failed"
        : null,
    }));
  }
}

module.exports = { MockPushNotificationService };
