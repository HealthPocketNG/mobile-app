# Data integrity, indexing, and retention

This document is the launch contract for Firestore Standard edition. The DEV
database is Firestore Native in `africa-south1`; `firestore.indexes.json` is the
source of truth for composite indexes. Index changes must be verified in the
emulator and deployed deliberately to each environment before a release.

## Query and index inventory

| Query family | Bound/pagination | Composite index |
| --- | --- | --- |
| Latest savings plan by user | `limit(1)` | `savings_plans(userId, updatedAt desc)` |
| Due savings plans | worker-supplied limit | `savings_plans(status, nextContributionDate)` |
| Personal/family contributions | recent UI cap of 100 | declared contribution indexes |
| Family memberships/invites | UI cap of 100 | collection-group membership/invite indexes |
| Activity history | opaque `(createdAt, documentId)` cursor, max page 100 | personal/family indexes, plus activity-type variants |
| Wallet and Family Pocket reconciliation | internal pages of 500 | owner/pocket + status + `createdAt asc` indexes |
| Funding, ledger, and financial-operation lists | max 100 | owner + `createdAt desc` indexes |
| Notification inbox | opaque cursor, max page 100 | owner/read-state + `createdAt desc` indexes |
| Push delivery devices | max 100 active devices per dispatch | equality-index merge |
| Provider discovery | max 100 | active + selected filter + normalized name indexes |
| Coverage evaluation | max 100 | active + price index |
| Email outbox dispatch | worker-supplied limit | status + next-attempt index |

Document-ID lookups use automatic indexes. Equality-only queries use Firestore
index merging. Every range/order query is represented in
`firestore.indexes.json`. Do not add a new filtered/ordered query without adding
it to this table, declaring its bound/cursor, and verifying its index.

The callable history and notification APIs are cursor-paginated. Flutter's
legacy real-time contribution, Family Pocket, and activity views are explicitly
capped at the most recent 100 records so a screen cannot subscribe to an
ever-growing collection. A future UI that needs older rows must consume a
cursor-paginated backend method rather than raising or removing those caps.

Activity pages bulk-fetch their authoritative transaction sources with one
Firestore `getAll` call per page. Reconciliation scans use bounded 500-document
pages. Catalog replacement reads at most 401 active records and fails closed if
the supported 400-record seed ceiling is exceeded.

## Document schema versions

Authoritative backend-created documents carry an integer `schemaVersion`.
Version changes follow these rules:

1. Prefer additive fields with safe reader defaults.
2. Writers emit only the current version; readers explicitly validate the
   versions they support.
3. Breaking changes require a new version and a bounded, restart-safe migration.
4. A migration uses a stable release ID and checksum, is dry-run by default,
   and records completion in `_backend_migrations`.
5. Never silently reinterpret integer-kobo money, currency, ownership, status,
   idempotency keys, or provider snapshots during migration.

Catalog documents currently use schema version 1. Family Pocket top-level and
membership documents use version 2; their child financial attempts and ledger
records retain their own version. Migration markers are backend-only and are
not readable or writable by clients.

## Account deletion and retention

An account-deletion request is a controlled lifecycle, not a recursive
Firestore delete:

- Immediately revoke sessions, disable new money operations, remove device
  tokens, and deactivate the user's profile/access paths.
- Delete optional profile/Family Pocket images when Storage deletion is
  available. Remove or anonymize profile fields that are not required for
  security, dispute handling, accounting, or an applicable legal hold.
- Preserve immutable wallet ledger entries, financial operations, funding and
  healthcare-payment records, Family Pocket contributions, receipts, and the
  minimum activity/audit linkage required to reconcile them. Replace direct
  display PII with a stable internal subject reference where policy permits;
  never alter amounts, currency, timestamps, references, or outcomes.
- Preserve membership/contribution facts needed to explain a Family Pocket
  balance, while marking the member inactive and suppressing deleted-profile
  display data.
- Retention duration must be configured only after Nigerian legal/compliance
  review and any regulated payment provider requirements are known. Until that
  approval exists, financial records must not be automatically purged.
- A later purge job must be allowlisted by collection, bounded, idempotent,
  auditable, aware of legal holds, and tested in the emulator before deployment.

Provider and coverage catalog rows are deactivated, not deleted. Completed
healthcare payments and receipts store provider ID and provider-name snapshots,
so historical records remain renderable when the directory entry changes or is
deactivated. Historical rendering must never require a live provider lookup.

## Safe catalog seeding

`functions/scripts/seed-catalogs.js` accepts a JSON manifest containing
`schemaVersion: 1`, a unique lowercase `releaseId`, and `providers` and/or
`coverageItems` arrays. It validates the complete manifest without connecting
to Firebase and defaults to dry-run:

```powershell
npm --prefix functions run seed:catalogs -- --file .\catalog.json
```

Apply to an emulator explicitly:

```powershell
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
npm --prefix functions run seed:catalogs -- --file .\catalog.json --apply --project demo-healthpocket
```

A live apply additionally requires `--confirm-project` with the exact project
ID. `--deactivate-missing` also requires that confirmation. Release IDs are
immutable: replaying identical data is a no-op, while reusing an ID with a
different checksum fails. The script logs counts and checksums, never the
catalog payload. Do not seed the live coverage catalog until genuine
partner-supplied prices have been approved.
