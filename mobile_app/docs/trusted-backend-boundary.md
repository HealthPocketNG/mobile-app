# Trusted backend boundary

`trustedBackend` is the single authenticated Cloud Functions command entry
point. It accepts `{action, payload}`, rejects unknown or extra fields, requires
a verified Google Firebase identity, and derives every `userId`, `actorId`, and
`ownerId` from that identity. Client-supplied authority fields are rejected.

## Client-callable operations

| Area | Allowed commands | Authority |
| --- | --- | --- |
| Wallet | `wallet.ensure` | Current user only; cannot accept a balance |
| Funding | `funding.initialize`, `funding.verify` | Current user's attempt; emulator-only until a regulated adapter is configured |
| Savings | `savings.create`, `update`, `pause`, `resume`, `cancel` | Current user's canonical plan |
| Family Pocket | create/update/invite/respond/member/ownership/close/contribution commands | Current identity plus backend-owned membership role checks |
| Healthcare payments | partner/non-partner initialize and verify | Current user's payment; emulator-only until regulated adapters are configured |
| Coverage | `coverage.evaluate` | Reads the current user's server-owned wallet balance |
| Notifications | list/read/device-token commands | Current user only |
| Activity | list/detail/statement | Current user or current Family Pocket membership |
| Receipts | get/export | Current user only |

Money commands are enabled only when the Functions emulator is running under
the `demo-healthpocket` project. Deployed functions fail closed with
`unavailable`; the mock gateway can never become a production settlement path.

## Server-only operations

Flutter has no command for ledger creation/finalization/reversal, wallet
reconciliation, provider or coverage administration, payment webhook
processing, scheduled-savings execution, Family Pocket reconciliation,
notification dispatch, email dispatch, or any admin seed operation. These are
reserved for signed provider webhooks, scheduled functions, task queues, or
explicitly authorized administrative tooling when those entry points are
introduced.

## Reliability and secrets

- Money and plan mutations use deterministic IDs/request fingerprints and
  reject conflicting reuse of an idempotency key.
- Balance changes, final state, receipts, activities, and notifications are
  committed through service-owned Firestore transactions/batches.
- Provider timeouts remain pending/timed-out and can be checked safely; timeout
  is never interpreted as successful settlement or an automatic final failure.
- The server-only payment reconciler polls ambiguous attempts and applies a
  normalized result through the same idempotent ledger path as verification
  and signed callbacks. It is intentionally absent from callable actions.
- Signed callbacks are rejected unless provider reference, amount, currency,
  and beneficiary match the server-created attempt.
- Callable logs contain only component, operation, outcome, normalized error
  type/code, and correlation ID—never payloads, user IDs, emails, tokens,
  account numbers, amounts, or provider responses.
- `functions/src/config/backend-config.js` declares payment, webhook, email,
  and push credentials as Firebase Secret Manager parameters. Current mock
  adapters do not read them. Future production adapters must receive only the
  specific secret bindings they consume.
- Payment, account-resolution, healthcare-eligibility, email, and push
  integrations are interfaces. Replacing a mock adapter does not replace
  ledger, idempotency, authorization, receipt, notification, or transaction
  orchestration.

The readiness audit and provider-adapter cutover requirements are recorded in
`real-payment-readiness.md`.
