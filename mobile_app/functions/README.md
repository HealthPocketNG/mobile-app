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
