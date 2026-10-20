# Real-payment integration readiness

This document records the Number 23 audit. It is an architectural readiness
gate, not approval to move real money. Production payment integration remains
blocked until HealthPocket selects and completes onboarding with a regulated
provider, configures billing and Secret Manager, and completes provider-specific
security, compliance, sandbox, and operational testing.

## Audit and disposition

The initial audit on 2026-10-21 found twelve requirements **DONE** and pending
transaction reconciliation **PARTIAL**. Reconciliation had safe user-triggered
verification and signed-webhook paths, but no explicit server-only polling
operation that applied a provider status. `reconcileAttempt` now fills that gap
through the same idempotent settlement path. No requirement is MISSING or
BLOCKED at the architecture/mock-infrastructure level.

| Gate | Final status | Repository evidence |
| --- | --- | --- |
| Clients cannot manipulate balances | DONE | Firestore Rules deny wallet, financial-operation, ledger, provider-event, and completed-transaction writes; callable actions accept no balance field. |
| Ledger is authoritative and auditable | DONE | Immutable integer-kobo ledger postings drive wallet reconciliation; reversals are separate linked postings. |
| Financial operations are idempotent | DONE | Deterministic attempt/operation IDs and request fingerprints reject conflicting key reuse and collapse retries. |
| Gateway is provider-independent | DONE | `PaymentGateway` defines normalized statuses and provider-neutral funding, healthcare, status, beneficiary, and webhook operations. |
| Mock lifecycle coverage | DONE | Emulator tests exercise success, pending, failure, timeout, reversal, invalid signatures, duplicate delivery, and mismatched settlement data. |
| Webhook/event architecture exists | DONE | Raw-body signature verification, normalized parsing, durable event claims, replay conflict checks, and idempotent settlement exist in `payment-service.js`. No public HTTP webhook is exported before a real provider is selected. |
| Provider/beneficiary interfaces exist | DONE | Payment beneficiary resolution plus replaceable account-resolution and healthcare-eligibility contracts are defined. |
| Non-partner MCC interface is explicitly mocked | DONE | Mock account and healthcare-eligibility adapters return `productionMccVerified: false`; no production MCC claim is made. |
| Secrets are server-side only | DONE | Firebase Secret Manager parameters are declared only in Functions; mocks do not consume production credentials. |
| Rules pass adversarial tests | DONE | Firestore and Storage emulator suites cover cross-user access, forged financial state, immutable records, and server-only collections. |
| Critical services have automated tests | DONE | Ledger, funding, savings, Family Pocket, healthcare, history, receipts, notifications, coverage, abuse controls, errors, and trusted commands have emulator/service tests. |
| Pending/ambiguous reconciliation is designed | DONE | Timeouts never move money. `reconcileAttempt` polls by provider reference and applies normalized results through the existing idempotent ledger path; signed callbacks and owner-authorized verification remain alternate paths. |
| Provider replacement avoids client/domain redesign | DONE | Provider adapters sit behind server contracts. Flutter models, wallet/ledger logic, receipts, activities, and notifications consume HealthPocket-normalized records rather than provider payloads. |

## Required production adapter contract

A selected provider adapter must implement every `PaymentGateway` operation and:

- use the supplied deterministic request ID as its idempotency reference;
- translate proprietary states only into HealthPocket's normalized statuses;
- verify funding and healthcare settlement against the expected amount,
  currency, beneficiary, and provider reference supplied by the service;
- authenticate callbacks from their raw bytes before parsing them;
- return callback amount, currency, beneficiary, attempt, and provider
  references so the service can compare them with the server-created attempt;
- treat transport timeouts as ambiguous, never as success or final failure;
- keep credentials in Firebase Secret Manager and redact provider payloads from
  logs and client errors; and
- preserve duplicate-event IDs and provider references for replay protection
  and reconciliation.

The adapter must not write wallets, ledger entries, receipts, activity, or
notifications directly. It reports normalized provider facts; the existing
payment and ledger services own all HealthPocket state transitions.

## Production cutover gate

Before enabling money commands outside `demo-healthpocket`, complete all of the
following as a separate integration phase:

1. Select and onboard a regulated payment provider and confirm supported
   funding, transfer, beneficiary, reversal, webhook, and reconciliation APIs.
2. Implement its adapter and bind only the secrets that adapter consumes.
3. Export a provider-specific HTTPS webhook with raw-body signature handling,
   replay protection, rate controls, and the provider's documented response
   semantics.
4. Add a bounded scheduled reconciliation worker that calls
   `reconcileAttempt`; it must never mutate financial collections directly.
5. Run provider sandbox contract tests for amount/currency/beneficiary mismatch,
   delayed events, duplicate events, out-of-order events, timeouts, reversals,
   and provider downtime.
6. Complete security, compliance, operational alerting, support, settlement,
   and incident-recovery review before changing the production fail-closed
   switch.

Until then, deployed money commands remain unavailable and the mock gateway is
restricted to the local Functions emulator under `demo-healthpocket`.
