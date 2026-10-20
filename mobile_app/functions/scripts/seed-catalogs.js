"use strict";

const { createHash } = require("node:crypto");
const { readFile } = require("node:fs/promises");
const { initializeApp } = require("firebase-admin/app");
const { FieldValue, getFirestore } = require("firebase-admin/firestore");
const {
  buildProviderDirectoryService,
  normalizeProvider,
  normalizeProviderId,
} = require("../src/providers/provider-directory-service");
const {
  buildCoverageService,
  normalizeItem,
  normalizeItemId,
} = require("../src/coverage/coverage-service");

const SAFE_RELEASE = /^[a-z0-9][a-z0-9_-]{0,79}$/;

function validateManifest(input) {
  if (!input || typeof input !== "object" || Array.isArray(input) ||
      input.schemaVersion !== 1 || !SAFE_RELEASE.test(input.releaseId || "")) {
    throw new Error("Manifest requires schemaVersion 1 and a safe releaseId.");
  }
  const providers = input.providers || [];
  const coverageItems = input.coverageItems || [];
  if ((!Array.isArray(providers) || !Array.isArray(coverageItems)) ||
      (providers.length === 0 && coverageItems.length === 0) ||
      providers.length > 400 || coverageItems.length > 400) {
    throw new Error("Manifest must contain 1-400 providers and/or coverage items.");
  }
  const providerIds = providers.map((entry) => {
    const normalized = normalizeProvider(entry);
    return normalizeProviderId(entry.id || normalized.name);
  });
  const itemIds = coverageItems.map((entry) => {
    const normalized = normalizeItem(entry);
    return normalizeItemId(entry.id || normalized.name);
  });
  if (new Set(providerIds).size !== providerIds.length ||
      new Set(itemIds).size !== itemIds.length) {
    throw new Error("Catalog IDs must be unique within the manifest.");
  }
  return {
    schemaVersion: 1,
    releaseId: input.releaseId,
    providers,
    coverageItems,
    providerIds,
    itemIds,
  };
}

function canonicalChecksum(manifest) {
  return createHash("sha256").update(JSON.stringify({
    schemaVersion: manifest.schemaVersion,
    releaseId: manifest.releaseId,
    providers: manifest.providers,
    coverageItems: manifest.coverageItems,
  })).digest("hex");
}

async function applyManifest({ db, manifest, deactivateMissing = false, logger = console }) {
  const checksum = canonicalChecksum(manifest);
  const migrationId = `catalog_seed_${manifest.releaseId}`;
  const marker = db.collection("_backend_migrations").doc(migrationId);
  const existing = await marker.get();
  if (existing.exists) {
    if (existing.data().checksum !== checksum) {
      throw new Error("This releaseId was already used with different catalog data.");
    }
    return { migrationId, checksum, alreadyApplied: true };
  }

  const actor = { uid: "catalog-seed-script", claims: { admin: true } };
  const result = {};
  if (manifest.providers.length > 0) {
    result.providers = await buildProviderDirectoryService({ db, logger }).seedProviders({
      actor,
      entries: manifest.providers,
      deactivateMissing,
    });
  }
  if (manifest.coverageItems.length > 0) {
    result.coverageItems = await buildCoverageService({ db, logger }).seedItems({
      actor,
      entries: manifest.coverageItems,
      deactivateMissing,
    });
  }
  await marker.create({
    schemaVersion: 1,
    releaseId: manifest.releaseId,
    checksum,
    providerCount: manifest.providers.length,
    coverageItemCount: manifest.coverageItems.length,
    deactivateMissing,
    appliedAt: FieldValue.serverTimestamp(),
  });
  return { migrationId, checksum, alreadyApplied: false, ...result };
}

function parseArgs(argv) {
  const values = { apply: false, deactivateMissing: false };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--apply") values.apply = true;
    else if (argument === "--deactivate-missing") values.deactivateMissing = true;
    else if (["--file", "--project", "--confirm-project"].includes(argument)) {
      values[argument.slice(2).replace("-project", "Project")] = argv[++index];
    } else throw new Error(`Unknown argument: ${argument}`);
  }
  if (!values.file) throw new Error("--file is required.");
  if (values.deactivateMissing && !values.apply) {
    throw new Error("--deactivate-missing is only valid with --apply.");
  }
  return values;
}

async function main(argv = process.argv.slice(2)) {
  const options = parseArgs(argv);
  const manifest = validateManifest(JSON.parse(await readFile(options.file, "utf8")));
  const checksum = canonicalChecksum(manifest);
  const summary = {
    releaseId: manifest.releaseId,
    checksum,
    providerCount: manifest.providers.length,
    coverageItemCount: manifest.coverageItems.length,
  };
  if (!options.apply) {
    console.info(JSON.stringify({ mode: "dry-run", valid: true, ...summary }));
    return summary;
  }

  const projectId = options.project || process.env.GCLOUD_PROJECT;
  if (!projectId) throw new Error("--project is required when applying a manifest.");
  const emulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
  if (!emulator && options.confirmProject !== projectId) {
    throw new Error("Live apply requires --confirm-project with the exact project ID.");
  }
  if (options.deactivateMissing && options.confirmProject !== projectId) {
    throw new Error("Deactivation requires --confirm-project with the exact project ID.");
  }
  const db = getFirestore(initializeApp({ projectId }, `catalog-seed-${Date.now()}`));
  const result = await applyManifest({
    db,
    manifest,
    deactivateMissing: options.deactivateMissing,
  });
  console.info(JSON.stringify({ mode: emulator ? "emulator" : "live", ...summary, ...result }));
  return result;
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`Catalog seed failed: ${error.message}`);
    process.exitCode = 1;
  });
}

module.exports = { applyManifest, canonicalChecksum, main, parseArgs, validateManifest };
