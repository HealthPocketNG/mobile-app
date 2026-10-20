"use strict";

const {
  TransactionalEmailProvider,
  EMAIL_DELIVERY_RESULT,
} = require("./transactional-email-provider");

class MockEmailProvider extends TransactionalEmailProvider {
  constructor({ outcomes = [] } = {}) {
    super("mock-email");
    this.outcomes = [...outcomes];
    this.deliveries = [];
  }

  setOutcomes(...outcomes) {
    this.outcomes = [...outcomes];
  }

  async send(message) {
    this.deliveries.push(structuredClone(message));
    const outcome = this.outcomes.shift() || EMAIL_DELIVERY_RESULT.DELIVERED;
    return {
      status: outcome,
      providerMessageId: outcome === EMAIL_DELIVERY_RESULT.DELIVERED
        ? `mock_${this.deliveries.length}`
        : null,
      errorCode: outcome === EMAIL_DELIVERY_RESULT.TRANSIENT_FAILURE
        ? "mock-temporary-failure"
        : outcome === EMAIL_DELIVERY_RESULT.PERMANENT_FAILURE
          ? "mock-permanent-failure"
          : null,
    };
  }
}

module.exports = { MockEmailProvider };
