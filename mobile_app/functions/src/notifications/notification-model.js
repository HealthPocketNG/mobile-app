"use strict";

const { Timestamp } = require("firebase-admin/firestore");

const NOTIFICATION_CATEGORIES = new Set([
  "savings",
  "funding",
  "payment",
  "family_pocket",
  "security",
  "system",
]);

function notificationDocument({
  userId,
  type,
  category,
  title,
  body,
  relatedEntityType = null,
  relatedEntityId = null,
  familyPocketId = null,
  now = Timestamp.now(),
}) {
  requireText(userId, "userId", 128);
  requireText(type, "type", 100);
  if (!NOTIFICATION_CATEGORIES.has(category)) {
    throw new TypeError("Notification category is invalid.");
  }
  requireText(title, "title", 120);
  requireText(body, "body", 240);
  return {
    schemaVersion: 1,
    userId,
    type,
    category,
    title: title.trim(),
    body: body.trim(),
    readState: "unread",
    readAt: null,
    deliveryStatus: "queued",
    deliveryAttemptCount: 0,
    lastDeliveryErrorCode: null,
    deliveredAt: null,
    relatedEntityType,
    relatedEntityId,
    familyPocketId,
    createdAt: now,
    updatedAt: now,
  };
}

function requireText(value, name, maximum) {
  if (typeof value !== "string" || value.trim().length < 1 ||
      value.length > maximum) {
    throw new TypeError(`${name} is invalid.`);
  }
}

module.exports = { notificationDocument, NOTIFICATION_CATEGORIES };
