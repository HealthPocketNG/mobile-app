# Firebase data model

## Invitation slice rollout status

The capability-based invitation lifecycle is implemented and tested locally.
Its rules and new indexes were deployed to DEV on 2026-09-14. The preflight
inventory found zero Family Pockets and zero child records, so no migration
writes were needed. Contribution records were untouched. Production is unchanged.
All nine listed DEV indexes are READY, including the new membership and invite
indexes. The 42 Flutter tests and Flutter analysis passed again after deployment.
The app is ready for DEV mobile acceptance; see `TODO.md` for that checklist.

### DEV rollout and recovery

Run `node scripts/migrate-family-dev.mjs preview` after refreshing Firebase CLI
login to inspect DEV and save a local inventory under
`.dart_tool/family-migration/`. This script is read-only and hardcoded to DEV;
it rejects apply mode. Backups may contain personal data: keep them out of Git
and do not share them. A future non-empty legacy inventory needs a reviewed,
tested migration and recovery plan before any writes.

No data rollback is required for this rollout because no data was changed.
If a rules regression requires rollback, compare the previous DEV ruleset
`da7c1516-006e-4982-b84f-b6c1c0760799` with the deployed ruleset
`5c5b87d8-4669-4398-bdf0-a91a427d9481` before restoring via Firebase Console.
Do not blindly restore old rules after new-schema records have been created.
Keep the new indexes; they do not rewrite documents.

For mobile acceptance, run
`flutter run --flavor dev --target lib/main_dev.dart` with two verified accounts.
Create a pocket, invite the other account's email, then switch accounts and
accept or decline from the Family tab. Check cancellation, removal, two-slot
capacity, refresh and restart persistence. Use additional accounts to exercise
the beneficiary capacity boundary. No invitation emails are sent in this slice.

This first iteration authorizes atomic client transactions through Firestore
Security Rules. It does not yet implement the previously discussed trusted
invitation service. Token redemption, email delivery, and automated expiry
remain tracked in `TODO.md` and are required before the full email journey.

This contract began in the Week 1 foundation pass. Authenticated DEV journeys
now persist profiles, notification preferences, personal pockets, savings
instructions, development contribution records, and Family Pockets through
repositories. The general activity repository remains an extension point; the
current personal and family histories derive directly from contribution records.

## Collections

- `users/{userId}` stores profile data, notification preferences, KYC status,
  `onboardingStatus`, and creation/update timestamps. The document ID must equal
  the Firebase Auth UID. Google sign-in provisions this document transactionally;
  repeated sign-ins retrieve the same document instead of creating duplicates.
- `personal_health_pockets/{pocketId}` stores ownership, currency, lifecycle
  status, and timestamps. It does not store a mutable balance.
- `savings_plans/personal-plan-{userId}` stores one user's recurring amount,
  daily/weekly/monthly frequency, start date, safely calculated next scheduled
  date, optional funding-source reference, and active/paused/cancelled status.
  Cancellation is terminal.
- `savings_plan_operations/{operationId}` is the server-owned idempotency and
  audit boundary for plan creation and lifecycle changes.
- `scheduled_contributions/{occurrenceId}` stores one deterministic recurring
  occurrence with its expected amount, schedule time, payment attempt/reference,
  ledger operation, and pending/succeeded/failed outcome. Owners may read these
  records; only the trusted backend may write them.
- `funding_transactions/{paymentAttemptId}` is the owner-readable Add Money
  projection of a trusted server payment attempt. It stores integer kobo,
  currency, created/pending/completed/failed/cancelled/reversed status, nullable
  provider and ledger references, failure code, stable transaction reference,
  nullable receipt number, safe description/channel fields, and timestamps.
- `notification_events/{eventId}` stores a backend-created, owner-readable
  queued notification event for a completed, failed, timed-out, or cancelled
  funding attempt. Flutter cannot create or mutate these events.
- `contributions/dev_{userId}_{idempotencyKey}` and
  `contributions/dev_family_{userId}_{idempotencyKey}` store immutable personal
  or Family Pocket development records. Each record has `amountKobo`, `NGN`,
  `status: recorded`, `origin: dev_simulation`, `moneyMovement: false`, the
  owning pocket ID, a personal plan ID when applicable, an idempotency key, and
  a server `createdAt`.
- `wallets/{userId}` is the server-owned cached account view for one Firebase
  user. It stores NGN `availableBalanceKobo`, lifecycle status, a monotonic
  transaction version, and trusted timestamps. The client may read its own
  wallet but cannot create, update, increment, decrement, or delete it.
- `financial_operations/{operationId}` stores the trusted lifecycle of a
  balance-changing request: pending, completed, failed, cancelled, or reversed.
  IDs and request fingerprints are deterministically derived from the user and
  idempotency key, so a retry returns the original outcome and conflicting reuse
  is rejected.
- `ledger_entries/{entryId}` stores immutable completed credit/debit postings in
  integer kobo. A reversal creates a separate compensating entry linked to the
  original entry; completed history is never rewritten or deleted.
- `family_pockets/{pocketId}` stores the pocket name, optional description and
  image path, daily/weekly/monthly contribution frequency, default contribution
  amount, explicit owner, currency, status, transactionally cached balance,
  version, and timestamps. The image path is nullable while Cloud Storage
  upload remains deferred.
- `family_pockets/{pocketId}/members/{memberId}` stores non-PII membership
  display data, authority role, contribution/beneficiary capabilities, and
  lifecycle state. An accepted user's membership ID is their Auth UID. Removing
  a member is a soft update to `status: removed` with `removedAt`; financial
  history is never deleted.
- `family_pockets/{pocketId}/invites/{inviteId}` stores invitation email PII,
  denormalized pocket/inviter display names, proposed capabilities, seven-day
  expiry, and response state. Active admins can manage their pocket's invites;
  an email-verified invitee can discover and respond only to the invitation
  matching their Firebase Auth email.
- `family_pockets/{pocketId}/beneficiary_slots/{1|2}` reserves the two allowed
  beneficiary positions across pending and accepted invitations. Reservation,
  acceptance, decline/cancellation, and member removal update the invitation,
  membership, and slot atomically.
- `activities/{activityId}` is an append-only user-visible audit feed linked to
  the affected entity and, when applicable, a Family Pocket.
- `family_invite_keys/{hash}` enforces one pending invite per pocket/email and
  stores only an email hash. `family_invite_codes/{codeHash}` maps a hashed,
  high-entropy bearer code to an invitation; raw link codes are never stored.
- `family_contribution_attempts/{attemptId}` stores mock/provider funding state.
  `family_ledger_entries/{entryId}` is the immutable authoritative Family
  Pocket credit history used for reconciliation and balance derivation.

## Data decisions

- Firebase Auth is the account authority. Google is the only MVP sign-in
  provider; Firestore rejects non-Google and unverified-email identities.
- The six-digit HealthPocket app PIN is device-local only. Firestore has no PIN
  field, and neither application logging nor analytics receives the PIN. A
  versioned record containing only a random 16-byte salt and a
  PBKDF2-HMAC-SHA256 hash is placed in OS-protected secure storage. Legacy
  records are migrated locally; incomplete, corrupt, or unsupported records are
  deleted and require a new PIN after Google authentication. Android backup is
  disabled so this app-unlock material is not restored onto another install.
- PIN guessing is throttled in secure storage after five failures, with
  persisted progressive cooldowns of 2 minutes, 5 minutes, 15 minutes, and one
  hour. Closing or restarting the app does not bypass an active cooldown.
- A PIN is only an unlock factor for an already authenticated, verified Google
  identity. Logout or Firebase token/session loss blocks PIN verification.
  Forgotten-PIN recovery reauthenticates the same Google UID before deleting
  the old local credential. A new device or reinstall must authenticate with
  Google and create its own local PIN.

- Savings-plan preferences and contribution records use positive integer kobo
  (`contributionAmountKobo` and `amountKobo`) and explicitly store
  `currency: NGN` where the record carries currency.
- Savings schedule calculation is separate from UI code. Daily and weekly
  occurrences preserve the UTC time; monthly schedules clamp to the last valid
  calendar day (for example, January 31 advances to February 28 in 2026).
- The recurring contribution runner uses the provider-neutral payment boundary.
  In this phase it is exercised only with the local mock adapter. Initialization
  cannot credit a wallet; a trusted mock verification must succeed first, and a
  failed occurrence never creates a completed ledger entry.
- The displayed development balance is derived only from personal contribution
  records whose status is `recorded`, origin is `dev_simulation`, and
  `moneyMovement` is false. It is never stored as an independently editable
  value. The dashboard activity feed reads this same ordered record list.
- A Family Pocket development balance follows the same rule and is derived from
  immutable family-scoped records visible only to active members.
- The trusted Family Pocket balance is changed only in the same transaction
  that creates an immutable completed Family Pocket ledger entry. The member's
  lifetime contribution total is updated in that transaction, keeping member
  attribution, pocket totals, activity, and notifications idempotent under
  concurrent contributions.
- Family Pocket membership authority is explicit: one `owner`, optional
  `admin` members, and ordinary `member` records. Owners must transfer ownership
  before leaving; alternatively they may close the pocket. Admins cannot remove
  owners or other admins, and members cannot manipulate membership.
- DEV simulation contributions remain explicitly non-monetary and are not
  migrated into the authoritative wallet. The trusted ledger is a separate
  boundary used only by server-side funding/payment services.
- The authoritative wallet balance is a transactionally updated cache of
  immutable completed ledger postings. Every debit checks the current balance
  inside the same Firestore transaction, preventing negative balances under
  concurrency. Failed and cancelled operations create no ledger posting.
- `functions/src/ledger-service.js` owns pending creation, finalization,
  reversal, idempotency, atomic cache updates, and reconciliation. No generic
  client-callable credit/debit function is exported. Future payment adapters
  must call this service only after trusted verification.
- The provider-neutral payment boundary lives under
  `functions/src/payments/`. Server-owned `payment_attempts` retain the expected
  user, amount, currency, kind, normalized status, and a nullable opaque
  `providerReference`. Server-owned `provider_events` retain only the normalized
  callback envelope and processing state, never the raw callback body.
- Funding initialization and healthcare-payment initiation cannot post ledger
  entries. Only an adapter verification result or a signature-verified callback
  can finalize an attempt. Provider events and their ledger operations use
  deterministic IDs so callback retries and duplicate delivery do not move
  money twice.
- Add Money validates ₦500–₦1,000,000 centrally in the trusted payment service.
  Presets are ₦500, ₦1,000, ₦2,000, ₦5,000, and ₦10,000; custom amounts inside
  the same range are also accepted. Savings-plan funding uses its own amount
  policy and is not constrained by the Add Money UI limits.
- A completed Add Money verification updates the owner-readable funding
  transaction, posts exactly one funding ledger credit, creates one activity,
  and queues one notification. Failed, timed-out, and cancelled attempts queue
  a notification but post no completed ledger credit.
- The current adapter is a local mock with controllable success, pending,
  failure, timeout, duplicate-callback, and reversal behavior. It contains no
  production credentials, makes no payment-network calls, and performs no real
  MCC verification.
- New profile creation provisions a zero-balance wallet through a Firestore
  trigger. `ensureMyWallet` provides an authenticated, idempotent backfill path
  that can only create the caller's zero-balance wallet. DEV deployment and the
  existing-user backfill remain pending until Cloud Functions billing is
  available.
- The mobile client can create only those non-monetary development records.
  Real/provider-originated deposits, payments, settlement and withdrawals are
  rejected. A trusted backend or provider webhook must own those writes later.
- A client-generated request key produces a deterministic document ID. The
  repository checks that document in a transaction, so retrying the same
  request is a no-op instead of a second record.
- KYC documents, selfies, bank credentials, OTPs, and card details must not be
  stored in these documents. Only a provider status and opaque provider
  reference should be retained once a regulated integration is selected.
- SMS OTP, production KYC, BVN/NIN verification and identity-document collection
  are outside MVP scope. Existing status fields are reserved extension points;
  the client rules cannot promote them to a verified state.
- Rules are deny-by-default. User records are owner-scoped; Family Pocket data
  is member-scoped; member administration requires an active admin membership.
- Family access authority (`admin` or `member`) is separate from the
  `canContribute` and `isBeneficiary` capabilities, so one member can be both a
  contributor and a beneficiary without receiving admin power.
- Invitation states are `pending`, `accepted`, `declined`, `cancelled`, and the
  locally derived `expired` state. Pending invitations past `expiresAt` cannot
  be accepted. Until the trusted backend exists, an admin must cancel an expired
  invite to release its reserved beneficiary slot.
- This slice deliberately sends no email and stores no link token. Transactional
  email, single-use token hashing/redemption, resend throttling, persisted expiry
  cleanup, and authoritative notification/audit events remain trusted-backend
  work tracked in `TODO.md`.
- Firestore document deletion is disabled by the rules for financial and audit
  records. The DEV database itself also has deletion protection enabled.

## Identifier conventions

- Firebase Auth UID is the canonical user ID and the `users/{uid}` document ID.
- New profiles begin with `onboardingStatus: incomplete`. Only the owning,
  verified Google identity can complete onboarding, required personal fields
  must be present, and Security Rules prevent reverting `complete` to
  `incomplete`. Profiles created before this field was introduced are decoded as
  complete for beta-user compatibility.
- A user's one personal pocket and one MVP savings plan use deterministic IDs:
  `personal-{uid}` and `personal-plan-{uid}`. This makes onboarding retries
  idempotent and prevents duplicate owner records.
- New Family Pockets and invitations use an owner prefix plus a cryptographically
  random 128-bit hexadecimal token: `family_{uid}_{token}` and
  `invite_{uid}_{token}`.
- Development contribution IDs are deterministic idempotency paths:
  `dev_{uid}_{requestKey}` and `dev_family_{uid}_{requestKey}`.
- Application-generated IDs are limited to path-safe ASCII letters, digits,
  `_`, and `-`. Construction and validation live in
  `lib/core/data/backend_ids.dart` and are independently enforced by Firestore
  Security Rules.

## User profile and photo boundary

- `users/{uid}` is the canonical private profile. The document ID and `userId`
  equal the Firebase Auth UID, and only that verified Google identity may read
  or write it. It contains name, provider-managed email, optional date of birth
  and location details, onboarding state, notification preferences, an optional
  `profileImagePath`, and trusted `createdAt` / `updatedAt` timestamps.
- Email and email-verification state are copied from Firebase Auth and cannot be
  changed independently by the client. Profile editing is limited to the
  user-editable name, phone, location, personal, emergency-contact, photo, and
  notification fields.
- Profile photos use `users/{uid}/profile/{random32}.{jpg|png|webp}` in Firebase
  Storage. The app checks the file signature, restricts images to JPG, PNG, or
  WebP, and enforces a 5 MiB maximum before upload. Firestore accepts only a
  photo path scoped to the same UID. A successful replacement updates Firestore
  before deleting the old object; a failed profile write attempts to remove the
  newly uploaded orphan.
- While live Storage is deferred, the upload control is hidden. The app uses
  the Google account photo when available, then initials. The MVP stores no
  identity documents, selfies, BVN/NIN, or other production KYC material in the
  user profile or profile-photo area.
- The profile-photo code and prototype Storage Rules pass local emulator tests.
  DEV deployment is pending one-time creation of the project's default Firebase
  Storage bucket; production remains unchanged.

## Wallet and ledger verification

The wallet/ledger foundation is locally verified against the Firestore
emulator. Tests cover concurrent identical retries, idempotency conflicts,
resuming an interrupted pending operation, concurrent debits, insufficient
balance, cancellation, compensating reversal, invalid amounts, and
reconciliation drift. Security Rules tests prove that owners can query their
records while anonymous users, other users, and the owning Flutter client
cannot manufacture or mutate wallet, operation, or ledger data.

## Privacy-safe operational logging

Firestore mutation repositories emit structured `started`, `success`, and
`failure` lifecycle events through `BackendLogger`. Logged fields use a strict
allowlist: repository, operation, entity type, outcome, error type, record
count, and retry flag. User IDs, document IDs, names, email addresses, phone
numbers, PINs, tokens, request bodies, Firestore payloads, and exception
messages are never logged. The default sink writes JSON to `dart:developer`;
it does not create another Firestore collection or transmit logs externally.

## Healthcare provider directory

- `healthcare_providers/{providerId}` is the canonical, non-PII directory. IDs
  are stable lowercase slugs. Each document stores schema version, name and
  normalized name, category, partner status, address, state/city, coordinates,
  coarse geo cells, contacts, opening information, optional HTTPS logo/images,
  services, bounded search prefixes, active state, and lifecycle timestamps.
- Approved categories are `hospital`, `clinic`, `pharmacy`, `diagnostics`, and
  `other`; partnership is explicitly `partner` or `non_partner`.
- Verified Google users can discover only documents where `active == true`.
  Flutter's converter is read-only and Security Rules deny every client create,
  update, activation/deactivation, and delete operation.
- Firestore performs a bounded active-provider query using one selective
  dimension (geo cells, search prefix, city, state, category, or partnership),
  orders by normalized name, and caps results at 100. The repository applies
  any remaining filters and exact radius calculation locally. Composite indexes
  for those query shapes are declared in `firestore.indexes.json`.
- Coordinates use numeric latitude/longitude. A 0.25-degree coarse-cell query
  reads the origin cell and its eight neighbors, then the app uses Haversine
  distance for the exact radius and builds a Google Maps directions URL from
  the stored coordinates. Search and filters remain usable when location is
  denied or unavailable.
- `functions/src/providers/provider-directory-service.js` is the trusted admin
  and seeding boundary. It validates the full schema, URLs, coordinates,
  categories, IDs, and admin claim. Seeding can deactivate missing providers;
  deactivation retains the document and timestamps so future historical
  transactions do not lose their provider reference. It is not exported as a
  public callable and no provider dashboard is included.

## Healthcare payment foundation

- `healthcare_payments/{paymentId}` is the owner-readable, server-owned history
  projection for partner and non-partner payments. It stores integer kobo,
  normalized lifecycle and verification states, a stable transaction reference,
  provider snapshot, nullable gateway/ledger links, receipt metadata, and trusted
  timestamps. The provider snapshot preserves historical display information if
  the directory record is later changed or deactivated.
- A deterministic payment ID and request fingerprint make retries idempotent.
  The service validates the active provider, its partner/non-partner classification,
  the wallet state, amount, and available balance before creating the pending
  transaction. The ledger still repeats the balance check atomically when the
  trusted result attempts to debit, protecting concurrent payments.
- Partner and non-partner workflows share the provider-neutral payment service
  and ledger. Only trusted verification can complete a debit. Completed payments
  create one immutable ledger posting, one activity event, receipt-ready metadata,
  and one queued notification; failed or pending attempts remain stored without
  pretending that settlement succeeded.
- Non-partner payments additionally use replaceable account-resolution and
  healthcare-eligibility contracts. The local adapters are explicit mocks and
  never claim production MCC verification. Firestore stores only the account
  number's last four digits and an opaque beneficiary reference—not the raw bank
  account number.
- Clients may query only their own history by `userId` ordered by `createdAt`.
  All healthcare-payment creates, updates, deletes, verification transitions,
  ledger links, and receipt writes are denied to Flutter by Security Rules.

## Activity and transaction history

- `activities/{activityId}` is the normalized, append-only read feed. Each event
  identifies its owner, type, authoritative related entity, timestamp, optional
  Family Pocket context, and bounded display metadata. Trusted writers also add
  canonical status, amount, currency, and money-movement hints where relevant.
- `functions/src/activity/activity-history-service.js` provides newest-first
  cursor pagination, exact activity-type filtering, inclusive date filtering,
  transaction detail, clean empty results, and bounded JSON/CSV statement data.
  Opaque cursors are tied to the original owner/family scope and filters.
- Known events are resolved against `funding_transactions`,
  `healthcare_payments`, `scheduled_contributions`,
  `family_contribution_attempts`, or `savings_plans`. The returned amount,
  currency, ownership, Family Pocket linkage, provider, receipt, and lifecycle
  state are derived or validated against that authoritative source. Missing or
  mismatched sources fail closed instead of displaying unverified history.
- The feed covers direct funding, scheduled savings outcomes, healthcare
  completion/reversal/failure, Family Pocket contributions, and non-financial
  savings-plan changes. Failed and cancelled terminal events explicitly report
  no money movement.
- Personal history and exports use `userId == authenticated user`. Family Pocket
  history and exports require current active/accepted membership and stop working
  after removal or departure. Statement generation requires a bounded date range,
  caps record count, and produces spreadsheet-safe CSV cells.
- Composite indexes support owner or Family Pocket history ordered by newest
  first, with additional indexes for activity-type filters. Security Rules allow
  only verified scoped reads and deny every client activity create, update, or
  delete.

## Receipts

- `receipts/{receiptNumber}` is the canonical server-owned receipt projection.
  Its document ID equals the deterministic HealthPocket reference (`HPF-...`
  for wallet funding or `HPC-...` for healthcare), so Firestore enforces unique
  receipt numbers.
- Each receipt stores schema version, owner, HealthPocket reference, source
  transaction ID/reference and type, completed status, integer-kobo amount,
  currency, issued/created timestamps, payment method, provider and recipient
  snapshots, description, authoritative ledger links, and a deterministic
  source fingerprint.
- Trusted settlement creates the receipt in the same Firestore transaction as
  the completed funding or healthcare projection. Pending, failed, timed-out,
  and cancelled sources are rejected by the receipt builders. Repeated provider
  callbacks validate the same receipt instead of creating or overwriting one.
- Provider/recipient display fields are copied from the historical completed
  transaction, not re-read from the live provider directory. Renaming,
  deactivating, or otherwise changing a provider therefore cannot rewrite an
  issued receipt.
- The trusted receipt service supports lookup by receipt number or source
  transaction and produces JSON/plain-text download and share payloads. It
  validates the stored fingerprint before returning data and uses a not-found
  response for cross-owner lookup attempts.
- Verified users may read only receipts whose `userId` matches their identity.
  Every client create, update, and delete is denied; receipt issuance and all
  authoritative fields remain backend-only.

## Notifications

- `notification_events/{notificationId}` is the durable in-app inbox. Canonical
  documents include schema version, owner, type, category, generic display copy,
  unread/read state and `readAt`, delivery state/attempt metadata, related entity
  links, and trusted timestamps.
- Supported categories are `savings`, `funding`, `payment`, `family_pocket`,
  `security`, and `system`. Financial producers use deterministic IDs so retries
  cannot create duplicate notifications.
- Personal pages query `userId`, optionally filter `readState`, and order by
  `createdAt DESC` plus document ID as a stable tie-breaker. Opaque cursors are
  bound to the authenticated owner and filter.
- `notification_devices/{deviceId}` stores a SHA-256-derived document ID, owner,
  raw provider token, platform, active/stale/revoked status, and delivery
  metadata. This collection is completely inaccessible to client SDKs; trusted
  methods perform registration, removal, refresh, and stale-token retirement.
- Lock-screen push data is minimized to notification ID, category, and type,
  with generic title/body. Amounts, balances, account/bank data, receipts, and
  provider references are excluded.
- A Firestore inbox event is authoritative for the open-app experience. Push is
  best-effort for background/closed-app awareness. Push failure changes only
  delivery metadata and never the underlying transaction outcome.
- Verified owners can read only their own inbox documents. All client inbox
  mutations and all client access to device-token documents are denied; read
  state changes pass through the trusted service.

## Rules hardening notes

- New owner records must use canonical document IDs, and relationship IDs must
  agree with their document paths.
- Family Pocket creation must atomically include its accepted founding admin.
- Membership identity is bound to the membership document ID.
- Client-created activity/audit events are denied. Trusted payment, savings,
  healthcare, and Family Pocket services create authoritative audit events.
- Existing legacy personal/savings records can still be read through
  owner-scoped queries, but cannot be duplicated or rewritten onto a
  non-canonical path.

## Repository boundary

UI and application stores depend on the interfaces in
`lib/core/data/repository_contracts.dart`. Firebase implementations live in
`lib/core/data/firestore/firestore_repositories.dart`; this keeps provider code
out of features and leaves room for test/in-memory implementations.
