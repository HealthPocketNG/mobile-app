# HealthPocket trusted backend

This Node 22 Cloud Functions codebase owns authoritative wallet and ledger
mutations. Flutter has no API that can set a balance or create a completed
ledger entry.

`createWalletForNewProfile` creates a zero-balance wallet after a user profile
is created. `ensureMyWallet` is an authenticated, idempotent backfill path and
cannot accept an amount. Future funding and payment functions must import
`src/ledger-service.js` only after their provider-side verification succeeds.

Run the transaction suite from the repository root:

```powershell
firebase emulators:exec --only firestore "npm --prefix functions test" --project demo-healthpocket
```

Run Functions and Firestore together to validate function discovery:

```powershell
firebase emulators:exec --only firestore,functions "npm --prefix functions test" --project demo-healthpocket
```

DEV deployment and existing-user wallet backfill are intentionally deferred
until Cloud Billing is available. Do not treat the older `dev_simulation`
contribution records as real money or migrate them into authoritative wallets.

## Payment-provider boundary

`src/payments/payment-gateway.js` defines the provider-neutral contract and the
normalized statuses used by HealthPocket. `mock-payment-gateway.js` is strictly
for local development and emulator tests; its outcomes can be scripted as
success, pending, failure, timeout, or reversal, and it can generate repeated
signed callback deliveries. It makes no network calls.

`payment-service.js` persists server-owned `payment_attempts` and
`provider_events`. An initialization response cannot post to the ledger. Only
an explicit adapter verification result or a signature-verified callback can
do so, and the resulting ledger operation and callback processing are
idempotent. Raw callback bodies are not persisted.

TODO when a regulated provider is selected:

- implement the full `PaymentGateway` contract in a separate adapter;
- use Secret Manager for provider credentials and webhook secrets;
- make provider initialization idempotent with the supplied `requestId`;
- verify callbacks from their raw bytes and map proprietary states to the
  normalized statuses before returning them;
- retrieve and compare provider-side amount, currency, beneficiary, and
  reference data against the server-created attempt; and
- add the provider's regulated healthcare-eligibility/MCC controls separately.

No production payment endpoint, provider credential, settlement logic, or real
MCC verification is included in this codebase yet.

## Add Money / funding

Wallet funding uses the payment boundary above but exposes a separate,
owner-readable `funding_transactions` projection. The authoritative limits are
₦500 minimum and ₦1,000,000 maximum; the supported UI presets are ₦500, ₦1,000,
₦2,000, ₦5,000, and ₦10,000, while any whole-kobo custom amount inside the
limits is accepted.

Funding transactions retain created, pending, completed, failed, cancelled,
and reversed lifecycle states. A provider initialization response never credits
the wallet. Only trusted verification or a signature-verified callback can
create the completed funding ledger entry. Completed records include a stable
transaction reference, receipt number, amount, currency, provider/channel,
description, and completion time.

Completion creates a deterministic activity record and a queued notification
event. Failure, timeout, and cancellation create deterministic notification
events but never a completed ledger credit. Repeated verification and callback
delivery reuse the same payment, ledger, activity, receipt, and notification
records.

`funding-policy.js` and the mock provider are currently local-backend building
blocks. No production funding callable, real bank redirect, credentials, or
real-money movement is exported or deployed.

## Savings-plan orchestration

`src/savings/savings-plan-service.js` owns the trusted savings-plan lifecycle:
create, read, update, pause, resume, terminal cancellation, due-plan discovery,
and recurring contribution execution. The canonical
`personal-plan-{userId}` document enforces one MVP plan per user. The default
amount is 50,000 kobo (₦500), and schedule calculation supports daily, weekly,
and calendar-clamped monthly recurrence in UTC.

Each plan change has a deterministic `savings_plan_operations` record and a
server-created activity event. Each recurring occurrence has one deterministic
`scheduled_contributions` record, so retries cannot create a second payment
attempt or ledger credit. Pending, succeeded, and failed outcomes are retained.
Failed mock funding creates no completed ledger posting.

`runDueContributions` is an orchestration entry point for emulator tests and a
future scheduler. It is intentionally not exported as a deployed scheduled
function yet: the current tests wire it only to the local mock payment adapter,
and it performs no real bank debit or production payment call.

## Family Pocket

`src/family/family-pocket-service.js` is the trusted boundary for Family Pocket
creation, settings, membership, invitations, ownership, closure, and funding.
Pocket records support a name, optional description/image path, daily/weekly/
monthly frequency, default contribution amount, explicit owner, timestamps,
status, and a transactionally maintained cached balance.

Membership roles are `owner`, `admin`, and `member`. Invite links contain a
high-entropy bearer code; only its SHA-256 hash is stored. Acceptance requires
a verified authentication email matching the normalized invite email. A
deterministic uniqueness record prevents two pending invitations to the same
email. Owners cannot leave or be removed: ownership must first be transferred,
or the pocket must be closed.

Family funding uses the same provider-neutral payment gateway contract as Add
Money. Initialization never changes a balance. Trusted provider verification
creates exactly one immutable `family_ledger_entries` posting and atomically
increments both the pocket balance and that member's lifetime contribution.
It also creates deterministic activity and notification records. Failed,
pending, and timed-out attempts never credit the pocket; delayed verification
can safely complete later. Reconciliation derives the expected balance from
completed ledger postings.

No production Family Pocket callable or real-money payment endpoint is
exported yet. `imagePath` is ready in the model, but actual Family Pocket image
upload remains deferred with the broader Cloud Storage billing work.

## Healthcare provider directory

`src/providers/provider-directory-service.js` is the trusted maintenance
boundary for `healthcare_providers`. Its upsert, seed, activate, and deactivate
operations require an explicit admin custom claim and validate the complete
non-PII provider schema before the Admin SDK writes it. No client-callable
directory mutation or provider dashboard is exported.

The seed operation accepts at most 400 records per batch. With
`deactivateMissing: true`, active records absent from the seed are marked
inactive and timestamped rather than deleted. This preserves stable provider
IDs for transaction history. Run the service tests through the standard
Firestore emulator command above; no live deployment or production data is
required.

## Healthcare payments

`src/healthcare/healthcare-payment-service.js` orchestrates partner and
non-partner healthcare payments on top of the existing provider-neutral payment
service and ledger. It validates the active provider, correct directory flow,
integer-kobo amount, wallet state, and available balance before creating a
pending transaction. Trusted payment verification performs the authoritative
ledger debit; the client cannot report success or mutate the resulting record.

Completed mock settlement creates deterministic receipt metadata, activity,
notification, payment-attempt, financial-operation, and ledger records. Retries
reuse the same IDs and cannot debit twice. Pending, failed, cancelled, and
reversed states remain explicit and retained for history.

`healthcare-verification.js` defines replaceable account-resolution and
healthcare-eligibility contracts. The local implementations in
`mock-healthcare-verification.js` are test-only: they never perform or claim
production MCC verification. Non-partner persistence contains only safe bank
display fields (last four digits, bank identity/name, and an opaque beneficiary
reference); the raw account number is not stored.

No healthcare callable, QR payment, production settlement endpoint, provider
credential, or real MCC service is exported or deployed in this phase.

## Activity and transaction history

`src/activity/activity-history-service.js` is the trusted read boundary for the
append-only `activities` feed. It exposes cursor-paginated personal or permitted
Family Pocket history, exact activity-type and inclusive date-range filters,
transaction detail, an explicit empty state, and bounded statement generation
with CSV output. Cursors are bound to their original scope and filters.

The service resolves each known activity against its authoritative funding,
healthcare, savings, Family Pocket, or plan record. Amount, currency, ownership,
Family Pocket linkage, status, provider snapshot, and receipt metadata therefore
cannot be silently replaced by stale client-facing activity metadata. Missing or
mismatched sources fail closed as integrity errors. Funding and healthcare
terminal failures now create non-financial activity records; only completed or
reversed events are marked as money movement.

Personal exports contain only records whose `userId` is the authenticated actor.
Family Pocket exports require a current active/accepted membership and exclude
removed or departed members. Export windows are limited to 366 days and 5,000
records. Spreadsheet-formula prefixes are neutralized in generated CSV cells.
Clients retain read-only access under Firestore Security Rules; every activity
create, update, and delete remains trusted-backend-only. No public history
callable or live deployment is included in this phase.

## Receipts

`src/receipts/receipt-service.js` defines the canonical immutable
`receipts/{receiptNumber}` model for completed wallet funding and healthcare
payments. The document ID is the HealthPocket receipt number (`HPF-...` or
`HPC-...`), making receipt-number uniqueness enforceable by Firestore. Every
receipt includes the owner, source transaction ID/reference, integer-kobo
amount, currency, issued time, completed status, payment type/method, provider
and recipient snapshots, description, and authoritative ledger links.

Receipt creation runs inside the same trusted transaction that projects a
successful payment outcome. Pending, failed, timed-out, and cancelled attempts
cannot call the receipt builders. Idempotent settlement retries validate the
existing receipt fingerprint instead of overwriting it. Healthcare provider
details are copied from the payment's historical provider snapshot, so later
directory edits or deactivation do not change an issued receipt.

The receipt read service supports owner-only lookup by receipt number or source
transaction and returns JSON or plain-text download/share contracts. Stored
receipts are checked against a deterministic source fingerprint and fail closed
if corrupted. Clients may read only their own receipts and cannot create,
update, or delete them. No PDF renderer, frontend share sheet, public callable,
or deployment is included in this backend phase.

## Notifications

`src/notifications/notification-service.js` is the trusted notification
boundary. It stores a durable, owner-scoped `notification_events` inbox with
canonical categories, unread/read state, newest-first cursor pagination,
single-read and bounded mark-all-read operations. Funding, savings,
healthcare-payment, verification-failure, and Family Pocket outcomes create
deterministic inbox events from trusted backend flows; Flutter does not
manufacture financial notifications.

`notification_devices` stores deterministic device IDs, raw provider tokens,
platform, lifecycle status, and delivery metadata. Registration, revocation,
refresh, delivery updates, and stale-token retirement are backend-only. The
push provider is isolated behind `PushNotificationService`; the controllable
mock adapter exercises multiple devices, stale tokens, partial delivery, and
provider failure without requiring FCM credentials. A real FCM adapter can
replace it without changing transaction services or the inbox model.

Push dispatch is downstream of the source transaction. Delivery failure
updates only notification/device metadata and never changes a funding, savings,
Family Pocket, or healthcare outcome. Lock-screen payloads contain only generic
title/body plus notification ID, category, and type. Amounts, balances,
bank/account data, receipts, and provider references remain inside authenticated
app views.

The open-app experience should query or subscribe to the durable inbox. The
background/closed-app experience should use FCM after a production adapter and
trusted invocation boundary are connected. Flutter foreground listeners,
permission prompts, system-tray behavior, deep links, and physical-device
lifecycle testing remain frontend/integration work. No FCM credential or live
deployment is included here.
