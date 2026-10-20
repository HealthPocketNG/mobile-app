"use strict";

const { Timestamp } = require("firebase-admin/firestore");

const CURRENCY = "NGN";
const MAX_PRICE_KOBO = 100000000000;
const SAFE_ID = /^[a-z0-9][a-z0-9_-]{0,127}$/;
const CATEGORIES = new Set([
  "consultation",
  "diagnostics",
  "pharmacy",
  "dental",
  "vision",
  "maternal_care",
  "other",
]);

class CoverageError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "CoverageError";
    this.code = code;
  }
}

function buildCoverageService({ db, clock = () => new Date(), logger = console }) {
  if (!db || typeof db.runTransaction !== "function") {
    throw new TypeError("A Firestore Admin database is required.");
  }
  const items = db.collection("coverage_items");
  const wallets = db.collection("wallets");

  async function upsertItem({ actor, item }) {
    assertAdmin(actor);
    const normalized = normalizeItem(item);
    const itemId = normalizeItemId(item.id || normalized.name);
    const reference = items.doc(itemId);
    await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(reference);
      const now = Timestamp.fromDate(nowFrom(clock));
      transaction.set(reference, {
        ...normalized,
        createdAt: existing.exists ? existing.data().createdAt : now,
        updatedAt: now,
        lastUpdatedAt: now,
        deactivatedAt: normalized.active
          ? null
          : existing.data()?.deactivatedAt || now,
      });
    });
    log(logger, "coverage_item_upsert", "success", { itemId });
    return { itemId };
  }

  async function setItemActive({ actor, itemId, active }) {
    assertAdmin(actor);
    requireItemId(itemId);
    if (typeof active !== "boolean") invalid("active must be a boolean.");
    const reference = items.doc(itemId);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw new CoverageError("not-found", "Coverage item was not found.");
      const now = Timestamp.fromDate(nowFrom(clock));
      transaction.update(reference, {
        active,
        updatedAt: now,
        deactivatedAt: active ? null : now,
      });
    });
    log(logger, "coverage_item_activation_change", "success", { itemId, active });
    return { itemId, active };
  }

  async function seedItems({ actor, entries, deactivateMissing = false }) {
    assertAdmin(actor);
    if (!Array.isArray(entries) || entries.length < 1 || entries.length > 400) {
      invalid("entries must contain between 1 and 400 coverage items.");
    }
    if (typeof deactivateMissing !== "boolean") {
      invalid("deactivateMissing must be a boolean.");
    }
    const prepared = entries.map((entry) => ({
      itemId: normalizeItemId(entry.id || entry.name),
      document: normalizeItem(entry),
    }));
    if (new Set(prepared.map(({ itemId }) => itemId)).size !== prepared.length) {
      invalid("Coverage item IDs must be unique within a seed operation.");
    }
    const existing = await Promise.all(
      prepared.map(({ itemId }) => items.doc(itemId).get()),
    );
    const now = Timestamp.fromDate(nowFrom(clock));
    const writes = prepared.map(({ itemId, document }, index) => ({
      kind: "set",
      ref: items.doc(itemId),
      data: {
        ...document,
        createdAt: existing[index].exists ? existing[index].data().createdAt : now,
        updatedAt: now,
        lastUpdatedAt: now,
        deactivatedAt: document.active
          ? null
          : existing[index].data()?.deactivatedAt || now,
      },
    }));
    let deactivatedCount = 0;
    if (deactivateMissing) {
      const retained = new Set(prepared.map(({ itemId }) => itemId));
      const active = await items.where("active", "==", true).limit(401).get();
      if (active.size > 400) {
        invalid("Cannot deactivate missing coverage items when more than 400 are active.");
      }
      for (const document of active.docs) {
        if (!retained.has(document.id)) {
          writes.push({
            kind: "update",
            ref: document.ref,
            data: { active: false, updatedAt: now, deactivatedAt: now },
          });
          deactivatedCount += 1;
        }
      }
    }
    for (let offset = 0; offset < writes.length; offset += 450) {
      const batch = db.batch();
      for (const write of writes.slice(offset, offset + 450)) {
        batch[write.kind](write.ref, write.data);
      }
      await batch.commit();
    }
    log(logger, "coverage_seed", "success", {
      itemCount: prepared.length,
      deactivatedCount,
    });
    return { itemCount: prepared.length, deactivatedCount };
  }

  async function evaluateCoverage({ actorId, limit = 20 } = {}) {
    requireUserId(actorId);
    if (!Number.isInteger(limit) || limit < 1 || limit > 100) {
      invalid("limit must be between 1 and 100.");
    }
    const [wallet, catalog] = await Promise.all([
      wallets.doc(actorId).get(),
      items.where("active", "==", true)
        .orderBy("indicativePriceKobo", "asc")
        .limit(limit)
        .get(),
    ]);
    if (!wallet.exists) throw new CoverageError("wallet-not-found", "Wallet is not provisioned.");
    const walletData = wallet.data();
    if (walletData.userId !== actorId || walletData.currency !== CURRENCY ||
        !Number.isSafeInteger(walletData.availableBalanceKobo) ||
        walletData.availableBalanceKobo < 0) {
      throw new CoverageError("integrity-error", "Wallet data is invalid.");
    }
    if (walletData.status !== "active") {
      throw new CoverageError("wallet-unavailable", "Wallet is not active.");
    }
    const balanceKobo = walletData.availableBalanceKobo;
    const coverageItems = catalog.docs.map((document) => {
      const item = document.data();
      validateStoredItem(item);
      const covered = balanceKobo >= item.indicativePriceKobo;
      return {
        itemId: document.id,
        name: item.name,
        category: item.category,
        indicativePriceKobo: item.indicativePriceKobo,
        currency: item.currency,
        priceType: item.priceType,
        covered,
        amountRemainingKobo: covered ? balanceKobo - item.indicativePriceKobo : 0,
        shortfallKobo: covered ? 0 : item.indicativePriceKobo - balanceKobo,
        source: {
          name: item.sourceName,
          reference: item.sourceReference,
          providerId: item.providerId,
        },
        locationContext: item.locationContext,
        lastUpdatedAt: item.lastUpdatedAt.toDate(),
        disclaimer: item.disclaimer,
      };
    });
    const coveredCount = coverageItems.filter((item) => item.covered).length;
    return {
      balanceKobo,
      currency: CURRENCY,
      state: coverageItems.length === 0
        ? "empty_catalog"
        : balanceKobo === 0
        ? "zero_balance"
        : coveredCount === 0
          ? "below_all_estimates"
          : coveredCount === coverageItems.length
            ? "covers_all_listed"
            : "covers_some_listed",
      message: balanceKobo === 0
        ? "Start saving to see which healthcare estimates your balance can cover."
        : null,
      coverageItems,
      empty: coverageItems.length === 0,
    };
  }

  return { upsertItem, setItemActive, seedItems, evaluateCoverage };
}

function normalizeItem(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    invalid("item must be an object.");
  }
  const name = boundedString(input.name, "name", 160);
  if (!CATEGORIES.has(input.category)) invalid("category is invalid.");
  if (!Number.isSafeInteger(input.indicativePriceKobo) ||
      input.indicativePriceKobo < 1 || input.indicativePriceKobo > MAX_PRICE_KOBO) {
    invalid("indicativePriceKobo must be positive integer kobo.");
  }
  if (typeof input.active !== "boolean") invalid("active must be a boolean.");
  return {
    schemaVersion: 1,
    name,
    normalizedName: normalizeSearchText(name),
    category: input.category,
    indicativePriceKobo: input.indicativePriceKobo,
    currency: CURRENCY,
    priceType: "indicative_estimate",
    sourceName: boundedString(input.sourceName, "sourceName", 160),
    sourceReference: optionalString(input.sourceReference, "sourceReference", 256),
    providerId: optionalId(input.providerId, "providerId"),
    locationContext: normalizeLocation(input.locationContext),
    disclaimer: "Indicative estimate only. Actual healthcare costs may vary.",
    active: input.active,
  };
}

function validateStoredItem(item) {
  if (!item || item.schemaVersion !== 1 || item.currency !== CURRENCY ||
      item.priceType !== "indicative_estimate" || !CATEGORIES.has(item.category) ||
      !Number.isSafeInteger(item.indicativePriceKobo) || item.indicativePriceKobo < 1 ||
      item.indicativePriceKobo > MAX_PRICE_KOBO || item.active !== true ||
      typeof item.name !== "string" || item.name.length < 1 || item.name.length > 160 ||
      typeof item.sourceName !== "string" || item.sourceName.length < 1 ||
      item.sourceName.length > 160 || typeof item.disclaimer !== "string" ||
      !(item.lastUpdatedAt instanceof Timestamp)) {
    throw new CoverageError("integrity-error", "Coverage catalog data is invalid.");
  }
}

function normalizeLocation(value) {
  if (value === undefined || value === null) return { state: null, city: null };
  if (typeof value !== "object" || Array.isArray(value)) invalid("locationContext is invalid.");
  return {
    state: optionalString(value.state, "locationContext.state", 100),
    city: optionalString(value.city, "locationContext.city", 100),
  };
}

function normalizeItemId(value) {
  const slug = normalizeSearchText(boundedString(value, "id", 160))
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 120);
  requireItemId(slug);
  return slug;
}

function requireItemId(value) {
  if (typeof value !== "string" || !SAFE_ID.test(value)) invalid("itemId is invalid.");
}

function requireUserId(value) {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) {
    invalid("actorId is invalid.");
  }
}

function optionalId(value, field) {
  if (value === undefined || value === null || value === "") return null;
  if (typeof value !== "string" || !SAFE_ID.test(value)) invalid(`${field} is invalid.`);
  return value;
}

function boundedString(value, field, maximum) {
  if (typeof value !== "string" || value.trim().length < 1 || value.trim().length > maximum) {
    invalid(`${field} is invalid.`);
  }
  return value.trim();
}

function optionalString(value, field, maximum) {
  if (value === undefined || value === null || value === "") return null;
  return boundedString(value, field, maximum);
}

function normalizeSearchText(value) {
  return value.trim().toLowerCase().normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function assertAdmin(actor) {
  if (!actor || typeof actor.uid !== "string" || !actor.uid || actor.claims?.admin !== true) {
    throw new CoverageError("permission-denied", "A trusted catalog administrator is required.");
  }
}

function nowFrom(clock) {
  const value = clock();
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) throw new TypeError("Clock is invalid.");
  return value;
}

function invalid(message) {
  throw new CoverageError("invalid-argument", message);
}

function log(logger, operation, outcome, details) {
  logger.info?.("healthpocket_backend", {
    component: "coverage", operation, outcome, ...details,
  });
}

module.exports = {
  buildCoverageService,
  CoverageError,
  normalizeItem,
  normalizeItemId,
  CATEGORIES,
};
