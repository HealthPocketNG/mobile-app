# Firebase data model

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
- `family_pockets/{pocketId}` stores the pocket name, beneficiary, creator,
  currency, status, and timestamps.
- `family_pockets/{pocketId}/members/{memberId}` stores non-PII membership
  display data and role. An accepted user's membership ID is their Auth UID.
  Removing a contributor is a soft update to `invitationStatus: removed` with
  `removedAt`; financial history is never deleted.
- `family_pockets/{pocketId}/invites/{inviteId}` stores pending invitation name
  and email. Only active admins can read or create these documents. MVP records
  the invitation but does not claim to deliver or accept it without a trusted
  backend workflow.
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
- Firestore document deletion is disabled by the rules for financial and audit
  records. The DEV database itself also has deletion protection enabled.

## Repository boundary

UI and application stores depend on the interfaces in
`lib/core/data/repository_contracts.dart`. Firebase implementations live in
`lib/core/data/firestore/firestore_repositories.dart`; this keeps provider code
out of features and leaves room for test/in-memory implementations.
