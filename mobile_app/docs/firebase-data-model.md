# Firebase data model

This is the Week 1 persistence contract. The existing in-memory feature stores
remain active until the Week 2 integration pass.

## Collections

- `users/{userId}` stores profile data, notification preferences, KYC status,
  and creation/update timestamps. The document ID must equal the Firebase Auth
  UID.
- `personal_health_pockets/{pocketId}` stores ownership, currency, lifecycle
  status, and timestamps. It does not store a mutable balance.
- `savings_plans/{planId}` stores a user's recurring amount, frequency, start
  date, next scheduled date, optional funding-source reference, and status.
- `contributions/{contributionId}` is the canonical append-only ledger for both
  personal and Family Pocket contributions. Exactly one of
  `personalHealthPocketId` or `familyPocketId` is present.
- `family_pockets/{pocketId}` stores the pocket name, beneficiary, creator,
  currency, status, and timestamps.
- `family_pockets/{pocketId}/members/{memberId}` stores role and invitation
  state. An accepted user's membership ID is their Auth UID. Removing a member
  is a soft update to `invitationStatus: removed` with `removedAt`; financial
  history is never deleted.
- `activities/{activityId}` is an append-only user-visible audit feed linked to
  the affected entity and, when applicable, a Family Pocket.

## Data decisions

- Firebase Auth is the account authority. MVP sign-in providers are verified
  Email/Password and Google; Firestore rejects unverified email identities.
- The six-digit HealthPocket app PIN is device-local only. Firestore has no PIN
  field. Only a salted PBKDF2-SHA256 hash is placed in OS-protected secure
  storage, with local attempt throttling. A new device must use Firebase sign-in
  and creates its own local PIN.

- Currency is explicitly stored as `NGN`; MVP amounts are positive integer
  naira values. Before integrating a real payment provider, this boundary must
  be revisited because most providers represent money in minor units (kobo).
- Balances are derived from completed, non-reversed contribution ledger entries
  instead of being independently writable. A trusted backend will be required
  when provider-confirmed transactions are introduced.
- The mobile client may record only `mock` or `manual` contributions in DEV.
  Provider-originated contributions are intentionally rejected by the current
  rules until a trusted backend or verified webhook owns those writes.
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
