# HealthPocket — Final MVP Backend Checklist

> **Purpose:** This is the final MVP backend hardening plan before post-MVP work begins.
>
> **MVP outcome:** HealthPocket should be structurally ready for real users to save, use Family Pockets, find healthcare providers, and eventually make healthcare transactions once the business/payment infrastructure is available.
>
> **Current constraint:** Do **not** integrate Anchor, real-money settlement, MCC verification, or production payment credentials yet. Build clean interfaces, mock/sandbox adapters, state machines, data models, security, and tests so a real payment provider can be plugged in later without rewriting the product.
>
> **Post-MVP exclusions:** KYC, partner QR payments, Apple/phone authentication, provider dashboard, investments/T-Bills, and other features explicitly deferred beyond MVP.

---

## 0. Backend Audit & Cleanup

- [x] Audit the existing Flutter/Firebase backend implementation before changing architecture.
- [x] Inventory existing Firebase Auth, Firestore collections, repositories, models, converters, Cloud Functions, Storage rules, Firestore rules, and Emulator tests.
- [x] Identify duplicate/obsolete beta code and remove or isolate it safely.
- [x] Confirm dev/emulator and future production environments are separated.
- [x] Centralize environment/configuration handling; no secrets in Flutter source.
- [x] Standardize IDs, timestamps, money representation, status enums, error models, and repository conventions.
- [x] Store money as integer **kobo**, never floating-point naira.
- [x] Ensure all server-generated timestamps use trusted server timestamps.
- [x] Add structured logging for important backend operations without logging secrets, PINs, tokens, or sensitive payloads.

## 1. Authentication & Session

- [x] Keep **Continue with Google** as the only MVP account entry method.
- [x] Create/retrieve the HealthPocket user document after successful Google authentication.
- [x] Prevent duplicate HealthPocket profiles for the same authenticated identity.
- [x] Implement first-login vs returning-user routing state.
- [x] Persist authenticated sessions correctly across app restarts.
- [x] Implement logout and clear local sensitive/session state correctly.
- [x] Implement account-disabled/deleted handling.
- [x] Implement backend/account state guards so incomplete onboarding cannot access protected flows.
- [x] Prepare an email verification-code service abstraction if HealthPocket requires an additional app-level email confirmation.
- [x] Verification codes must expire, be single-use, rate-limited, and never stored in plaintext. *(Policy/contract prepared; no second code flow is active in the Google-only MVP.)*
- [x] Implement resend cooldown and attempt limits. *(Policy/contract prepared for a future trusted backend implementation.)*
- [x] Do not treat client-side verification state as authoritative.

## 2. 6-Digit App PIN

- [x] Support creation and confirmation of a 6-digit PIN.
- [x] Never store the PIN as plaintext in Firestore, logs, analytics, or local preferences.
- [x] Prefer device-secure storage / platform credential protection for app-unlock material.
- [x] Implement PIN verification for returning authenticated users.
- [x] Implement retry/lockout protection against repeated guessing.
- [x] Implement forgotten/reset PIN flow requiring re-authentication with Google.
- [x] Ensure logout invalidates PIN-only re-entry until Google authentication occurs again.
- [x] Test app restart, token expiry, logout, PIN reset, and reinstall edge cases.

## 3. User Profile

- [x] Create a canonical user profile model.
- [x] Support name, email, date of birth, location, profile image reference, onboarding status, createdAt, and updatedAt.
- [x] Treat Google email/identity fields appropriately as identity-provider data.
- [x] Support profile editing for editable fields.
- [ ] Implement profile photo upload to Firebase Storage. *(Deferred by product decision on 2026-10-16. Code and emulator coverage are retained; live upload remains disabled pending DEV Storage billing/bucket setup.)*
- [x] Validate file type and size.
- [ ] Restrict profile image write/delete permissions to the owning user. *(Deferred by product decision on 2026-10-16. Prototype rules remain locally tested; DEV deployment awaits Storage billing/bucket setup.)*
- [x] Clean up/reconcile replaced profile images where appropriate.
- [x] Provide safe defaults/initials when no image exists.
- [x] Avoid collecting unnecessary identity/KYC data in the MVP.

## 4. Wallet & Ledger Foundation — Critical

- [ ] Introduce a wallet/account model for every HealthPocket user. *(Model, new-profile trigger, and idempotent self-provisioning callable are locally complete; DEV Functions deployment and existing-user backfill await billing.)*
- [x] Build a **ledger-first** money architecture.
- [x] Never allow Flutter to directly set or arbitrarily increment/decrement authoritative balances.
- [x] Represent every financial movement as an immutable ledger/transaction event.
- [x] Support at minimum: credit, debit, pending, completed, failed, reversed/cancelled where applicable.
- [x] Store transaction amount in kobo.
- [x] Store unique transaction/reference IDs.
- [x] Store source/type, user ID, timestamps, status, provider/family-pocket references where applicable.
- [x] Make transaction creation idempotent to prevent duplicate credits/debits.
- [x] Protect against double processing/retries.
- [x] Implement atomic/transactional balance updates where cached balances are maintained.
- [x] Prevent negative balances.
- [x] Build reconciliation checks between wallet balance and ledger.
- [x] Ensure completed financial history cannot be edited/deleted by the client.
- [x] Create server-side functions/services as the only authority allowed to finalize balance-changing operations.
- [x] Add tests for concurrency, retries, duplicate requests, interrupted operations, and insufficient balance.

## 5. Payment Provider Abstraction — No Real Payments Yet

- [x] Define a payment gateway interface independent of Anchor or any specific provider.
- [x] Define operations needed later: initialize funding, verify funding, resolve/validate beneficiary, initiate healthcare payment/transfer, verify transaction, query status, and process provider callbacks/webhooks.
- [x] Build a **mock payment adapter** for development/testing.
- [x] Make mock outcomes controllable: success, pending, failure, timeout, duplicate callback, reversal.
- [x] Define normalized internal payment statuses independent of provider-specific status names.
- [x] Create webhook/event processing architecture with signature-verification hooks ready for future implementation.
- [x] Ensure webhook processing is idempotent.
- [x] Persist external provider reference fields as nullable until integration exists.
- [x] Never mark a future real-money transaction successful merely because the client reports success.
- [x] Add clear TODO/integration boundaries for the future regulated payment provider.
- [x] Do **not** add Anchor credentials or production payment logic yet.
- [x] Do **not** implement real MCC verification yet.

## 6. Savings Plans

- [x] Create savings-plan model/repository.
- [x] Support daily, weekly, and monthly frequency.
- [x] Default contribution amount to ₦500.
- [x] Allow users to increase/change the contribution amount.
- [x] Support create, read, update, pause/resume, and appropriate cancellation state.
- [x] Enforce one clear active-plan policy per user unless the product explicitly requires otherwise.
- [x] Calculate/store next contribution date safely.
- [x] Keep scheduling logic separate from UI.
- [x] Model successful, pending, and failed scheduled contributions.
- [x] Prepare auto-contribution orchestration without attempting real debits yet.
- [x] Use the mock payment/funding adapter to test recurring contribution flows.
- [x] Ensure failed contributions never create completed ledger credits.
- [x] Make recurring jobs idempotent so the same scheduled contribution cannot execute twice.
- [x] Record savings-plan changes and contribution activity.

## 7. Add Money / Funding

- [x] Create funding transaction model.
- [x] Support preset and custom amounts.
- [x] Validate minimum/maximum/positive amount rules centrally.
- [x] Implement funding lifecycle: created → pending → completed/failed/cancelled as appropriate.
- [x] Use mock payment adapter for MVP backend testing until business/payment setup is ready.
- [x] Credit wallet only after trusted backend verification.
- [x] Generate ledger entry and activity event after completion.
- [x] Generate receipt-ready transaction metadata.
- [x] Generate notification event after completion/failure where appropriate.
- [x] Test retry, duplicate verification, delayed confirmation, failure, and timeout paths.

## 8. Family Pocket

- [x] Create Family Pocket model and repository.
- [x] Support pocket name, optional description, image, frequency, default contribution amount, owner, timestamps, and status.
- [ ] Support Family Pocket image upload/storage.
- [x] Create membership model with explicit roles/permissions.
- [x] Support owner/admin/member rules required by the MVP.
- [x] Create invite model.
- [x] Support invite creation, acceptance, decline/expiry where appropriate, and duplicate-invite prevention.
- [x] Support invite links/codes without exposing unauthorized pocket data.
- [x] Allow members to leave subject to ownership rules.
- [x] Allow authorized owner/admin actions to remove members.
- [x] Prevent unauthorized membership manipulation.
- [x] Define ownership-transfer or pocket-close behavior before allowing an owner to leave.
- [x] Track each member's contribution independently.
- [x] Maintain Family Pocket balance through ledger-backed contribution records.
- [x] Never permit the client to directly alter Family Pocket balances.
- [x] Implement Family Pocket activity history.
- [x] Implement contribution frequency/default amount behavior.
- [x] Prepare Family Pocket funding through the same payment abstraction.
- [x] Test concurrent member contributions.
- [x] Test permissions extensively with Emulator Suite.

## 9. Healthcare Provider Directory / Find Care

- [x] Create canonical healthcare provider model.
- [x] Support partner and non-partner provider status.
- [x] Store provider name, category/type, address, state/city, coordinates, contact details, opening information where available, logo/image references, and active status.
- [x] Support hospitals, clinics, pharmacies, diagnostics and other approved healthcare categories.
- [x] Implement provider search.
- [x] Implement category filters.
- [x] Implement partner/non-partner filtering.
- [x] Implement location-aware querying appropriate for the current Firebase architecture.
- [x] Store latitude/longitude required for map/directions integration.
- [x] Return data needed for the app to open Google Maps directions.
- [x] Handle no-location-permission and no-nearby-provider states cleanly.
- [x] Ensure provider records cannot be edited by ordinary users.
- [x] Create an admin/seeding mechanism for maintaining provider records without building a provider dashboard.
- [x] Add provider activation/deactivation so closed/invalid providers can be removed from discovery without destroying historical transactions.

## 10. Healthcare Payment Flow — Prepared, Mocked

### HealthPocket Partners

- [x] Create healthcare-payment transaction model.
- [x] Allow user to select an active HP partner and enter an amount.
- [x] Validate amount and available HealthPocket balance.
- [x] Validate provider exists and is active.
- [x] Create pending transaction before processing.
- [x] Use mock payment/settlement adapter for now.
- [x] Finalize debit only through trusted backend logic.
- [x] Create ledger debit, activity event, receipt metadata, and notification after successful mock settlement.
- [x] Preserve failed/pending transaction records for debugging and user history.
- [x] Do not implement QR payment for MVP.

### Non-Partners

- [x] Build the non-partner transaction data model and workflow now.
- [x] Support beneficiary/provider bank-detail fields required by the future integration.
- [x] Create account-resolution/beneficiary-verification interface.
- [x] Create healthcare-provider/MCC-verification interface but leave the real implementation unconnected.
- [x] Use explicit mock verification states for development.
- [x] Do not fake production MCC verification.
- [x] Require a verified/allowed state before the mock payment flow can proceed.
- [x] Build failure state for provider verification rejection.
- [x] Keep partner and non-partner flows distinguishable in transaction records.
- [x] Make the future provider/MCC service replaceable without rewriting transaction/business logic.

## 11. Activity & Transaction History

- [x] Create one normalized activity/read model sourced from authoritative backend events.
- [x] Include savings contributions, direct top-ups, healthcare payments, Family Pocket contributions, reversals/failures where appropriate.
- [x] Support pagination.
- [x] Support filters by transaction/activity type.
- [x] Support date-range filters.
- [x] Ensure activity amounts/statuses match authoritative transaction/ledger data.
- [x] Provide transaction-detail endpoint/repository method.
- [x] Do not allow users to edit financial history.
- [x] Implement empty state cleanly.
- [x] Prepare statement/export data generation for MVP.
- [x] Ensure export only contains records belonging to the authenticated user and permitted Family Pocket context.

## 12. Receipts

- [x] Define canonical receipt data model.
- [x] Include HealthPocket reference ID, transaction ID, amount, date/time, provider/recipient, payment type/method, status, and relevant user-facing metadata.
- [x] Generate receipts from authoritative completed transaction data rather than client input.
- [x] Ensure receipt/reference IDs are unique.
- [x] Prevent receipt tampering.
- [x] Build backend data/export contract needed for download/share.
- [x] Ensure failed/pending transactions cannot masquerade as completed receipts.
- [x] Preserve historical receipt data even if provider profile details later change.

## 13. Notifications

- [x] Create in-app notification model.
- [x] Support read/unread state.
- [x] Support notification types: savings, funding, payment, Family Pocket, security/system.
- [x] Generate notifications from backend events rather than UI assumptions.
- [x] Add pagination/query strategy.
- [x] Implement mark-read / mark-all-read securely.
- [x] Prepare Firebase Cloud Messaging device-token model.
- [x] Support token registration/removal/refresh.
- [x] Build push-notification service abstraction.
- [x] Ensure notification failure never changes the underlying transaction outcome.
- [x] Avoid placing sensitive financial/account data unnecessarily in lock-screen push payloads.
- [x] Test multiple devices and stale token handling.

## 14. “What Can My Balance Cover?”

- [x] Create `coverageItems`/care-cost model.
- [ ] Start with approximately 5 curated healthcare items based on partner-supplied MVP data. *(The seed service and five-item emulator fixture are complete; awaiting genuine partner-supplied prices before creating the live catalog.)*
- [x] Store item name, category, indicative price, source/provider reference, location/context where relevant, last-updated timestamp, and active status.
- [x] Treat prices as indicative estimates rather than guaranteed treatment prices.
- [x] Compare each active item's price against the user's available balance.
- [x] Return `covered`, `amountRemaining`, or equivalent derived state.
- [x] When balance is ₦0, return the appropriate encouragement/empty-state data instead of pretending services are affordable.
- [x] Do not hard-code prices into Flutter.
- [x] Make coverage items remotely maintainable through backend/admin tooling.
- [x] Ensure stale/inactive pricing can be disabled.

## 15. Email Infrastructure

- [x] Define centralized transactional email service abstraction.
- [x] Implement templates/events required for the final MVP.
- [x] Keep email sending server-side.
- [x] Add rate limits/retry strategy.
- [x] Do not expose email-provider credentials to Flutter.
- [x] Prevent duplicate sends for idempotent financial events.
- [x] Separate essential transactional/security messages from optional marketing communications.
- [x] Wire verification-code email flow if retained. *(Not retained for the Google-only MVP; the reserved backend-only challenge boundary stores no plaintext codes.)*
- [x] Prepare relevant transaction/family/security email event hooks without making email delivery a prerequisite for transaction correctness.

## 16. Backend System/Error States

- [x] Standardize backend error codes/messages.
- [x] Cover unauthenticated/unauthorized.
- [x] Cover invalid input.
- [x] Cover offline/network/retry scenarios at repository boundary.
- [x] Cover insufficient balance.
- [x] Cover provider not found/inactive.
- [x] Cover payment pending/failed.
- [x] Cover duplicate request/idempotency conflict.
- [x] Cover verification failure.
- [x] Cover savings-plan failure.
- [x] Cover Family Pocket permission/invite errors.
- [x] Avoid exposing internal stack traces/provider secrets to users.
- [x] Make errors actionable enough for Flutter to render the correct state.

## 17. Firestore & Storage Security

- [x] Default-deny security posture.
- [x] Users may only read/write their permitted profile data.
- [x] Wallet balances and completed financial records cannot be manipulated by clients.
- [x] Ledger writes restricted to trusted backend.
- [x] Transaction finalization restricted to trusted backend.
- [x] Provider-directory writes restricted to trusted/admin backend.
- [x] Coverage-item writes restricted to trusted/admin backend.
- [x] Family Pocket rules enforce membership and role permissions.
- [x] Family Pocket private data inaccessible to non-members.
- [x] Notifications accessible only to intended user.
- [x] Storage rules protect profile and Family Pocket images.
- [x] Validate paths, ownership, file metadata/type/size where possible.
- [x] Test cross-user attacks in Emulator Suite.
- [x] Test guessed document IDs.
- [x] Test unauthorized update/delete attempts.
- [x] Test privilege escalation attempts.

*Verified locally in the Firestore and Storage emulators. Live Storage rules
remain undeployed until the DEV bucket/billing blocker is resolved; the earlier
live-upload checklist items remain open.*

## 18. Cloud Functions / Trusted Backend

- [x] Identify every operation that must not trust Flutter.
- [x] Move authoritative financial mutations into trusted backend functions/services.
- [x] Validate authentication on every callable/API operation.
- [x] Validate authorization separately from authentication.
- [x] Validate all request payloads server-side.
- [x] Add idempotency support to money-moving operations.
- [x] Use transactions/batches where consistency requires them.
- [x] Add timeout/retry-safe behavior.
- [x] Add structured audit logs for sensitive operations.
- [x] Keep provider/payment secrets in server-side secret/config management.
- [x] Design functions so future Anchor/payment-provider integration replaces adapters rather than business logic.

*The callable boundary and mock money flows are verified locally. Money commands
fail closed outside the `demo-healthpocket` emulator until a regulated provider
adapter and its Secret Manager values are configured; no live Functions deploy
was performed.*

## 19. Data Integrity & Indexing

- [x] Review Firestore schema for query patterns before launch.
- [x] Create required composite indexes.
- [x] Avoid unbounded reads.
- [x] Paginate potentially large collections.
- [x] Eliminate N+1-style Firestore access where practical.
- [x] Define deletion/retention behavior for user accounts while preserving records that may later require financial/legal retention.
- [x] Ensure references to deleted/deactivated providers do not break historical transactions.
- [x] Add schema/version strategy where useful.
- [x] Add safe migration/seeding scripts for provider and coverage data.

*Verified against the Firestore Standard emulator: the complete backend suite
passes 115/115 tests, including bulk activity-source reads and idempotent,
checksum-locked catalog releases. Flutter repository conventions pass 9/9
tests. The new reconciliation indexes are declared in
`firestore.indexes.json` but were not deployed to DEV or production in this
phase. Retention periods remain intentionally unset until Nigerian
legal/compliance and regulated-provider requirements are approved.*

## 20. Abuse & Reliability Protection

- [x] Rate-limit sensitive operations where appropriate.
- [x] Protect verification-code endpoints.
- [x] Protect invite creation.
- [x] Protect payment/funding initialization.
- [x] Validate all amounts and IDs server-side.
- [x] Reject malformed/negative/zero financial requests.
- [x] Prevent replay of completed requests.
- [x] Prevent duplicate scheduled savings execution.
- [x] Add reasonable transaction limits/config placeholders for future payment compliance requirements.
- [x] Design for provider API downtime without corrupting transaction state.
- [x] Ensure a timeout is not automatically treated as payment failure when final status is unknown.
- [x] Provide reconciliation path for ambiguous/pending transactions.

*Verified locally with Firestore Standard: atomic hashed-subject rate limits,
idempotent retries, duplicate-worker protection, validation/transaction caps,
and pending/timeout reconciliation are covered by the backend suite. The suite
passes 123/123 tests, and Functions export discovery still exposes only
`createWalletForNewProfile`, `ensureMyWallet`, and `trustedBackend`. The
rate-limit TTL configuration is declared locally but was not deployed in this
phase.*

## 21. Emulator & Automated Tests

- [x] Run Firebase Emulator Suite for backend development.
- [x] Unit-test repositories/services.
- [x] Test Firestore security rules.
- [x] Test Storage rules.
- [x] Test Cloud Functions.
- [x] Test wallet/ledger invariants.
- [x] Test concurrent balance operations.
- [x] Test idempotency.
- [x] Test funding success/failure/pending/retry.
- [x] Test healthcare payment success/failure/pending/retry.
- [x] Test non-partner mock verification approval/rejection.
- [x] Test savings scheduling.
- [x] Test Family Pocket permissions and concurrent contributions.
- [x] Test notification generation.
- [x] Test receipt generation.
- [x] Test cross-user unauthorized access.
- [x] Build end-to-end backend test scenarios representing realistic user journeys.

*Verified locally on 2026-10-20 using the Firestore Standard, Storage, and
Functions emulators. Functions/services pass 126/126 tests, Firestore rules
pass 48/48, Storage rules pass 6/6, and Flutter passes 93/93. Three realistic
funding, healthcare, and Family Pocket journeys now run through the trusted
callable boundary, including idempotent retries and cross-user denials. The
actual Functions runtime discovered only `createWalletForNewProfile`,
`ensureMyWallet`, and `trustedBackend`; its callable-protocol smoke test passed.
Commands and coverage are documented in `docs/backend-testing.md`. No live
Firebase resources were changed in this phase.*

## 22. MVP End-to-End Backend Journeys

All of these must work with mock payment infrastructure before real payment integration begins.

- [x] New user → Google auth → onboarding → profile → PIN → dashboard-ready state.
- [x] Returning authenticated user → PIN → session restored.
- [x] Logout → PIN no longer sufficient → Google authentication required.
- [x] User creates/edits/pauses savings plan.
- [x] Scheduled contribution → mock success → ledger credit → balance/activity/notification updated once.
- [x] Scheduled contribution → mock failure → no credit → failure state recorded.
- [x] User manually adds money → mock success → wallet/ledger/activity/receipt/notification consistent.
- [ ] User creates Family Pocket → uploads image → invites member → member joins.
- [x] Multiple members contribute → Family Pocket totals remain consistent.
- [x] Unauthorized user cannot read/write another Family Pocket.
- [x] User discovers nearby partner/non-partner providers.
- [x] User opens provider details and receives valid coordinates for Google Maps directions.
- [x] User initiates partner healthcare payment → mock settlement → debit → receipt/activity/notification.
- [x] Insufficient balance blocks healthcare payment without creating an incorrect debit.
- [x] Non-partner provider → mock account/provider verification → mock payment.
- [x] Non-partner verification failure → payment blocked safely.
- [x] Duplicate/retried payment request cannot debit twice.
- [x] User views/filter/searches transaction activity.
- [x] User accesses completed transaction receipt/export data.
- [x] Coverage engine reacts correctly to ₦0, low, sufficient, and high balances.
- [x] Backend remains internally consistent after simulated failures and retries.

_Verified locally on 2026-10-21: Functions/services 128/128, Firestore and Storage rules 54/54, Flutter 94/94, and trusted-backend journeys 5/5. The Family Pocket create/invite/join flow and Storage permissions are covered, but the combined image-upload journey remains unchecked because live uploads are intentionally disabled until billing is resolved. No live Firebase resources were changed._

## 23. Real-Payment Integration Readiness Gate

Do **not** begin real payment integration until this section passes.

- [x] No client can directly manipulate authoritative wallet balances.
- [x] Ledger is authoritative/auditable.
- [x] Financial operations are idempotent.
- [x] Payment gateway abstraction is provider-independent.
- [x] Mock gateway exercises success, pending, failure, timeout, reversal, and duplicate-event paths.
- [x] Webhook/event architecture exists.
- [x] Provider/beneficiary verification interfaces exist.
- [x] Non-partner healthcare verification/MCC interface exists but is clearly mocked/unimplemented.
- [x] Secrets are server-side only.
- [x] Security rules pass adversarial tests.
- [x] Critical Cloud Functions/services have automated tests.
- [x] Pending/ambiguous transaction reconciliation is designed.
- [x] Provider/payment integration can be added without changing the Flutter domain models or rewriting wallet/ledger logic.

_Verified locally on 2026-10-21 against Firestore Standard and mock infrastructure: Functions/services 130/130, Firestore and Storage rules 54/54, Flutter 94/94. Production payment commands remain fail-closed; no provider, credential, live webhook, real settlement, or live Firebase resource was enabled. The full audit and cutover conditions are in `docs/real-payment-readiness.md`._

---

# Explicitly NOT Part of This MVP Backend

Do not let Codex expand scope into these items:

- KYC/identity-verification infrastructure.
- QR scan-to-pay and unique partner QR infrastructure.
- Apple Sign-In.
- Phone-number authentication.
- Provider/merchant dashboard.
- T-Bills/investment products.
- Production Anchor integration before business onboarding is available.
- Production MCC verification before the required payment/provider infrastructure is available.
- Unrelated post-MVP features.

---

# Definition of Done

The backend MVP is considered ready when:

1. Core user, savings, Family Pocket, provider discovery, activity, receipts, notifications, and coverage functionality work end-to-end.
2. Every balance-changing operation flows through trusted backend logic and an auditable ledger.
3. Real payments are represented by a clean provider abstraction and thoroughly tested mock implementation.
4. Partner and non-partner healthcare-payment workflows can be exercised end-to-end without real settlement.
5. Firebase/Storage security rules prevent cross-user access and direct financial manipulation.
6. Failure, retry, duplicate, pending, and concurrency scenarios do not corrupt balances or transaction history.
7. Replacing the mock payment/verification adapters with the eventual regulated provider integration does **not** require redesigning HealthPocket's core backend architecture.

---

## Codex Working Rule

**Do not implement this entire checklist in one pass.** First audit the existing repository and mark each item as `DONE`, `PARTIAL`, `MISSING`, or `BLOCKED`. Preserve working architecture where it satisfies the requirements. Then implement one subsystem at a time, run its tests, and only proceed when the subsystem is stable. Do not invent production payment behavior for currently blocked integrations.
