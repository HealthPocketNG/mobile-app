"use strict";

const EMAIL_DELIVERY_RESULT = Object.freeze({
  DELIVERED: "delivered",
  TRANSIENT_FAILURE: "transient_failure",
  PERMANENT_FAILURE: "permanent_failure",
});

class TransactionalEmailProvider {
  constructor(name) {
    if (new.target === TransactionalEmailProvider) {
      throw new TypeError("TransactionalEmailProvider is abstract.");
    }
    if (typeof name !== "string" || !name) throw new TypeError("Provider name is required.");
    this.name = name;
  }

  async send() {
    throw new Error("send must be implemented by an email provider.");
  }
}

module.exports = { TransactionalEmailProvider, EMAIL_DELIVERY_RESULT };
