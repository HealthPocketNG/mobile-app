# Abuse and reliability protection

This is the MVP operational contract for callable abuse controls and ambiguous
provider outcomes. It supplements authentication, authorization, Firestore
rules, idempotency, and ledger invariants; it does not replace regulated payment
provider controls or a future compliance programme.

## Callable rate limits

`functions/src/abuse/rate-limit-service.js` uses atomic, fixed-window Firestore
buckets. Bucket IDs and stored subjects contain a SHA-256 digest rather than a
Firebase UID. Clients cannot access `_rate_limits`. Expired buckets carry an
`expiresAt` TTL field, configured in `firestore.indexes.json` for eventual
backend cleanup.

| Authenticated action | Burst limit | Sustained limit |
| --- | ---: | ---: |
| Funding, Family contribution, or healthcare initialization | 5 / 10 minutes | 20 / hour |
| Funding, Family contribution, or healthcare verification | 20 / 5 minutes | 100 / hour |
| Family invite creation | 5 / hour | 20 / day |
| Invite-code resolution | 20 / 10 minutes | 100 / day |
| Invite response | 10 / 10 minutes | 50 / day |
| Device registration | 10 / 10 minutes | 50 / day |

Limits run after verified-Google authentication and payload allowlisting, but
before the service operation. Exceeded limits use the shared `rate-limited`
public error. Operational logs contain the action and outcome, never the UID,
payload, invite code, token, account, or amount.

The Google-only MVP has no app verification-code endpoint. No such callable is
exported, and `email_verification_challenges` remains default-denied to clients.
If a code flow is introduced later, it must add hashed codes, expiry, single
use, attempt limits, resend cooldown, and an action-specific rate policy before
it can be enabled.

## Financial limits and validation

`functions/src/config/transaction-policy.js` centralizes the mock-MVP ceilings:

- wallet funding: ₦500 minimum, ₦1,000,000 maximum per request;
- Family Pocket contribution: ₦500 minimum, ₦1,000,000 maximum per request;
- healthcare payment: ₦100 minimum, ₦1,000,000 maximum per request;
- future daily aggregate placeholder: ₦5,000,000 for each flow.

Every active limit is enforced server-side with safe integer kobo. IDs,
idempotency keys, provider details, bank fields, roles, dates, and enums are
validated independently by the owning service. Zero, negative, fractional,
overflowing, malformed, and out-of-range requests fail before money movement.
Daily aggregate placeholders are intentionally not enforced until compliance
and regulated-provider requirements define identity, timezone, reversal, and
pending-transaction treatment.

## Replay and duplicate protection

Money attempts, savings mutations, Family Pocket creation/invites/contributions,
provider callbacks, scheduled contributions, receipts, and ledger operations
use deterministic IDs or request fingerprints. Identical retries return the
existing result; reuse of a key with different data fails. Completed attempts
cannot post a second ledger entry. Scheduled contributions are keyed by plan
and scheduled timestamp, so multiple workers claim the same occurrence.

## Provider downtime and reconciliation

A timeout means the final provider state is unknown. It is never projected as
a payment failure and never creates a debit, credit, receipt, or terminal
failure notification.

- Funding and healthcare verification can be retried through their existing
  owner-authorized verification actions.
- An initialization timeout without a provider reference is retried with the
  same deterministic provider request ID. A compliant adapter must make that
  request ID idempotent.
- Family contribution initialization follows the same retry rule; verification
  remains owner-scoped to the original contributor.
- Scheduled savings remains on the same due occurrence while pending. Its plan
  schedule advances only after success or a definitive failure/cancellation.
- Non-partner account/provider verification outages leave the transaction in a
  retryable pre-payment state and create no failed financial history.
- Signed provider callbacks remain a second reconciliation path. Duplicate
  callback event IDs are claimed once, and conflicting replays fail closed.

Provider `pending` and `timed_out` records are durable for later polling or
webhook completion. The server-only `reconcileAttempt` operation queries the
provider and applies its normalized result through the same idempotent payment
and ledger services. A future production worker may scan bounded pending work,
but must call that operation rather than directly changing transaction or
ledger state.
