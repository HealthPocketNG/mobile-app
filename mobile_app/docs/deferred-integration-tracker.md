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
- [ ] Feed the Activity V2 overview, filters, transaction details, and receipt
  from a trusted payment ledger. The screen currently reads real savings and
  Family Pocket contribution records; the five sample rows appear only in DEV
  UI preview when that ledger is empty. `DEMO-*` references are never payment
  records. Replace them with backend-owned payment attempts and completed
  transactions, including timestamps, merchant identity, status, reversals,
  and receipt URLs. Enable receipt export only for confirmed records and keep
  pending/failed transactions distinct. Remove `DEV_ACTIVITY_EMPTY` after
  testing the empty state.
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
- [ ] Replace the six non-partner merchant-check and payment-outcome previews
  with backend-owned attempt states. The current verified mock shows a timed
  processing and success preview; slow, ineligible, and unavailable checks
  show separate review, not-completed, and failed previews. Attach real
  references, timestamps, balance holds/releases, activity, notifications,
  and receipts only after trusted confirmation. Remove the debug long-press
  outcome chooser when live payment status is connected.
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

## Profile V2 handoff

- [ ] Finish in-session Change Password and verify the new Reset PIN flow on
  a live DEV device. Reset PIN now requires Firebase email reauthentication
  (or Google reauthentication for Google-only accounts), checks the same user
  remains signed in, then saves a confirmed 6-digit PIN through the existing
  PIN repository. The onboarding PIN screen is not reused. Fingerprint login
  uses the existing device biometric service; auto-lock timing is still
  unavailable. Link Linked Accounts and Two-Factor Authentication to reviewed
  account flows. Active Sessions now shows the current device only; implement
  trusted server-side session enumeration and revocation before listing other
  devices or enabling “Log Out of All Other Devices.”
- [ ] Define storage, delivery, and consent for the Profile notification
  categories that are not in the current four-field preference model: login
  activity, security alerts, payments, and marketing offers. Their switches
  stay disabled until the backend supports them. Keep essential security
  messages separate from optional marketing consent.
- [ ] Add device notification permission handling and push registration before
  the “Stay in the loop” action can request permission or claim alerts are on.
  The current screen is a UI preview and makes no permission change.
- [ ] Connect bank account linking and real balance/payment method data to
  Payment Methods after the trusted payment provider is ready. It currently
  shows only the existing DEV contribution balance, labelled as a development
  record, and does not store bank details or enable a payment method.
- [ ] Connect the new Refer a Friend page to server-issued codes, attribution,
  rewards, and sharing once the referral programme is approved. The screen
  currently shows unavailable values and disables Share Invite rather than
  displaying Figma's sample code, friends, or earnings.
- [ ] Replace the new Terms and Privacy screen placeholders with reviewed,
  approved policies and their actual revision dates before release. The Figma
  text is explicitly placeholder copy; the current screen labels it as draft.
- [ ] Connect live chat, phone, and WhatsApp Support cards only after verified
  endpoints, hours, and response commitments exist. Email uses the existing
  mailto handoff and does not claim the message was sent by the app. Review
  the new FAQ answers against the launched payment and Family Pocket behavior.
- [ ] Build a verified self-service account deletion flow that checks
  reauthentication, balances, Family Pocket ownership, retention obligations,
  and cross-device sign-out. The Delete account screen currently opens a
  support email draft for a manual request; opening it does not delete data.
- [ ] Add an authenticated report-issue endpoint and screenshot upload if
  reports should be submitted in-app. The current Report an Issue form opens
  a prepared email draft; a screenshot can be attached there. Do not claim
  report delivery until it is sent from the email app or accepted by a backend.
- [ ] Connect the Profile app-guide and rating actions to real product flows.
  About uses the original
  HealthPocket logo and the current app version; the open-source license row
  was omitted by product decision. Profile photo upload still waits for the
  DEV Storage bucket and rules noted above. The Change Photo sheet supports
  camera, gallery, and removal once those callbacks are enabled.

## Release checks

- [ ] Re-run the complete DEV mobile journeys and backend emulator suites,
  then separately test live DEV integrations before any production rollout.
- [ ] Register/activate App Check and observe valid traffic before enforcement;
  finish the deployment, monitoring, backup, support, and incident gates in
  [backend-hardening-and-frontend-readiness.md](backend-hardening-and-frontend-readiness.md).

The broader backlog remains in [TODO.md](../TODO.md). Update this tracker as
each live handoff is implemented and tested; a checked item means the stated
integration and acceptance test are complete, not just that its screen exists.
