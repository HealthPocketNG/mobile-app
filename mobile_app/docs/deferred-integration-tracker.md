# Deferred integration tracker

Updated 2026-11-05. This is the handoff list for V2 screens that are currently
visual previews, use mock data, or need a live service. Keep the UI in place;
replace its data and actions through the existing repositories and trusted
backend boundary. A Firebase plan upgrade alone does **not** enable real
payments or device location.

**Permanent product constraint:** payment authorization must remain free of QR
scanning. The former scanner route, dependency, and camera permission were
removed; do not restore them during provider integration.

## After DEV Firebase billing and email setup

- [ ] Complete the DEV-only steps in
  [email-verification-setup-checklist.txt](email-verification-setup-checklist.txt):
  billing, verified Resend domain/sender, Secret Manager, Functions and rules
  deployment, then fresh-account and password-recovery tests on a phone.
- [ ] Run the real DEV auth flow with `--dart-define=DEV_PREVIEW_AUTH=false`.
  Verify sign-up, email verification, personal details, six-digit account PIN,
  returning sign-in, recovery, offline/retry, and session expiry.
- [ ] Once that flow passes, remove the temporary `DEV_PREVIEW_AUTH` path and
  `PreviewAuthRepository`; retain real Firebase Auth behavior. The preview
  switch is in `lib/firebase/firebase_bootstrap.dart`.
- [ ] Create and verify the DEV Storage bucket and owner-only rules before
  enabling profile and Family Pocket image uploads. See
  [firebase-data-model.md](firebase-data-model.md) and
  [backend-hardening-and-frontend-readiness.md](backend-hardening-and-frontend-readiness.md).

## Before any real funding or healthcare payment

The full adapter, webhook, reconciliation, security, and operational gates are
in [real-payment-readiness.md](real-payment-readiness.md). Deployed money
commands currently fail closed; the mock gateway is emulator-only.

- [ ] Select/onboard a regulated provider and complete that document's
  production cutover gates. Configure credentials only on the trusted backend.
- [ ] Replace the Find Care amount → transfer → review → PIN → processing →
  result **UI preview** in `lib/features/care/presentation/` with typed
  `TrustedBackendClient` commands and backend-owned attempt/status records.
  Do not infer success from a timer, client callback, or timeout.
- [ ] Decide the payment authorization policy. Figma shows four payment-PIN
  digits; the existing account-unlock PIN has six. The current four-digit
  keypad accepts demo digits in memory only. Define enrollment, recovery,
  lockout, secure verification, and any biometric alternative before enabling
  payment authorization. Do not silently reuse the account PIN.
- [ ] Show payment success and enable View Receipt only after trusted
  confirmation. Use server-owned amount, beneficiary, reference, status,
  balance, receipt, activity, and notification data. Keep pending and failed
  attempts distinct from completed ones.
- [ ] Replace `MockBankAccountVerificationService`, preview-only bank IDs,
  and `MockHealthcareMerchantVerificationService` with approved bank catalog,
  account-resolution, beneficiary, and healthcare-eligibility adapters. Keep
  Select Bank and account-error states; validate account details and failure
  responses through the trusted backend, never by trusting the client form.
- [ ] Connect the non-partner amount → bank details → review flow to the
  trusted payment attempt lifecycle. Resolve the recipient again server-side,
  verify healthcare eligibility before payout, and handle pending, ineligible,
  failed, and reversed outcomes without claiming money was returned before
  settlement or reversal is confirmed. The two new explanation sheets describe
  this intended behavior; today's Pay action only runs mock verification.
- [ ] Connect real funding and savings balance data to the insufficient-funds
  state. Test duplicate taps, interruptions, retries, reversals, and receipt
  reconciliation without client-side balance writes.

## Find Care data and device capabilities

These are separate workstreams; they do not become live just by upgrading
Firebase or connecting a payment provider.

- [ ] Replace fictional demo providers with reviewed provider records and
  owned administration. Confirm partner status before showing “Verified by
  us” or “Faster payments.” Preserve the directory repository boundary.
- [ ] Supply trustworthy distance and rating data for Filters and Search.
  Ratings are optional now; a minimum-rating filter excludes unrated records.
  Verify location-based filtering against the approved provider catalog.
- [ ] Add native location permission and position handling, with denial and
  unavailable states and a working manual-area fallback. “Allow Location”
  currently returns to manual selection because no device location service is
  wired. Test on Android and iOS devices before relying on nearby results.
- [ ] Implement saved providers if that action remains in scope; the current
  Save control reports that it is unavailable. This can be planned separately
  from real payments.
- [ ] Replace preview notification rows and mock delivery with trusted inbox
  data and approved push/email delivery when device registration and provider
  credentials are ready. Family Pocket invitation delivery is also tracked
  in [TODO.md](../TODO.md).

## Release checks

- [ ] Re-run the complete DEV mobile journeys and backend emulator suites,
  then separately test live DEV integrations before any production rollout.
- [ ] Register/activate App Check and observe valid traffic before enforcement;
  finish the deployment, monitoring, backup, support, and incident gates in
  [backend-hardening-and-frontend-readiness.md](backend-hardening-and-frontend-readiness.md).

The broader backlog remains in [TODO.md](../TODO.md). Update this tracker as
each live handoff is implemented and tested; a checked item means the stated
integration and acceptance test are complete, not just that its screen exists.
