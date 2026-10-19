"use strict";

const { after, before, beforeEach, test } = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { buildNotificationService } = require("../src/notifications/notification-service");
const { MockPushNotificationService } = require("../src/notifications/mock-push-notification-service");
const { PUSH_RESULT } = require("../src/notifications/push-notification-service");

let app;
let db;
let push;
let notifications;
const silentLogger = { info() {} };
const ownerId = "notification-owner";
const tokenA = "device-token-a-1234567890";
const tokenB = "device-token-b-1234567890";

before(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("Run through the Firestore emulator.");
  app = initializeApp({ projectId: "demo-healthpocket" }, "notification-tests");
  db = getFirestore(app);
});

beforeEach(async () => {
  await Promise.all([
    db.recursiveDelete(db.collection("notification_events")),
    db.recursiveDelete(db.collection("notification_devices")),
    db.recursiveDelete(db.collection("funding_transactions")),
  ]);
  push = new MockPushNotificationService();
  notifications = buildNotificationService({
    db, push, logger: silentLogger,
    clock: () => new Date("2026-10-19T12:00:00.000Z"),
  });
});

after(async () => deleteApp(app));

test("creates a canonical backend-owned inbox event for every supported category", async () => {
  for (const category of ["savings", "funding", "payment", "family_pocket", "security", "system"]) {
    const result = await notifications.enqueue({
      notificationId: `notice_${category}`,
      userId: ownerId,
      category,
      type: `${category}_event`,
      title: "HealthPocket update",
      body: "Open HealthPocket to view the update.",
    });
    assert.equal(result.readState, "unread");
    assert.equal(result.deliveryStatus, "queued");
  }
});

test("paginates newest-first and binds cursors to owner and filter", async () => {
  await enqueue("notice_old", "funding", "2026-10-17T12:00:00.000Z");
  await enqueue("notice_middle", "payment", "2026-10-18T12:00:00.000Z");
  await enqueue("notice_new", "savings", "2026-10-19T12:00:00.000Z");
  await notifications.markRead({ actorId: ownerId, notificationId: "notice_old" });

  const first = await notifications.list({ actorId: ownerId, readState: "unread", pageSize: 1 });
  assert.deepEqual(first.notifications.map((item) => item.notificationId), ["notice_new"]);
  assert.ok(first.nextCursor);
  const second = await notifications.list({
    actorId: ownerId, readState: "unread", pageSize: 1, cursor: first.nextCursor,
  });
  assert.deepEqual(second.notifications.map((item) => item.notificationId), ["notice_middle"]);
  await assert.rejects(
    notifications.list({ actorId: ownerId, readState: "read", cursor: first.nextCursor }),
    (error) => error.code === "invalid-cursor",
  );
});

test("marks one or all notifications read without crossing ownership", async () => {
  await enqueue("notice_one", "funding");
  await enqueue("notice_two", "payment");
  await notifications.enqueue({
    notificationId: "notice_stranger", userId: "another-user", category: "system",
    type: "system_event", title: "Update", body: "Open the app.",
  });
  await assert.rejects(
    notifications.markRead({ actorId: "another-user", notificationId: "notice_one" }),
    (error) => error.code === "not-found",
  );
  await notifications.markRead({ actorId: ownerId, notificationId: "notice_one" });
  assert.equal((await notifications.markAllRead({ actorId: ownerId })).markedRead, 1);
  assert.equal((await db.collection("notification_events").doc("notice_stranger").get()).data().readState, "unread");
});

test("registers, removes, and atomically refreshes backend-only device tokens", async () => {
  const first = await notifications.registerDevice({ actorId: ownerId, token: tokenA, platform: "android" });
  assert.equal(first.status, "active");
  const refreshed = await notifications.refreshDevice({
    actorId: ownerId, oldToken: tokenA, newToken: tokenB, platform: "android",
  });
  assert.equal(refreshed.status, "active");
  const documents = await db.collection("notification_devices").get();
  assert.deepEqual(documents.docs.map((document) => document.data().status).sort(), ["active", "revoked"]);
  assert.equal((await notifications.removeDevice({ actorId: ownerId, token: tokenB })).status, "revoked");
});

test("delivers to multiple devices and retires stale tokens", async () => {
  await notifications.registerDevice({ actorId: ownerId, token: tokenA, platform: "android" });
  await notifications.registerDevice({ actorId: ownerId, token: tokenB, platform: "ios" });
  push.outcomes[tokenB] = PUSH_RESULT.STALE;
  await enqueue("notice_delivery", "funding");
  const result = await notifications.dispatch("notice_delivery");
  assert.deepEqual(result, { status: "partial", delivered: 1, stale: 1, failed: 0 });
  const stale = await db.collection("notification_devices")
    .where("token", "==", tokenB).get();
  assert.equal(stale.docs[0].data().status, "stale");

  await enqueue("notice_next", "system");
  await notifications.dispatch("notice_next");
  assert.deepEqual(push.deliveries[1].tokens, [tokenA]);
});

test("uses a privacy-minimized lock-screen payload", async () => {
  await notifications.registerDevice({ actorId: ownerId, token: tokenA, platform: "android" });
  await enqueue("notice_private", "payment");
  await notifications.dispatch("notice_private");
  const encoded = JSON.stringify(push.deliveries[0].payload);
  assert.doesNotMatch(encoded, /amount|balance|account|bank|receipt|providerReference|50000/i);
  assert.deepEqual(Object.keys(push.deliveries[0].payload.data).sort(), ["category", "notificationId", "type"]);
});

test("push failure cannot change its underlying transaction outcome", async () => {
  await notifications.registerDevice({ actorId: ownerId, token: tokenA, platform: "android" });
  await db.collection("funding_transactions").doc("funding-final").set({
    userId: ownerId, status: "succeeded", amountKobo: 50000,
  });
  await enqueue("notice_failure", "funding");
  push.throwCode = "provider-unavailable";
  const result = await notifications.dispatch("notice_failure");
  assert.equal(result.status, "failed");
  assert.equal((await db.collection("funding_transactions").doc("funding-final").get()).data().status, "succeeded");
  assert.equal((await db.collection("notification_events").doc("notice_failure").get()).data().deliveryStatus, "failed");
});

async function enqueue(id, category, date = "2026-10-19T12:00:00.000Z") {
  const service = buildNotificationService({
    db, push, logger: silentLogger, clock: () => new Date(date),
  });
  return service.enqueue({
    notificationId: id,
    userId: ownerId,
    category,
    type: `${category}_event`,
    title: "HealthPocket update",
    body: "Open HealthPocket to view the update.",
    relatedEntityType: "test_event",
    relatedEntityId: `${id}_source`,
  });
}
