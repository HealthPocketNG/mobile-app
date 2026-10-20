"use strict";

const { createHash } = require("node:crypto");
const { FieldPath, Timestamp } = require("firebase-admin/firestore");

const SAFE_ID = /^[A-Za-z0-9_-]{1,256}$/;
const ACTIVITY_TYPE = /^[a-z][a-z0-9_]{1,79}$/;
const MAX_PAGE_SIZE = 100;
const MAX_EXPORT_RECORDS = 5000;
const MAX_EXPORT_WINDOW_MS = 366 * 24 * 60 * 60 * 1000;

const SOURCE_COLLECTIONS = Object.freeze({
  funding_transaction: "funding_transactions",
  healthcare_payment: "healthcare_payments",
  scheduled_contribution: "scheduled_contributions",
  family_contribution: "family_contribution_attempts",
  savings_plan: "savings_plans",
});

class ActivityHistoryError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "ActivityHistoryError";
    this.code = code;
  }
}

function buildActivityHistoryService({ db, logger = console, clock = () => new Date() }) {
  if (!db || typeof db.collection !== "function") {
    throw new TypeError("A Firestore Admin database is required.");
  }
  const activities = db.collection("activities");
  const pockets = db.collection("family_pockets");

  async function listHistory(input) {
    const options = normalizeListInput(input);
    const scope = await authorizeScope(options.actorId, options.familyPocketId);
    const filterKey = cursorFilterKey(scope, options);
    const cursor = options.cursor ? decodeCursor(options.cursor, filterKey) : null;

    let query = activities.where(scope.field, "==", scope.value);
    if (options.activityType) {
      query = query.where("activityType", "==", options.activityType);
    }
    if (options.startDate) {
      query = query.where("createdAt", ">=", Timestamp.fromDate(options.startDate));
    }
    if (options.endDate) {
      query = query.where("createdAt", "<=", Timestamp.fromDate(options.endDate));
    }
    query = query
      .orderBy("createdAt", "desc")
      .orderBy(FieldPath.documentId(), "desc");
    if (cursor) {
      query = query.startAfter(Timestamp.fromMillis(cursor.createdAtMillis), cursor.id);
    }

    const snapshot = await query.limit(options.pageSize + 1).get();
    const pageDocuments = snapshot.docs.slice(0, options.pageSize);
    const items = await normalizeActivityDocuments(pageDocuments);
    const hasMore = snapshot.size > options.pageSize;
    const last = hasMore ? pageDocuments.at(-1) : null;
    const nextCursor = last
      ? encodeCursor({
        id: last.id,
        createdAtMillis: requireTimestamp(last.data().createdAt, "createdAt").toMillis(),
        filterKey,
      })
      : null;

    log(logger, "list_activity_history", "success", { itemCount: items.length });
    return {
      items,
      nextCursor,
      empty: items.length === 0,
    };
  }

  async function getTransactionDetail({ actorId, activityId }) {
    requireSafeId(actorId, "actorId");
    requireSafeId(activityId, "activityId");
    const snapshot = await activities.doc(activityId).get();
    if (!snapshot.exists) {
      throw new ActivityHistoryError("not-found", "Activity was not found.");
    }
    const activity = snapshot.data();
    if (activity.userId !== actorId) {
      if (!activity.familyPocketId) throw permissionDenied();
      await authorizeScope(actorId, activity.familyPocketId);
    }
    return normalizeActivityDocument(snapshot, true);
  }

  async function prepareStatement(input) {
    const options = normalizeExportInput(input);
    const records = [];
    let cursor = null;
    do {
      const page = await listHistory({
        actorId: options.actorId,
        familyPocketId: options.familyPocketId,
        activityType: options.activityType,
        startDate: options.startDate,
        endDate: options.endDate,
        pageSize: Math.min(MAX_PAGE_SIZE, options.maxRecords - records.length),
        cursor,
      });
      records.push(...page.items);
      cursor = page.nextCursor;
      if (records.length >= options.maxRecords && cursor) {
        throw new ActivityHistoryError(
          "export-too-large",
          "The statement contains too many records; use a smaller date range.",
        );
      }
    } while (cursor);

    const generatedAt = requireDate(clock(), "generatedAt").toISOString();
    const statement = {
      schemaVersion: 1,
      scope: options.familyPocketId
        ? { type: "family_pocket", id: options.familyPocketId }
        : { type: "personal", id: options.actorId },
      period: {
        start: options.startDate.toISOString(),
        end: options.endDate.toISOString(),
      },
      generatedAt,
      recordCount: records.length,
      records,
    };
    log(logger, "prepare_activity_statement", "success", {
      recordCount: records.length,
    });
    return { ...statement, csv: statementCsv(statement) };
  }

  async function authorizeScope(actorId, familyPocketId) {
    requireSafeId(actorId, "actorId");
    if (!familyPocketId) return { type: "personal", field: "userId", value: actorId };
    requireSafeId(familyPocketId, "familyPocketId");
    const pocketRef = pockets.doc(familyPocketId);
    const [pocket, membership] = await Promise.all([
      pocketRef.get(),
      pocketRef.collection("members").doc(actorId).get(),
    ]);
    if (!pocket.exists || !membership.exists || !activeMembership(membership.data())) {
      throw permissionDenied();
    }
    return { type: "family_pocket", field: "familyPocketId", value: familyPocketId };
  }

  async function normalizeActivityDocument(document, includeMetadata = false) {
    const activity = document.data();
    validateActivity(activity);
    const source = await authoritativeSource(activity);
    return normalizeActivity(document, activity, source, includeMetadata);
  }

  async function normalizeActivityDocuments(documents) {
    const activitiesToSources = documents.map((document) => {
      const activity = document.data();
      validateActivity(activity);
      const collectionName = SOURCE_COLLECTIONS[activity.relatedEntityType];
      if (!collectionName) return { document, activity, reference: null };
      requireSafeId(activity.relatedEntityId, "activity.relatedEntityId");
      return {
        document,
        activity,
        reference: db.collection(collectionName).doc(activity.relatedEntityId),
      };
    });
    const references = activitiesToSources
      .map(({ reference }) => reference)
      .filter(Boolean);
    const snapshots = references.length === 0 ? [] : await db.getAll(...references);
    let sourceIndex = 0;
    return activitiesToSources.map(({ document, activity, reference }) => {
      const source = reference
        ? validatedAuthoritativeSource(activity, snapshots[sourceIndex++])
        : null;
      return normalizeActivity(document, activity, source);
    });
  }

  function normalizeActivity(document, activity, source, includeMetadata = false) {
    validateActivity(activity);
    const amountKobo = authoritativeAmount(activity, source);
    const currency = authoritativeCurrency(activity, source, amountKobo);
    const status = activityStatus(activity, source);
    const category = activityCategory(activity.activityType);
    const direction = activityDirection(category, activity.activityType, status);
    const result = {
      activityId: document.id,
      activityType: activity.activityType,
      category,
      status,
      moneyMovement: amountKobo !== null && ["completed", "reversed"].includes(status),
      direction,
      amountKobo,
      signedAmountKobo: amountKobo === null || direction === null
        ? null
        : direction === "debit" ? -amountKobo : amountKobo,
      currency,
      title: activityTitle(category, activity.activityType, status),
      relatedEntityType: activity.relatedEntityType || null,
      relatedEntityId: activity.relatedEntityId || null,
      familyPocketId: activity.familyPocketId || null,
      receiptNumber: source?.receiptNumber || safeMetadata(activity).receiptNumber || null,
      provider: providerSnapshot(source, activity),
      occurredAt: activity.createdAt.toDate().toISOString(),
    };
    if (includeMetadata) result.metadata = publicMetadata(activity, source);
    return result;
  }

  async function authoritativeSource(activity) {
    const collectionName = SOURCE_COLLECTIONS[activity.relatedEntityType];
    if (!collectionName) return null;
    requireSafeId(activity.relatedEntityId, "activity.relatedEntityId");
    const snapshot = await db.collection(collectionName).doc(activity.relatedEntityId).get();
    return validatedAuthoritativeSource(activity, snapshot);
  }

  function validatedAuthoritativeSource(activity, snapshot) {
    if (!snapshot?.exists) {
      throw integrityError("The authoritative activity source is missing.");
    }
    const source = snapshot.data();
    const sourceOwner = source.userId || source.contributorUserId;
    if (sourceOwner && sourceOwner !== activity.userId) {
      throw integrityError("Activity ownership does not match its source.");
    }
    if (activity.familyPocketId &&
        (source.familyPocketId || source.pocketId) !== activity.familyPocketId) {
      throw integrityError("Activity Family Pocket does not match its source.");
    }
    return source;
  }

  function validateActivity(activity) {
    requireSafeId(activity.userId, "activity.userId");
    if (!ACTIVITY_TYPE.test(activity.activityType || "")) {
      throw integrityError("Activity type is invalid.");
    }
    requireTimestamp(activity.createdAt, "activity.createdAt");
  }

  return { listHistory, getTransactionDetail, prepareStatement };
}

function normalizeListInput(input) {
  if (!input || typeof input !== "object") {
    throw new ActivityHistoryError("invalid-argument", "History request is required.");
  }
  requireSafeId(input.actorId, "actorId");
  if (input.familyPocketId != null) requireSafeId(input.familyPocketId, "familyPocketId");
  if (input.activityType != null && !ACTIVITY_TYPE.test(input.activityType)) {
    throw new ActivityHistoryError("invalid-argument", "Activity type is invalid.");
  }
  const startDate = optionalDate(input.startDate, "startDate");
  const endDate = optionalDate(input.endDate, "endDate");
  if (startDate && endDate && startDate > endDate) {
    throw new ActivityHistoryError("invalid-argument", "Date range is invalid.");
  }
  const pageSize = input.pageSize ?? 25;
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > MAX_PAGE_SIZE) {
    throw new ActivityHistoryError("invalid-argument", "Page size is invalid.");
  }
  if (input.cursor != null && typeof input.cursor !== "string") {
    throw new ActivityHistoryError("invalid-cursor", "History cursor is invalid.");
  }
  return {
    actorId: input.actorId,
    familyPocketId: input.familyPocketId || null,
    activityType: input.activityType || null,
    startDate,
    endDate,
    pageSize,
    cursor: input.cursor || null,
  };
}

function normalizeExportInput(input) {
  const value = normalizeListInput({ ...input, pageSize: 1, cursor: null });
  if (!value.startDate || !value.endDate) {
    throw new ActivityHistoryError(
      "invalid-argument",
      "Statement exports require a start and end date.",
    );
  }
  if (value.endDate.getTime() - value.startDate.getTime() > MAX_EXPORT_WINDOW_MS) {
    throw new ActivityHistoryError("invalid-argument", "Statement range cannot exceed 366 days.");
  }
  const maxRecords = input.maxRecords ?? 1000;
  if (!Number.isInteger(maxRecords) || maxRecords < 1 || maxRecords > MAX_EXPORT_RECORDS) {
    throw new ActivityHistoryError("invalid-argument", "Export record limit is invalid.");
  }
  return { ...value, maxRecords };
}

function authoritativeAmount(activity, source) {
  const metadata = safeMetadata(activity);
  const value = source?.amountKobo ?? activity.amountKobo ?? metadata.amountKobo ?? null;
  if (value === null) return null;
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw integrityError("Activity amount is invalid.");
  }
  return value;
}

function authoritativeCurrency(activity, source, amountKobo) {
  const value = source?.currency ?? activity.currency ?? safeMetadata(activity).currency ?? null;
  if (amountKobo === null) return value || null;
  if (value !== "NGN") throw integrityError("Activity currency is invalid.");
  return value;
}

function activityStatus(activity, source) {
  const type = activity.activityType;
  if (type.startsWith("savings_plan_")) return "recorded";
  if (type.endsWith("_reversed")) return "reversed";
  if (type.endsWith("_failed")) return "failed";
  if (type.endsWith("_cancelled")) return "cancelled";
  if (type.endsWith("_completed")) return "completed";
  const value = source?.status ?? activity.status ?? safeMetadata(activity).status ?? "recorded";
  if (value === "succeeded") return "completed";
  if (["pending", "completed", "failed", "cancelled", "reversed", "recorded"].includes(value)) {
    return value;
  }
  throw integrityError("Activity status is invalid.");
}

function activityCategory(type) {
  if (type.startsWith("funding_")) return "funding";
  if (type.startsWith("healthcare_payment_")) return "healthcare_payment";
  if (type.startsWith("family_")) return "family_pocket";
  if (type.startsWith("scheduled_savings_") || type.startsWith("savings_")) return "savings";
  return "system";
}

function activityDirection(category, type, status) {
  if (!["completed", "reversed"].includes(status)) return null;
  if (status === "reversed") return "credit";
  if (category === "healthcare_payment") return "debit";
  if (["funding", "family_pocket", "savings"].includes(category) &&
      !type.startsWith("savings_plan_")) return "credit";
  return null;
}

function activityTitle(category, type, status) {
  if (type.startsWith("savings_plan_")) return "Savings plan updated";
  const labels = {
    funding: "Wallet funding",
    healthcare_payment: "Healthcare payment",
    family_pocket: "Family Pocket contribution",
    savings: "Savings contribution",
    system: "Account activity",
  };
  const suffix = status === "recorded" ? "" : ` ${status}`;
  return `${labels[category]}${suffix}`.trim();
}

function providerSnapshot(source, activity) {
  const metadata = safeMetadata(activity);
  const providerId = source?.providerId || metadata.providerId || null;
  const providerName = source?.providerName || metadata.providerName || null;
  return providerId || providerName ? { providerId, providerName } : null;
}

function publicMetadata(activity, source) {
  const metadata = safeMetadata(activity);
  return {
    action: typeof metadata.action === "string" ? metadata.action : null,
    flowType: source?.flowType || metadata.flowType || null,
    receiptNumber: source?.receiptNumber || metadata.receiptNumber || null,
  };
}

function activeMembership(data) {
  return ["active", "accepted"].includes(data.status || data.invitationStatus) &&
    data.removedAt == null && data.leftAt == null;
}

function cursorFilterKey(scope, options) {
  return createHash("sha256").update(JSON.stringify({
    scope: [scope.field, scope.value],
    activityType: options.activityType,
    startDate: options.startDate?.toISOString() || null,
    endDate: options.endDate?.toISOString() || null,
  })).digest("hex").slice(0, 24);
}

function encodeCursor(value) {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

function decodeCursor(value, expectedFilterKey) {
  try {
    const parsed = JSON.parse(Buffer.from(value, "base64url").toString("utf8"));
    requireSafeId(parsed.id, "cursor.id");
    if (!Number.isSafeInteger(parsed.createdAtMillis) || parsed.createdAtMillis < 0 ||
        parsed.filterKey !== expectedFilterKey) throw new Error("mismatch");
    return parsed;
  } catch (_) {
    throw new ActivityHistoryError("invalid-cursor", "History cursor is invalid.");
  }
}

function statementCsv(statement) {
  const rows = [[
    "activity_id", "occurred_at", "type", "category", "status", "direction",
    "amount_kobo", "currency", "reference", "receipt_number",
  ]];
  for (const record of statement.records) {
    rows.push([
      record.activityId, record.occurredAt, record.activityType, record.category,
      record.status, record.direction, record.amountKobo, record.currency,
      record.relatedEntityId, record.receiptNumber,
    ]);
  }
  return rows.map((row) => row.map(csvCell).join(",")).join("\r\n");
}

function csvCell(value) {
  if (value == null) return "";
  let text = String(value);
  if (/^[=+\-@]/.test(text)) text = `'${text}`;
  return /[",\r\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

function safeMetadata(activity) {
  return activity.metadata && typeof activity.metadata === "object" &&
    !Array.isArray(activity.metadata) ? activity.metadata : {};
}

function optionalDate(value, field) {
  return value == null ? null : requireDate(value, field);
}

function requireDate(value, field) {
  const result = value instanceof Date
    ? new Date(value.getTime())
    : value && typeof value.toDate === "function"
      ? value.toDate()
      : new Date(value);
  if (Number.isNaN(result.getTime())) {
    throw new ActivityHistoryError("invalid-argument", `${field} is invalid.`);
  }
  return result;
}

function requireTimestamp(value, field) {
  if (!value || typeof value.toMillis !== "function" || typeof value.toDate !== "function") {
    throw integrityError(`${field} is invalid.`);
  }
  return value;
}

function requireSafeId(value, field) {
  if (typeof value !== "string" || !SAFE_ID.test(value)) {
    throw new ActivityHistoryError("invalid-argument", `${field} is invalid.`);
  }
  return value;
}

function permissionDenied() {
  return new ActivityHistoryError("permission-denied", "Activity history is not available.");
}

function integrityError(message) {
  return new ActivityHistoryError("integrity-error", message);
}

function log(logger, event, status, details) {
  logger.info?.("backend_event", {
    component: "activity_history",
    event,
    status,
    ...details,
  });
}

module.exports = { buildActivityHistoryService, ActivityHistoryError };
