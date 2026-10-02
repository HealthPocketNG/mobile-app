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
- [ ] Standardize IDs, timestamps, money representation, status enums, error models, and repository conventions.
- [x] Store money as integer **kobo**, never floating-point naira.
- [x] Ensure all server-generated timestamps use trusted server timestamps.
- [ ] Add structured logging for important backend operations without logging secrets, PINs, tokens, or sensitive payloads.

## 1. Authentication & Session

- [x] Keep **Continue with Google** as the only MVP account entry method.
- [ ] Create/retrieve the HealthPocket user document after successful Google authentication.
- [ ] Prevent duplicate HealthPocket profiles for the same authenticated identity.
- [ ] Implement first-login vs returning-user routing state.
- [ ] Persist authenticated sessions correctly across app restarts.
- [ ] Implement logout and clear local sensitive/session state correctly.
- [ ] Implement account-disabled/deleted handling.
- [ ] Implement backend/account state guards so incomplete onboarding cannot access protected flows.
- [ ] Prepare an email verification-code service abstraction if HealthPocket requires an additional app-level email confirmation.
- [ ] Verification codes must expire, be single-use, rate-limited, and never stored in plaintext.
- [ ] Implement resend cooldown and attempt limits.
- [ ] Do not treat client-side verification state as authoritative.

## 2. 6-Digit App PIN

- [ ] Support creation and confirmation of a 6-digit PIN.
- [ ] Never store the PIN as plaintext in Firestore, logs, analytics, or local preferences.
- [ ] Prefer device-secure storage / platform credential protection for app-unlock material.
- [ ] Implement PIN verification for returning authenticated users.
- [ ] Implement retry/lockout protection against repeated guessing.
- [ ] Implement forgotten/reset PIN flow requiring re-authentication with Google.
- [ ] Ensure logout invalidates PIN-only re-entry until Google authentication occurs again.
- [ ] Test app restart, token expiry, logout, PIN reset, and reinstall edge cases.

## 3. User Profile

- [ ] Create a canonical user profile model.
- [ ] Support name, email, date of birth, location, profile image reference, onboarding status, createdAt, and updatedAt.
- [ ] Treat Google email/identity fields appropriately as identity-provider data.
- [ ] Support profile editing for editable fields.
- [ ] Implement profile photo upload to Firebase Storage.
- [ ] Validate file type and size.
- [ ] Restrict profile image write/delete permissions to the owning user.
- [ ] Clean up/reconcile replaced profile images where appropriate.
- [ ] Provide safe defaults/initials when no image exists.
- [ ] Avoid collecting unnecessary identity/KYC data in the MVP.

## 4. Wallet & Ledger Foundation — Critical

- [ ] Introduce a wallet/account model for every HealthPocket user.
- [ ] Build a **ledger-first** money architecture.
- [ ] Never allow Flutter to directly set or arbitrarily increment/decrement authoritative balances.
- [ ] Represent every financial movement as an immutable ledger/transaction event.
- [ ] Support at minimum: credit, debit, pending, completed, failed, reversed/cancelled where applicable.
- [ ] Store transaction amount in kobo.
- [ ] Store unique transaction/reference IDs.
- [ ] Store source/type, user ID, timestamps, status, provider/family-pocket references where applicable.
- [ ] Make transaction creation idempotent to prevent duplicate credits/debits.
- [ ] Protect against double processing/retries.
- [ ] Implement atomic/transactional balance updates where cached balances are maintained.
- [ ] Prevent negative balances.
- [ ] Build reconciliation checks between wallet balance and ledger.
- [ ] Ensure completed financial history cannot be edited/deleted by the client.
- [ ] Create server-side functions/services as the only authority allowed to finalize balance-changing operations.
- [ ] Add tests for concurrency, retries, duplicate requests, interrupted operations, and insufficient balance.

## 5. Payment Provider Abstraction — No Real Payments Yet

- [ ] Define a payment gateway interface independent of Anchor or any specific provider.
- [ ] Define operations needed later: initialize funding, verify funding, resolve/validate beneficiary, initiate healthcare payment/transfer, verify transaction, query status, and process provider callbacks/webhooks.
- [ ] Build a **mock payment adapter** for development/testing.
- [ ] Make mock outcomes controllable: success, pending, failure, timeout, duplicate callback, reversal.
- [ ] Define normalized internal payment statuses independent of provider-specific status names.
- [ ] Create webhook/event processing architecture with signature-verification hooks ready for future implementation.
- [ ] Ensure webhook processing is idempotent.
- [ ] Persist external provider reference fields as nullable until integration exists.
- [ ] Never mark a future real-money transaction successful merely because the client reports success.
- [ ] Add clear TODO/integration boundaries for the future regulated payment provider.
- [ ] Do **not** add Anchor credentials or production payment logic yet.
- [ ] Do **not** implement real MCC verification yet.

## 6. Savings Plans

- [ ] Create savings-plan model/repository.
- [ ] Support daily, weekly, and monthly frequency.
- [ ] Default contribution amount to ₦500.
- [ ] Allow users to increase/change the contribution amount.
- [ ] Support create, read, update, pause/resume, and appropriate cancellation state.
- [ ] Enforce one clear active-plan policy per user unless the product explicitly requires otherwise.
- [ ] Calculate/store next contribution date safely.
- [ ] Keep scheduling logic separate from UI.
- [ ] Model successful, pending, and failed scheduled contributions.
- [ ] Prepare auto-contribution orchestration without attempting real debits yet.
- [ ] Use the mock payment/funding adapter to test recurring contribution flows.
- [ ] Ensure failed contributions never create completed ledger credits.
- [ ] Make recurring jobs idempotent so the same scheduled contribution cannot execute twice.
- [ ] Record savings-plan changes and contribution activity.

## 7. Add Money / Funding

- [ ] Create funding transaction model.
- [ ] Support preset and custom amounts.
- [ ] Validate minimum/maximum/positive amount rules centrally.
- [ ] Implement funding lifecycle: created → pending → completed/failed/cancelled as appropriate.
- [ ] Use mock payment adapter for MVP backend testing until business/payment setup is ready.
- [ ] Credit wallet only after trusted backend verification.
- [ ] Generate ledger entry and activity event after completion.
- [ ] Generate receipt-ready transaction metadata.
- [ ] Generate notification event after completion/failure where appropriate.
- [ ] Test retry, duplicate verification, delayed confirmation, failure, and timeout paths.

## 8. Family Pocket

- [ ] Create Family Pocket model and repository.
- [ ] Support pocket name, optional description, image, frequency, default contribution amount, owner, timestamps, and status.
- [ ] Support Family Pocket image upload/storage.
- [ ] Create membership model with explicit roles/permissions.
- [ ] Support owner/admin/member rules required by the MVP.
- [ ] Create invite model.
- [ ] Support invite creation, acceptance, decline/expiry where appropriate, and duplicate-invite prevention.
- [ ] Support invite links/codes without exposing unauthorized pocket data.
- [ ] Allow members to leave subject to ownership rules.
- [ ] Allow authorized owner/admin actions to remove members.
- [ ] Prevent unauthorized membership manipulation.
- [ ] Define ownership-transfer or pocket-close behavior before allowing an owner to leave.
- [ ] Track each member's contribution independently.
- [ ] Maintain Family Pocket balance through ledger-backed contribution records.
- [ ] Never permit the client to directly alter Family Pocket balances.
- [ ] Implement Family Pocket activity history.
- [ ] Implement contribution frequency/default amount behavior.
- [ ] Prepare Family Pocket funding through the same payment abstraction.
- [ ] Test concurrent member contributions.
- [ ] Test permissions extensively with Emulator Suite.

## 9. Healthcare Provider Directory / Find Care

- [ ] Create canonical healthcare provider model.
- [ ] Support partner and non-partner provider status.
- [ ] Store provider name, category/type, address, state/city, coordinates, contact details, opening information where available, logo/image references, and active status.
- [ ] Support hospitals, clinics, pharmacies, diagnostics and other approved healthcare categories.
- [ ] Implement provider search.
- [ ] Implement category filters.
- [ ] Implement partner/non-partner filtering.
- [ ] Implement location-aware querying appropriate for the current Firebase architecture.
- [ ] Store latitude/longitude required for map/directions integration.
- [ ] Return data needed for the app to open Google Maps directions.
- [ ] Handle no-location-permission and no-nearby-provider states cleanly.
- [ ] Ensure provider records cannot be edited by ordinary users.
- [ ] Create an admin/seeding mechanism for maintaining provider records without building a provider dashboard.
- [ ] Add provider activation/deactivation so closed/invalid providers can be removed from discovery without destroying historical transactions.

## 10. Healthcare Payment Flow — Prepared, Mocked

### HealthPocket Partners

- [ ] Create healthcare-payment transaction model.
- [ ] Allow user to select an active HP partner and enter an amount.
- [ ] Validate amount and available HealthPocket balance.
- [ ] Validate provider exists and is active.
- [ ] Create pending transaction before processing.
- [ ] Use mock payment/settlement adapter for now.
- [ ] Finalize debit only through trusted backend logic.
- [ ] Create ledger debit, activity event, receipt metadata, and notification after successful mock settlement.
- [ ] Preserve failed/pending transaction records for debugging and user history.
- [ ] Do not implement QR payment for MVP.

### Non-Partners

- [ ] Build the non-partner transaction data model and workflow now.
- [ ] Support beneficiary/provider bank-detail fields required by the future integration.
- [ ] Create account-resolution/beneficiary-verification interface.
- [ ] Create healthcare-provider/MCC-verification interface but leave the real implementation unconnected.
- [ ] Use explicit mock verification states for development.
- [ ] Do not fake production MCC verification.
- [ ] Require a verified/allowed state before the mock payment flow can proceed.
- [ ] Build failure state for provider verification rejection.
- [ ] Keep partner and non-partner flows distinguishable in transaction records.
- [ ] Make the future provider/MCC service replaceable without rewriting transaction/business logic.

## 11. Activity & Transaction History

- [ ] Create one normalized activity/read model sourced from authoritative backend events.
- [ ] Include savings contributions, direct top-ups, healthcare payments, Family Pocket contributions, reversals/failures where appropriate.
- [ ] Support pagination.
- [ ] Support filters by transaction/activity type.
- [ ] Support date-range filters.
- [ ] Ensure activity amounts/statuses match authoritative transaction/ledger data.
- [ ] Provide transaction-detail endpoint/repository method.
- [ ] Do not allow users to edit financial history.
- [ ] Implement empty state cleanly.
- [ ] Prepare statement/export data generation for MVP.
- [ ] Ensure export only contains records belonging to the authenticated user and permitted Family Pocket context.

## 12. Receipts

- [ ] Define canonical receipt data model.
- [ ] Include HealthPocket reference ID, transaction ID, amount, date/time, provider/recipient, payment type/method, status, and relevant user-facing metadata.
- [ ] Generate receipts from authoritative completed transaction data rather than client input.
- [ ] Ensure receipt/reference IDs are unique.
- [ ] Prevent receipt tampering.
- [ ] Build backend data/export contract needed for download/share.
- [ ] Ensure failed/pending transactions cannot masquerade as completed receipts.
- [ ] Preserve historical receipt data even if provider profile details later change.

## 13. Notifications

- [ ] Create in-app notification model.
- [ ] Support read/unread state.
- [ ] Support notification types: savings, funding, payment, Family Pocket, security/system.
- [ ] Generate notifications from backend events rather than UI assumptions.
- [ ] Add pagination/query strategy.
- [ ] Implement mark-read / mark-all-read securely.
- [ ] Prepare Firebase Cloud Messaging device-token model.
- [ ] Support token registration/removal/refresh.
- [ ] Build push-notification service abstraction.
- [ ] Ensure notification failure never changes the underlying transaction outcome.
- [ ] Avoid placing sensitive financial/account data unnecessarily in lock-screen push payloads.
- [ ] Test multiple devices and stale token handling.

## 14. “What Can My Balance Cover?”

- [ ] Create `coverageItems`/care-cost model.
- [ ] Start with approximately 5 curated healthcare items based on partner-supplied MVP data.
- [ ] Store item name, category, indicative price, source/provider reference, location/context where relevant, last-updated timestamp, and active status.
- [ ] Treat prices as indicative estimates rather than guaranteed treatment prices.
- [ ] Compare each active item's price against the user's available balance.
- [ ] Return `covered`, `amountRemaining`, or equivalent derived state.
- [ ] When balance is ₦0, return the appropriate encouragement/empty-state data instead of pretending services are affordable.
- [ ] Do not hard-code prices into Flutter.
- [ ] Make coverage items remotely maintainable through backend/admin tooling.
- [ ] Ensure stale/inactive pricing can be disabled.

## 15. Email Infrastructure

- [ ] Define centralized transactional email service abstraction.
- [ ] Implement templates/events required for the final MVP.
- [ ] Keep email sending server-side.
- [ ] Add rate limits/retry strategy.
- [ ] Do not expose email-provider credentials to Flutter.
- [ ] Prevent duplicate sends for idempotent financial events.
- [ ] Separate essential transactional/security messages from optional marketing communications.
- [ ] Wire verification-code email flow if retained.
- [ ] Prepare relevant transaction/family/security email event hooks without making email delivery a prerequisite for transaction correctness.

## 16. Backend System/Error States

- [ ] Standardize backend error codes/messages.
- [ ] Cover unauthenticated/unauthorized.
- [ ] Cover invalid input.
- [ ] Cover offline/network/retry scenarios at repository boundary.
- [ ] Cover insufficient balance.
- [ ] Cover provider not found/inactive.
- [ ] Cover payment pending/failed.
- [ ] Cover duplicate request/idempotency conflict.
- [ ] Cover verification failure.
- [ ] Cover savings-plan failure.
- [ ] Cover Family Pocket permission/invite errors.
- [ ] Avoid exposing internal stack traces/provider secrets to users.
- [ ] Make errors actionable enough for Flutter to render the correct state.

## 17. Firestore & Storage Security

- [ ] Default-deny security posture.
- [ ] Users may only read/write their permitted profile data.
- [ ] Wallet balances and completed financial records cannot be manipulated by clients.
- [ ] Ledger writes restricted to trusted backend.
- [ ] Transaction finalization restricted to trusted backend.
- [ ] Provider-directory writes restricted to trusted/admin backend.
- [ ] Coverage-item writes restricted to trusted/admin backend.
- [ ] Family Pocket rules enforce membership and role permissions.
- [ ] Family Pocket private data inaccessible to non-members.
- [ ] Notifications accessible only to intended user.
- [ ] Storage rules protect profile and Family Pocket images.
- [ ] Validate paths, ownership, file metadata/type/size where possible.
- [ ] Test cross-user attacks in Emulator Suite.
- [ ] Test guessed document IDs.
- [ ] Test unauthorized update/delete attempts.
- [ ] Test privilege escalation attempts.

## 18. Cloud Functions / Trusted Backend

- [ ] Identify every operation that must not trust Flutter.
- [ ] Move authoritative financial mutations into trusted backend functions/services.
- [ ] Validate authentication on every callable/API operation.
- [ ] Validate authorization separately from authentication.
- [ ] Validate all request payloads server-side.
- [ ] Add idempotency support to money-moving operations.
- [ ] Use transactions/batches where consistency requires them.
- [ ] Add timeout/retry-safe behavior.
- [ ] Add structured audit logs for sensitive operations.
- [ ] Keep provider/payment secrets in server-side secret/config management.
- [ ] Design functions so future Anchor/payment-provider integration replaces adapters rather than business logic.

## 19. Data Integrity & Indexing

- [ ] Review Firestore schema for query patterns before launch.
- [ ] Create required composite indexes.
- [ ] Avoid unbounded reads.
- [ ] Paginate potentially large collections.
- [ ] Eliminate N+1-style Firestore access where practical.
- [ ] Define deletion/retention behavior for user accounts while preserving records that may later require financial/legal retention.
- [ ] Ensure references to deleted/deactivated providers do not break historical transactions.
- [ ] Add schema/version strategy where useful.
- [ ] Add safe migration/seeding scripts for provider and coverage data.

## 20. Abuse & Reliability Protection

- [ ] Rate-limit sensitive operations where appropriate.
- [ ] Protect verification-code endpoints.
- [ ] Protect invite creation.
- [ ] Protect payment/funding initialization.
- [ ] Validate all amounts and IDs server-side.
- [ ] Reject malformed/negative/zero financial requests.
- [ ] Prevent replay of completed requests.
- [ ] Prevent duplicate scheduled savings execution.
- [ ] Add reasonable transaction limits/config placeholders for future payment compliance requirements.
- [ ] Design for provider API downtime without corrupting transaction state.
- [ ] Ensure a timeout is not automatically treated as payment failure when final status is unknown.
- [ ] Provide reconciliation path for ambiguous/pending transactions.

## 21. Emulator & Automated Tests

- [ ] Run Firebase Emulator Suite for backend development.
- [ ] Unit-test repositories/services.
- [ ] Test Firestore security rules.
- [ ] Test Storage rules.
- [ ] Test Cloud Functions.
- [ ] Test wallet/ledger invariants.
- [ ] Test concurrent balance operations.
- [ ] Test idempotency.
- [ ] Test funding success/failure/pending/retry.
- [ ] Test healthcare payment success/failure/pending/retry.
- [ ] Test non-partner mock verification approval/rejection.
- [ ] Test savings scheduling.
- [ ] Test Family Pocket permissions and concurrent contributions.
- [ ] Test notification generation.
- [ ] Test receipt generation.
- [ ] Test cross-user unauthorized access.
- [ ] Build end-to-end backend test scenarios representing realistic user journeys.

## 22. MVP End-to-End Backend Journeys

All of these must work with mock payment infrastructure before real payment integration begins.

- [ ] New user → Google auth → onboarding → profile → PIN → dashboard-ready state.
- [ ] Returning authenticated user → PIN → session restored.
- [ ] Logout → PIN no longer sufficient → Google authentication required.
- [ ] User creates/edits/pauses savings plan.
- [ ] Scheduled contribution → mock success → ledger credit → balance/activity/notification updated once.
- [ ] Scheduled contribution → mock failure → no credit → failure state recorded.
- [ ] User manually adds money → mock success → wallet/ledger/activity/receipt/notification consistent.
- [ ] User creates Family Pocket → uploads image → invites member → member joins.
- [ ] Multiple members contribute → Family Pocket totals remain consistent.
- [ ] Unauthorized user cannot read/write another Family Pocket.
- [ ] User discovers nearby partner/non-partner providers.
- [ ] User opens provider details and receives valid coordinates for Google Maps directions.
- [ ] User initiates partner healthcare payment → mock settlement → debit → receipt/activity/notification.
- [ ] Insufficient balance blocks healthcare payment without creating an incorrect debit.
- [ ] Non-partner provider → mock account/provider verification → mock payment.
- [ ] Non-partner verification failure → payment blocked safely.
- [ ] Duplicate/retried payment request cannot debit twice.
- [ ] User views/filter/searches transaction activity.
- [ ] User accesses completed transaction receipt/export data.
- [ ] Coverage engine reacts correctly to ₦0, low, sufficient, and high balances.
- [ ] Backend remains internally consistent after simulated failures and retries.

## 23. Real-Payment Integration Readiness Gate

Do **not** begin real payment integration until this section passes.

- [ ] No client can directly manipulate authoritative wallet balances.
- [ ] Ledger is authoritative/auditable.
- [ ] Financial operations are idempotent.
- [ ] Payment gateway abstraction is provider-independent.
- [ ] Mock gateway exercises success, pending, failure, timeout, reversal, and duplicate-event paths.
- [ ] Webhook/event architecture exists.
- [ ] Provider/beneficiary verification interfaces exist.
- [ ] Non-partner healthcare verification/MCC interface exists but is clearly mocked/unimplemented.
- [ ] Secrets are server-side only.
- [ ] Security rules pass adversarial tests.
- [ ] Critical Cloud Functions/services have automated tests.
- [ ] Pending/ambiguous transaction reconciliation is designed.
- [ ] Provider/payment integration can be added without changing the Flutter domain models or rewriting wallet/ledger logic.

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
