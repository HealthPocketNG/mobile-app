"use strict";

const PUSH_RESULT = Object.freeze({
  DELIVERED: "delivered",
  STALE: "stale",
  FAILED: "failed",
});

class PushNotificationService {
  constructor(name) {
    if (new.target === PushNotificationService) {
      throw new TypeError("PushNotificationService is abstract.");
    }
    this.name = name;
  }

  async sendBatch() {
    throw new Error("sendBatch must be implemented by a push adapter.");
  }
}

module.exports = { PushNotificationService, PUSH_RESULT };
