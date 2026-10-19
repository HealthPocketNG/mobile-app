"use strict";

const { createHash } = require("node:crypto");
const { FieldPath, Timestamp } = require("firebase-admin/firestore");
const { notificationDocument } = require("./notification-model");
const { PUSH_RESULT } = require("./push-notification-service");

const SAFE_ID = /^[A-Za-z0-9_-]{1,256}$/;
const PLATFORMS = new Set(["android", "ios", "web"]);
const READ_STATES = new Set(["read", "unread"]);

class NotificationError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "NotificationError";
    this.code = code;
  }
}

function buildNotificationService({ db, push, clock = () => new Date(), logger = console }) {
  if (!db || typeof db.runTransaction !== "function") {
    throw new TypeError("A Firestore Admin database is required.");
  }
  if (!push || typeof push.sendBatch !== "function") {
    throw new TypeError("A push notification adapter is required.");
  }
  const notifications = db.collection("notification_events");
  const devices = db.collection("notification_devices");

  async function enqueue(input) {
    const notificationId = input.notificationId || `notice_${hash({
      userId: input.userId,
      type: input.type,
      relatedEntityId: input.relatedEntityId,
    }).slice(0, 48)}`;
    requireId(notificationId, "notificationId");
    const reference = notifications.doc(notificationId);
    await db.runTransaction(async (transaction) => {
      if ((await transaction.get(reference)).exists) return;
      transaction.create(reference, notificationDocument({
        ...input,
        now: Timestamp.fromDate(nowFrom(clock)),
      }));
    });
    return notificationResult(notificationId, (await reference.get()).data());
  }

  async function list({ actorId, readState = null, pageSize = 20, cursor = null }) {
    requireId(actorId, "actorId");
    if (readState !== null && !READ_STATES.has(readState)) invalid("readState is invalid.");
    if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
      invalid("pageSize must be between 1 and 100.");
    }
    const scope = hash({ actorId, readState }).slice(0, 24);
    let query = notifications.where("userId", "==", actorId);
    if (readState) query = query.where("readState", "==", readState);
    query = query.orderBy("createdAt", "desc").orderBy(FieldPath.documentId(), "desc");
    if (cursor) {
      const decoded = decodeCursor(cursor);
      if (decoded.scope !== scope) {
        throw new NotificationError("invalid-cursor", "Cursor does not match this query.");
      }
      query = query.startAfter(Timestamp.fromMillis(decoded.createdAtMs), decoded.id);
    }
    const snapshot = await query.limit(pageSize + 1).get();
    const page = snapshot.docs.slice(0, pageSize);
    const last = page.at(-1);
    return {
      notifications: page.map((document) => notificationResult(document.id, document.data())),
      nextCursor: snapshot.size > pageSize && last
        ? encodeCursor(last.id, last.data().createdAt.toMillis(), scope)
        : null,
    };
  }

  async function markRead({ actorId, notificationId }) {
    requireId(actorId, "actorId");
    requireId(notificationId, "notificationId");
    const reference = notifications.doc(notificationId);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists || snapshot.data().userId !== actorId) throw notFound();
      if (snapshot.data().readState === "read") return;
      const now = Timestamp.fromDate(nowFrom(clock));
      transaction.update(reference, { readState: "read", readAt: now, updatedAt: now });
    });
    return notificationResult(notificationId, (await reference.get()).data());
  }

  async function markAllRead({ actorId }) {
    requireId(actorId, "actorId");
    let count = 0;
    while (true) {
      const snapshot = await notifications.where("userId", "==", actorId)
        .where("readState", "==", "unread").limit(400).get();
      if (snapshot.empty) break;
      const batch = db.batch();
      const now = Timestamp.fromDate(nowFrom(clock));
      for (const document of snapshot.docs) {
        batch.update(document.ref, { readState: "read", readAt: now, updatedAt: now });
      }
      await batch.commit();
      count += snapshot.size;
    }
    return { markedRead: count };
  }

  async function registerDevice({ actorId, token, platform }) {
    requireId(actorId, "actorId");
    requireToken(token);
    if (!PLATFORMS.has(platform)) invalid("platform is invalid.");
    const now = Timestamp.fromDate(nowFrom(clock));
    const deviceId = deviceIdFor(token);
    const reference = devices.doc(deviceId);
    await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(reference);
      if (existing.exists && existing.data().userId !== actorId) {
        throw new NotificationError("token-conflict", "This device token is already registered.");
      }
      transaction.set(reference, {
        schemaVersion: 1,
        userId: actorId,
        token,
        platform,
        status: "active",
        createdAt: existing.exists ? existing.data().createdAt : now,
        updatedAt: now,
        lastSeenAt: now,
        lastDeliveryAt: existing.exists ? existing.data().lastDeliveryAt || null : null,
        lastErrorCode: null,
      });
    });
    return { deviceId, status: "active" };
  }

  async function removeDevice({ actorId, token }) {
    requireId(actorId, "actorId");
    requireToken(token);
    const reference = devices.doc(deviceIdFor(token));
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists || snapshot.data().userId !== actorId) throw notFound();
      transaction.update(reference, {
        status: "revoked",
        updatedAt: Timestamp.fromDate(nowFrom(clock)),
      });
    });
    return { status: "revoked" };
  }

  async function refreshDevice({ actorId, oldToken, newToken, platform }) {
    requireId(actorId, "actorId");
    requireToken(oldToken);
    requireToken(newToken);
    if (!PLATFORMS.has(platform)) invalid("platform is invalid.");
    if (oldToken === newToken) return registerDevice({ actorId, token: newToken, platform });
    const oldRef = devices.doc(deviceIdFor(oldToken));
    const newRef = devices.doc(deviceIdFor(newToken));
    await db.runTransaction(async (transaction) => {
      const [oldSnapshot, newSnapshot] = await Promise.all([
        transaction.get(oldRef), transaction.get(newRef),
      ]);
      if (!oldSnapshot.exists || oldSnapshot.data().userId !== actorId) throw notFound();
      if (newSnapshot.exists && newSnapshot.data().userId !== actorId) {
        throw new NotificationError("token-conflict", "The refreshed token is unavailable.");
      }
      const now = Timestamp.fromDate(nowFrom(clock));
      transaction.update(oldRef, { status: "revoked", updatedAt: now });
      transaction.set(newRef, {
        schemaVersion: 1, userId: actorId, token: newToken, platform,
        status: "active", createdAt: newSnapshot.exists ? newSnapshot.data().createdAt : now,
        updatedAt: now, lastSeenAt: now, lastDeliveryAt: null, lastErrorCode: null,
      });
    });
    return { deviceId: deviceIdFor(newToken), status: "active" };
  }

  async function dispatch(notificationId) {
    requireId(notificationId, "notificationId");
    const reference = notifications.doc(notificationId);
    const snapshot = await reference.get();
    if (!snapshot.exists) throw notFound();
    const notice = snapshot.data();
    const deviceSnapshot = await devices.where("userId", "==", notice.userId)
      .where("status", "==", "active").get();
    const now = Timestamp.fromDate(nowFrom(clock));
    if (deviceSnapshot.empty) {
      await reference.update({ deliveryStatus: "no_devices", updatedAt: now });
      return { status: "no_devices", delivered: 0, stale: 0, failed: 0 };
    }
    let results;
    try {
      results = await push.sendBatch({
        tokens: deviceSnapshot.docs.map((document) => document.data().token),
        payload: safePushPayload(notificationId, notice),
      });
    } catch (error) {
      const code = safeErrorCode(error?.code);
      await reference.update({
        deliveryStatus: "failed",
        deliveryAttemptCount: (notice.deliveryAttemptCount || 0) + 1,
        lastDeliveryErrorCode: code,
        updatedAt: now,
      });
      log(logger, "dispatch", "failed", { notificationId, code });
      return { status: "failed", delivered: 0, stale: 0, failed: deviceSnapshot.size };
    }
    const byToken = new Map(results.map((result) => [result.token, result]));
    const totals = { delivered: 0, stale: 0, failed: 0 };
    const batch = db.batch();
    for (const device of deviceSnapshot.docs) {
      const result = byToken.get(device.data().token) || { status: PUSH_RESULT.FAILED };
      if (result.status === PUSH_RESULT.DELIVERED) totals.delivered++;
      else if (result.status === PUSH_RESULT.STALE) totals.stale++;
      else totals.failed++;
      batch.update(device.ref, {
        status: result.status === PUSH_RESULT.STALE ? "stale" : "active",
        lastDeliveryAt: result.status === PUSH_RESULT.DELIVERED ? now : null,
        lastErrorCode: result.errorCode || null,
        updatedAt: now,
      });
    }
    const status = totals.failed > 0 || totals.stale > 0
      ? (totals.delivered > 0 ? "partial" : "failed")
      : "delivered";
    batch.update(reference, {
      deliveryStatus: status,
      deliveryAttemptCount: (notice.deliveryAttemptCount || 0) + 1,
      lastDeliveryErrorCode: totals.failed > 0 ? "partial-delivery-failure" : null,
      deliveredAt: totals.delivered > 0 ? now : null,
      updatedAt: now,
    });
    await batch.commit();
    log(logger, "dispatch", status, { notificationId });
    return { status, ...totals };
  }

  return { enqueue, list, markRead, markAllRead, registerDevice, removeDevice, refreshDevice, dispatch };
}

function safePushPayload(notificationId, notice) {
  return {
    notification: { title: notice.title, body: notice.body },
    data: { notificationId, category: notice.category, type: notice.type },
  };
}

function notificationResult(notificationId, data) {
  return {
    notificationId,
    type: data.type,
    category: data.category,
    title: data.title,
    body: data.body,
    readState: data.readState,
    readAt: data.readAt?.toDate() || null,
    deliveryStatus: data.deliveryStatus,
    relatedEntityType: data.relatedEntityType || null,
    relatedEntityId: data.relatedEntityId || null,
    familyPocketId: data.familyPocketId || null,
    createdAt: data.createdAt.toDate(),
  };
}

function encodeCursor(id, createdAtMs, scope) {
  return Buffer.from(JSON.stringify({ id, createdAtMs, scope })).toString("base64url");
}

function decodeCursor(cursor) {
  try {
    const value = JSON.parse(Buffer.from(cursor, "base64url").toString("utf8"));
    requireId(value.id, "cursor");
    if (typeof value.scope !== "string" || !/^[a-f0-9]{24}$/.test(value.scope)) throw new Error();
    if (!Number.isSafeInteger(value.createdAtMs) || value.createdAtMs < 0) throw new Error();
    return value;
  } catch (_) {
    invalid("cursor is invalid.");
  }
}

function deviceIdFor(token) {
  return `device_${hash(token).slice(0, 48)}`;
}

function requireToken(token) {
  if (typeof token !== "string" || token.length < 20 || token.length > 4096 || /\s/.test(token)) {
    invalid("device token is invalid.");
  }
}

function requireId(value, name) {
  if (typeof value !== "string" || !SAFE_ID.test(value)) invalid(`${name} is invalid.`);
}

function invalid(message) {
  throw new NotificationError("invalid-argument", message);
}

function notFound() {
  return new NotificationError("not-found", "Notification resource was not found.");
}

function nowFrom(clock) {
  const value = clock();
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) throw new TypeError("Clock is invalid.");
  return value;
}

function hash(value) {
  return createHash("sha256").update(typeof value === "string" ? value : JSON.stringify(value)).digest("hex");
}

function safeErrorCode(value) {
  return typeof value === "string" && /^[A-Za-z0-9_.-]{1,80}$/.test(value)
    ? value
    : "push-provider-error";
}

function log(logger, operation, outcome, details) {
  logger.info("healthpocket_backend", {
    component: "notifications", operation, outcome, ...details,
  });
}

module.exports = { buildNotificationService, NotificationError, safePushPayload };
