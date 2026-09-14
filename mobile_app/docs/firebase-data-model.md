# Firebase data model

## Invitation slice rollout status

The capability-based invitation lifecycle is implemented and tested locally.
Its rules and new indexes were deployed to DEV on 2026-09-14. The preflight
inventory found zero Family Pockets and zero child records, so no migration
writes were needed. Contribution records were untouched. Production is unchanged.
All nine listed DEV indexes are READY, including the new membership and invite
indexes. The 42 Flutter tests and Flutter analysis passed again after deployment.
The app is ready for DEV mobile acceptance; see `TODO.md` for that checklist.

### DEV rollout and recovery

Run `node scripts/migrate-family-dev.mjs preview` after refreshing Firebase CLI
login to inspect DEV and save a local inventory under
`.dart_tool/family-migration/`. This script is read-only and hardcoded to DEV;
it rejects apply mode. Backups may contain personal data: keep them out of Git
and do not share them. A future non-empty legacy inventory needs a reviewed,
tested migration and recovery plan before any writes.

No data rollback is required for this rollout because no data was changed.
If a rules regression requires rollback, compare the previous DEV ruleset
`da7c1516-006e-4982-b84f-b6c1c0760799` with the deployed ruleset
`5c5b87d8-4669-4398-bdf0-a91a427d9481` before restoring via Firebase Console.
Do not blindly restore old rules after new-schema records have been created.
Keep the new indexes; they do not rewrite documents.

For mobile acceptance, run
`flutter run --flavor dev --target lib/main_dev.dart` with two verified accounts.
Create a pocket, invite the other account's email, then switch accounts and
accept or decline from the Family tab. Check cancellation, removal, two-slot
capacity, refresh and restart persistence. Use additional accounts to exercise
the beneficiary capacity boundary. No invitation emails are sent in this slice.

This first iteration authorizes atomic client transactions through Firestore
Security Rules. It does not yet implement the previously discussed trusted
invitation service. Token redemption, email delivery, and automated expiry
remain tracked in `TODO.md` and are required before the full email journey.

This contract began in the Week 1 foundation pass. Authenticated DEV journeys
now persist profiles, notification preferences, personal pockets, savings
instructions, development contribution records, and Family Pockets through
repositories. The general activity repository remains an extension point; the
current personal and family histories derive directly from contribution records.

## Collections

- `users/{userId}` stores profile data, notification preferences, KYC status,
  and creation/update timestamps. The document ID must equal the Firebase Auth
  UID.
- `personal_health_pockets/{pocketId}` stores ownership, currency, lifecycle
  status, and timestamps. It does not store a mutable balance.
- `savings_plans/{planId}` stores a user's recurring amount, frequency, start
  date, next scheduled date, optional funding-source reference, and status.
- `contributions/dev_{userId}_{idempotencyKey}` and
  `contributions/dev_family_{userId}_{idempotencyKey}` store immutable personal
  or Family Pocket development records. Each record has `amountKobo`, `NGN`,
  `status: recorded`, `origin: dev_simulation`, `moneyMovement: false`, the
  owning pocket ID, a personal plan ID when applicable, an idempotency key, and
  a server `createdAt`.
- `family_pockets/{pocketId}` stores the pocket name, fixed beneficiary limit
  of two, creator, currency, status, and timestamps.
- `family_pockets/{pocketId}/members/{memberId}` stores non-PII membership
  display data, authority role, contribution/beneficiary capabilities, and
  lifecycle state. An accepted user's membership ID is their Auth UID. Removing
  a member is a soft update to `status: removed` with `removedAt`; financial
  history is never deleted.
- `family_pockets/{pocketId}/invites/{inviteId}` stores invitation email PII,
  denormalized pocket/inviter display names, proposed capabilities, seven-day
  expiry, and response state. Active admins can manage their pocket's invites;
  an email-verified invitee can discover and respond only to the invitation
  matching their Firebase Auth email.
- `family_pockets/{pocketId}/beneficiary_slots/{1|2}` reserves the two allowed
  beneficiary positions across pending and accepted invitations. Reservation,
  acceptance, decline/cancellation, and member removal update the invitation,
  membership, and slot atomically.
- `activities/{activityId}` is an append-only user-visible audit feed linked to
  the affected entity and, when applicable, a Family Pocket.

## Data decisions

- Firebase Auth is the account authority. MVP sign-in providers are verified
  Email/Password and Google; Firestore rejects unverified email identities.
- The six-digit HealthPocket app PIN is device-local only. Firestore has no PIN
  field. Only a salted PBKDF2-SHA256 hash is placed in OS-protected secure
  storage, with local attempt throttling. A new device must use Firebase sign-in
  and creates its own local PIN.

- Savings-plan preferences remain positive integer naira amounts because they
  describe a schedule, not a movement of money. Contribution records use
  positive integer kobo (`amountKobo`) and explicitly store `currency: NGN`.
- The displayed development balance is derived only from personal contribution
  records whose status is `recorded`, origin is `dev_simulation`, and
  `moneyMovement` is false. It is never stored as an independently editable
  value. The dashboard activity feed reads this same ordered record list.
- A Family Pocket development balance follows the same rule and is derived from
  immutable family-scoped records visible only to active members.
- The mobile client can create only those non-monetary development records.
  Real/provider-originated deposits, payments, settlement and withdrawals are
  rejected. A trusted backend or provider webhook must own those writes later.
- A client-generated request key produces a deterministic document ID. The
  repository checks that document in a transaction, so retrying the same
  request is a no-op instead of a second record.
- KYC documents, selfies, bank credentials, OTPs, and card details must not be
  stored in these documents. Only a provider status and opaque provider
  reference should be retained once a regulated integration is selected.
- SMS OTP, production KYC, BVN/NIN verification and identity-document collection
  are outside MVP scope. Existing status fields are reserved extension points;
  the client rules cannot promote them to a verified state.
- Rules are deny-by-default. User records are owner-scoped; Family Pocket data
  is member-scoped; member administration requires an active admin membership.
- Family access authority (`admin` or `member`) is separate from the
  `canContribute` and `isBeneficiary` capabilities, so one member can be both a
  contributor and a beneficiary without receiving admin power.
- Invitation states are `pending`, `accepted`, `declined`, `cancelled`, and the
  locally derived `expired` state. Pending invitations past `expiresAt` cannot
  be accepted. Until the trusted backend exists, an admin must cancel an expired
  invite to release its reserved beneficiary slot.
- This slice deliberately sends no email and stores no link token. Transactional
  email, single-use token hashing/redemption, resend throttling, persisted expiry
  cleanup, and authoritative notification/audit events remain trusted-backend
  work tracked in `TODO.md`.
- Firestore document deletion is disabled by the rules for financial and audit
  records. The DEV database itself also has deletion protection enabled.

## Repository boundary

UI and application stores depend on the interfaces in
`lib/core/data/repository_contracts.dart`. Firebase implementations live in
`lib/core/data/firestore/firestore_repositories.dart`; this keeps provider code
out of features and leaves room for test/in-memory implementations.
