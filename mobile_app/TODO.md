# HealthPocket MVP follow-up checklist

This file tracks intentionally deferred work so it does not disappear between
delivery slices. A checked item means the specific milestone described is done;
local verification, deployment, and mobile acceptance are tracked separately.

## Completed invitation foundation (locally verified)

- [x] Separate admin/member authority from contributor and beneficiary capabilities.
- [x] Implement verified-email invitation discovery and accept/decline actions.
- [x] Implement admin cancellation and member removal, preserving contributions.
- [x] Enforce two beneficiary slots through atomic invitation/membership writes.
- [x] Display expired invitations and allow admin cancellation to release slots.
- [x] Verify the implementation with 42 Flutter tests, 15 Firestore emulator tests,
  Flutter analysis, and a successful DEV rules compilation dry run (2026-09-13).
- [x] Create this deferred-work checklist, including guardian-managed dependants.

## Next slice: DEV migration and deployment

- [x] Inspect existing DEV pockets, memberships, and invitations; produce a
  migration preview and identify ambiguous records.
- [x] Save the DEV inventory/backup and document recovery. The 2026-09-14
  inventory contained zero pockets and zero child records, so a data migration
  was unnecessary. The preview script deliberately cannot apply writes.
- [x] Verify no legacy records need migration; contribution history was untouched.
- [x] Deploy the matching indexes and rules to DEV and verify index readiness
  (2026-09-14: all nine listed indexes READY; 42 Flutter tests passed and
  Flutter analysis reported no issues).
- [x] Mobile-test with two verified DEV accounts: invite, accept/decline,
  cancellation, beneficiary capacity, removal, refresh, and app restart.
  User reported successful mobile testing with no urgent flaws.

## Invitation attention and email guidance

- [x] Add a Family tab badge for loaded, actionable pending invitations, with
  an accessible count and local expiry handling. Opening the tab does not clear it.
- [x] Add Spam/Junk guidance to email verification; preserve the existing resend action.
- [x] Mobile-test the badge and verification guidance (user confirmed success).
- [ ] Configure branded authentication email and verify sender authentication
  and delivery across email providers before public launch.
- [ ] Add live invitation delivery/refresh so remote changes appear without a
  manual refresh or session restore. The badge currently reflects loaded data.

Production changes and real email delivery are not part of this rollout.

## Before the MVP pilot

- [x] Connect account-detail edits to the profile repository and retain failed
  drafts for retry; keep sign-in email out of ordinary profile editing.
- [ ] Mobile-test account edits across restart and offline retry.
- [x] Add persisted personal-information and emergency-contact editors with
  validation, duplicate-save protection, and retained drafts on failure.
- [ ] Beta mobile acceptance: edit personal details/emergency contact, restart,
  verify saved values, and exercise offline retry (batched with later testing).
- [ ] Replace placeholder support actions and connect published privacy/terms.
- [x] Replace the fake support-request action with email composition to
  gethealthpocket@gmail.com, copy-address fallback, and safe feedback guidance.
- [x] Update outdated FAQ copy for the no-money beta.
- [ ] Mobile-test email handoff and copy fallback in the combined beta pass.
- [ ] Implement account deletion with a retention-aware backend workflow.
- [ ] Evaluate optional profile-photo uploads after core profile functionality.

- [x] Check existing DEV Family Pocket documents and legacy invitations for the
  capability model and reconcile beneficiary slots before deploying these rules.
  Preserve all contribution history; never infer accepted beneficiaries from the
  former free-text beneficiary description. No records existed on 2026-09-14;
  no migration was needed for this rollout.
- [ ] Add the trusted Family Pocket invitation backend: single-use token
  generation and hashing, token redemption, resend throttling, persisted expiry
  cleanup, and authoritative audit events.
- [ ] Select and connect a transactional email provider for Family Pocket
  invitations and invitation-response emails.
- [ ] Configure a HealthPocket-owned invite domain with Android App Links and
  iOS Universal Links; provide a store/website fallback when the app is absent.
- [ ] Add in-app notifications for pending invites and accepted/declined/
  cancelled invitation outcomes.
- [ ] Add Family Pocket ownership transfer and a member-initiated leave flow.
- [ ] Decide whether users may belong to multiple Family Pockets during the MVP
  pilot and enforce the chosen limit consistently.
- [ ] Complete the persistence-closure audit for profile edits and the general
  activity/audit feed.
- [ ] Build the partner clinic/pharmacy directory and state-based discovery.
- [x] Add offline demo Find care tab, repository interface, combined search/state/
  type filters, provider details, empty/error/retry states, and demo disclaimers.
  Verified with 50 passing Flutter tests and clean analysis on 2026-09-15.
- [ ] Connect reviewed confirmed-provider records and directory administration;
  do not publish fictional listings as actual partnerships.
- [x] Draft plain-language privacy and beta terms in privacy-policy/terms.txt.
- [ ] Resolve draft placeholders, confirm retention/deletion and data practices,
  obtain review, publish website pages, and connect final app links.
- [ ] Include Find care navigation, filters, details, and small-screen usability
  in combined beta mobile testing.
- [ ] Build partner QR scanning and the manual care-authorization lifecycle:
  requested, authorized, care approved, service completed, pending settlement,
  and settled.
- [x] Implement the bounded DEV design flow: provider-first selection, amount
  confirmation, camera/mock scanning, strict stable-ID matching, clear rejection,
  one in-memory demo authorization result, and duplicate-confirmation prevention.
- [x] Remove settlement-style states and operator controls from the design beta.
- [x] Verify the bounded Find Care/QR slice with 9 focused tests and the full
  56-test Flutter suite (2026-09-19).
- [ ] Design the future provider-neutral backend separately after partnerships;
  the current beta must not persist authorization/payment/settlement records.
- [ ] Device-test scanner permissions, denial fallback, camera lifecycle, and
  Android release packaging; iOS camera permission text is not iOS validation.
- [ ] Build the minimum partner/admin operations surface needed to confirm care
  authorizations, record manual settlement, and reconcile pilot transactions.
- [ ] Select the regulated savings/funds-holding partner and replace all DEV-only
  contribution records with provider-backed, webhook-confirmed records.
- [ ] Define pilot support, reversal, dispute, reconciliation, and incident
  procedures before any real balance is displayed as money held for a user.
- [ ] Complete the production Firebase security review, environment checklist,
  monitoring, backups, release signing, store listings, and launch runbook.

## Post-MVP product extensions

- [ ] Add guardian-managed dependant profiles for children or family members who
  do not have their own email-addressed HealthPocket account.
- [ ] Add guardian consent, dependant relationship evidence, and age-appropriate
  privacy rules before dependants can receive care through a Family Pocket.
- [ ] Add production KYC through a specialist provider rather than collecting or
  verifying identity documents directly in HealthPocket.
- [ ] Add BVN/NIN verification only where the regulated partner and applicable
  compliance process require it.
- [ ] Re-evaluate SMS OTP/phone verification after MVP evidence justifies its
  ongoing cost.
- [ ] Add biometric local unlocking as an alternative to the six-digit app PIN.
- [ ] Add automated partner settlement and payment-provider reconciliation.
- [ ] Add investment products such as Treasury Bills only through an appropriately
  regulated partner and as a product separate from default health savings.
- [ ] Evaluate separate target-based savings pockets without changing the default
  ongoing emergency-health savings model.

## UX and quality pass

- [ ] Complete the planned Month 3/4 visual-polish pass across onboarding,
  dashboard, savings, Family Pocket, accessibility, small screens, and text
  scaling.
- [ ] Add complete empty, loading, offline, retry, and partial-failure states to
  every remaining network-backed screen.
- [ ] Add end-to-end tests for fresh install, returning user, new device, password
  reset, PIN recovery, invitation acceptance, and partner QR authorization.
