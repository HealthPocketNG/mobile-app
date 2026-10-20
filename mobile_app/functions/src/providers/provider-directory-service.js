"use strict";

const { Timestamp } = require("firebase-admin/firestore");

const CATEGORIES = new Set([
  "hospital",
  "clinic",
  "pharmacy",
  "diagnostics",
  "other",
]);
const PARTNER_STATUSES = new Set(["partner", "non_partner"]);
const SAFE_ID = /^[a-z0-9][a-z0-9_-]{0,127}$/;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

class ProviderDirectoryError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "ProviderDirectoryError";
    this.code = code;
  }
}

function buildProviderDirectoryService({ db, logger = console }) {
  if (!db || typeof db.runTransaction !== "function") {
    throw new TypeError("A Firestore Admin database is required.");
  }
  const providers = db.collection("healthcare_providers");

  async function upsertProvider({ actor, provider }) {
    assertAdmin(actor);
    const normalized = normalizeProvider(provider);
    const providerId = normalizeProviderId(provider.id || normalized.name);
    const ref = providers.doc(providerId);
    await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(ref);
      const now = Timestamp.now();
      transaction.set(ref, {
        ...normalized,
        createdAt: existing.exists ? existing.data().createdAt : now,
        updatedAt: now,
        deactivatedAt: normalized.active
          ? null
          : existing.data()?.deactivatedAt || now,
      });
    });
    log(logger, "provider_upsert", "success", { providerId });
    return { providerId };
  }

  async function setProviderActive({ actor, providerId, active }) {
    assertAdmin(actor);
    const safeProviderId = requireProviderId(providerId);
    if (typeof active !== "boolean") invalid("active must be a boolean.");
    const ref = providers.doc(safeProviderId);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw new ProviderDirectoryError("not-found", "Provider was not found.");
      }
      const now = Timestamp.now();
      transaction.update(ref, {
        active,
        updatedAt: now,
        deactivatedAt: active ? null : now,
      });
    });
    log(logger, "provider_activation_change", "success", {
      providerId: safeProviderId,
      active,
    });
    return { providerId: safeProviderId, active };
  }

  async function seedProviders({ actor, entries, deactivateMissing = false }) {
    assertAdmin(actor);
    if (!Array.isArray(entries) || entries.length === 0 || entries.length > 400) {
      invalid("entries must contain between 1 and 400 providers.");
    }
    if (typeof deactivateMissing !== "boolean") {
      invalid("deactivateMissing must be a boolean.");
    }
    const prepared = entries.map((provider) => ({
      providerId: normalizeProviderId(provider.id || provider.name),
      document: normalizeProvider(provider),
    }));
    if (new Set(prepared.map(({ providerId }) => providerId)).size !== prepared.length) {
      invalid("Provider IDs must be unique within a seed operation.");
    }
    const existing = await Promise.all(
      prepared.map(({ providerId }) => providers.doc(providerId).get()),
    );
    const now = Timestamp.now();
    const writes = prepared.map(({ providerId, document }, index) => {
      const current = existing[index];
      return {
        kind: "set",
        ref: providers.doc(providerId),
        data: {
          ...document,
          createdAt: current.exists ? current.data().createdAt : now,
          updatedAt: now,
          deactivatedAt: document.active
            ? null
            : current.data()?.deactivatedAt || now,
        },
      };
    });

    let deactivatedCount = 0;
    if (deactivateMissing) {
      const retainedIds = new Set(prepared.map(({ providerId }) => providerId));
      const active = await providers.where("active", "==", true).limit(401).get();
      if (active.size > 400) {
        invalid("Cannot deactivate missing providers when more than 400 are active.");
      }
      for (const document of active.docs) {
        if (!retainedIds.has(document.id)) {
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
    log(logger, "provider_seed", "success", {
      providerCount: prepared.length,
      deactivatedCount,
    });
    return { providerCount: prepared.length, deactivatedCount };
  }

  return { upsertProvider, setProviderActive, seedProviders };
}

function normalizeProvider(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    invalid("provider must be an object.");
  }
  const name = boundedString(input.name, "name", 160);
  const category = enumValue(input.category, "category", CATEGORIES);
  const partnerStatus = enumValue(
    input.partnerStatus,
    "partnerStatus",
    PARTNER_STATUSES,
  );
  const state = boundedString(input.state, "state", 100);
  const city = boundedString(input.city, "city", 100);
  const address = boundedString(input.address, "address", 500);
  const coordinates = normalizeCoordinates(input.coordinates);
  const contact = normalizeContact(input.contact || {});
  const services = stringList(input.services, "services", 40, 120, true);
  const imageUrls = urlList(input.imageUrls || [], "imageUrls", 10);
  const logoUrl = optionalUrl(input.logoUrl, "logoUrl");
  const openingInformation = optionalString(
    input.openingInformation,
    "openingInformation",
    1000,
  );
  if (typeof input.active !== "boolean") invalid("active must be a boolean.");
  const normalizedName = normalizeSearchText(name);
  return {
    schemaVersion: 1,
    name,
    normalizedName,
    category,
    partnerStatus,
    address,
    state,
    city,
    coordinates,
    locationCell: [locationCell(coordinates)],
    contact,
    openingInformation,
    logoUrl,
    imageUrls,
    services,
    searchPrefixes: searchPrefixes([
      name,
      category,
      state,
      city,
      address,
      ...services,
    ]),
    active: input.active,
  };
}

function normalizeCoordinates(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    invalid("coordinates must be an object.");
  }
  const { latitude, longitude } = value;
  if (typeof latitude !== "number" || !Number.isFinite(latitude) ||
      latitude < -90 || latitude > 90 ||
      typeof longitude !== "number" || !Number.isFinite(longitude) ||
      longitude < -180 || longitude > 180) {
    invalid("coordinates must contain valid latitude and longitude values.");
  }
  return { latitude, longitude };
}

function normalizeContact(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    invalid("contact must be an object.");
  }
  const phone = optionalString(value.phone, "contact.phone", 40);
  const email = optionalString(value.email, "contact.email", 254);
  if (email !== null && !EMAIL.test(email)) invalid("contact.email is invalid.");
  return {
    phone,
    email: email?.toLowerCase() || null,
    website: optionalUrl(value.website, "contact.website"),
  };
}

function normalizeProviderId(value) {
  const slug = normalizeSearchText(boundedString(value, "id", 160))
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 120);
  return requireProviderId(slug);
}

function requireProviderId(value) {
  if (typeof value !== "string" || !SAFE_ID.test(value)) {
    invalid("providerId must be a safe lowercase ID.");
  }
  return value;
}

function locationCell({ latitude, longitude }) {
  return `g_${Math.floor((latitude + 90) * 4)}_${Math.floor((longitude + 180) * 4)}`;
}

function searchPrefixes(values) {
  const result = new Set();
  for (const token of normalizeSearchText(values.join(" ")).split(" ")) {
    if (!token) continue;
    for (let length = 1; length <= Math.min(token.length, 30); length += 1) {
      result.add(token.slice(0, length));
      if (result.size === 50) return [...result];
    }
  }
  return [...result];
}

function normalizeSearchText(value) {
  return value.trim().toLowerCase().normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function assertAdmin(actor) {
  if (!actor || typeof actor.uid !== "string" ||
      actor.uid.length === 0 || actor.claims?.admin !== true) {
    throw new ProviderDirectoryError(
      "permission-denied",
      "A trusted directory administrator is required.",
    );
  }
}

function boundedString(value, field, maxLength) {
  if (typeof value !== "string" || value.trim().length === 0 ||
      value.trim().length > maxLength) {
    invalid(`${field} must be a non-empty string of at most ${maxLength} characters.`);
  }
  return value.trim();
}

function optionalString(value, field, maxLength) {
  if (value === undefined || value === null || value === "") return null;
  if (typeof value !== "string" || value.trim().length > maxLength) {
    invalid(`${field} must be null or a string of at most ${maxLength} characters.`);
  }
  return value.trim();
}

function enumValue(value, field, allowed) {
  if (!allowed.has(value)) invalid(`${field} is invalid.`);
  return value;
}

function stringList(value, field, maxItems, maxLength, required) {
  if (!Array.isArray(value) || value.length > maxItems ||
      (required && value.length === 0)) {
    invalid(`${field} must be a list with at most ${maxItems} items.`);
  }
  return value.map((item) => boundedString(item, field, maxLength));
}

function optionalUrl(value, field) {
  const text = optionalString(value, field, 2048);
  if (text === null) return null;
  let url;
  try {
    url = new URL(text);
  } catch (_) {
    invalid(`${field} must be a valid HTTPS URL.`);
  }
  if (url.protocol !== "https:") invalid(`${field} must use HTTPS.`);
  return url.toString();
}

function urlList(value, field, maxItems) {
  if (!Array.isArray(value) || value.length > maxItems) {
    invalid(`${field} must be a list with at most ${maxItems} items.`);
  }
  return value.map((item) => optionalUrl(item, field));
}

function invalid(message) {
  throw new ProviderDirectoryError("invalid-argument", message);
}

function log(logger, operation, outcome, details) {
  logger.info?.("provider_directory", { operation, outcome, ...details });
}

module.exports = {
  ProviderDirectoryError,
  buildProviderDirectoryService,
  locationCell,
  normalizeProvider,
  normalizeProviderId,
};
