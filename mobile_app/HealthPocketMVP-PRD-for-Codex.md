# HealthPocket MVP Product and Launch Plan

**Version:** MVP v1.1

**Status:** Active build

**Build window:** September–December 2026

**Target launch:** 1 January 2027 (controlled public beta)

**Audience:** Product, Engineering, Design, Operations

## Design system

- **Font:** Geomini
- **Primary:** Teal
- **Secondary:** Pinkish red
- **Accent:** Brownish gold, used sparingly for tier unlocks and other small
  highlights—not large surfaces
- **Reference prototype:** https://healthpocket-dashboard.netlify.app/

## 1. Product promise

HealthPocket helps Nigerians build a dedicated health-savings habit before a
medical need becomes an emergency. A user chooses how much to save and how
often, builds an ongoing health balance, and can use that balance with an
approved clinic, hospital, or pharmacy partner.

The MVP must prove two things:

1. People will save consistently for healthcare.
2. A small partner network can accept a clear HealthPocket care authorization
   and be settled through a controlled manual process.

HealthPocket is not insurance. “What your balance can cover” is educational
guidance only—not a provider quote, treatment guarantee, or promise of full
payment.

## 2. January beta outcome

By launch, a user should be able to:

- Create an account with email/password or Google.
- Verify an email address and securely return using a six-digit local app PIN.
- Complete a basic profile without SMS OTP, BVN/NIN verification, or identity
  document collection by HealthPocket.
- Configure and edit an ongoing daily, weekly, or monthly savings instruction.
- Fund a personal HealthPocket through a licensed financial partner and see a
  trustworthy contribution history and available balance.
- Create or participate in a Family Pocket where the selected financial and
  legal model supports it.
- Discover approved care partners in the pilot state.
- Scan a partner QR code, request use of an amount, and receive a short-lived
  HealthPocket authorization.
- Follow the authorization through service completion and manual settlement.

The pilot partner must see **HEALTHPOCKET AUTHORIZED**, not **PAID**, until
settlement has actually completed.

## 3. MVP scope

### Account and security

- Firebase Email/Password authentication
- Google Sign-In
- Email verification for password accounts
- Password reset
- Firebase session restoration
- Six-digit HealthPocket PIN for subsequent local unlocking
- PIN recovery through Firebase re-authentication
- Basic profile and notification preferences

The PIN supplements Firebase authentication. It never replaces the Firebase
credential and must not be stored in plaintext or ordinary Firestore.

### Personal health savings

- One default Personal HealthPocket per user
- Recurring amount and frequency: daily, weekly, or monthly
- Edit, pause, and resume the instruction
- Funding through a licensed financial/custody partner
- Provider-confirmed contribution records
- Current available balance and contribution history
- Zero-balance encouragement and first-deposit guidance
- Informational “What your balance can cover” reference bands

The default product has no savings target and never becomes “complete.” A goal
or target pocket, if introduced later, is a separate product.

### Family Pocket

- Create a pocket
- Invite and view members
- Admin, contributor, and beneficiary roles
- Admin removal of a contributor
- Shared balance and contribution history

A Family Pocket has no target or completion state. Removing a contributor must
not delete or reverse their historical contributions. Real-money Family Pocket
funding ships only if the chosen regulated partner and operating model support
ownership, beneficiary, and withdrawal controls safely; otherwise the feature
remains behind a beta flag until that dependency is resolved.

### Care-partner discovery and authorization

- Pilot directory for approved clinics, hospitals, and/or pharmacies
- Filter or search by state and partner type
- Partner QR identifies an approved facility; it must not contain sensitive
  user or medical data
- Server-created, short-lived, single-use authorization reference
- Amount confirmation and explicit user consent
- Partner verification screen or lightweight operations portal
- Authorization status history and expiry
- Manual service confirmation, reconciliation, and settlement records

Initial status flow:

```text
requested -> authorized -> careApproved -> serviceCompleted
          -> pendingSettlement -> settled
```

Cancelled, declined, and expired terminal paths must be supported. Only the
trusted backend may authorize, expire, or settle a care request. The mobile app
must never be the source of truth for balances or authorization state.

### Operations required for the pilot

- Approve and manage partner locations
- Confirm care authorizations
- Record completion and settlement evidence
- Reconcile partner-held funds, the HealthPocket ledger, and settlement records
- Resolve failed or disputed cases
- Maintain an auditable status history

## 4. Explicitly deferred until post-MVP

- Real SMS OTP or phone authentication
- HealthPocket-built production KYC
- BVN/NIN verification
- Identity-document or selfie collection by HealthPocket
- Biometrics as an authentication factor
- Treasury bills, investments, yield, or return projections
- Automated hospital/pharmacy settlement
- Insurance claims or coverage guarantees
- Open-ended nationwide partner onboarding
- Goal/target pockets

If the selected savings partner legally requires identity checks for the launch
account tier, use its compliant hosted or SDK-based flow where practical. Do
not build a custom KYC system. If that cannot satisfy the agreed MVP boundary,
it is a launch dependency to resolve—not a check to bypass.

## 5. Recommended launch sequence

### September — identity and durable product foundation

- Complete DEV/PROD Android isolation and keep debug builds on DEV Firebase.
- Implement Email/Password, Google Sign-In, email verification, password reset,
  session restoration, local PIN, and recovery.
- Persist profiles, personal pockets, savings instructions, contributions,
  Family Pockets, and activity behind repository interfaces.
- Remove seeded mock state from authenticated DEV user journeys.
- Keep emulators and security-rule tests in the development loop.
- Select the licensed savings/custody partner and document the integration,
  compliance, reconciliation, and failure-handling responsibilities.

**Current partner-research position:** Anchor is the leading candidate, pending
due diligence, technical validation, pricing, compliance review, and agreement.
No application domain model may depend directly on Anchor-specific types.

### October — real savings through the selected partner

- Integrate customer/account or virtual-account provisioning through the
  selected licensed partner.
- Receive trusted deposit confirmation through a backend webhook.
- Make the server-side contribution ledger authoritative and idempotent.
- Display pending, completed, failed, and reversed funding states accurately.
- Support recurring instructions only to the extent the partner safely enables
  them; never imply a debit occurred from a local schedule alone.
- Implement reconciliation, support tooling, and provider failure handling.

This is the point at which a trusted backend becomes a concrete requirement.
Use the smallest maintainable backend shape; do not introduce microservices.

### November — care network and QR authorization

- Launch the pilot partner directory.
- Build partner QR scanning and secure authorization creation.
- Build the minimum partner/operations verification surface.
- Enforce available-balance, expiry, replay-prevention, and status-transition
  rules on the backend.
- Implement manual completion, settlement, reconciliation, and audit history.
- Test first with pharmacies or small clinics if hospital onboarding is slower.

### December — closed pilot and launch hardening

- Run a closed pilot with approximately 2–5 partners in one state.
- Exercise deposits, reversals, authorization expiry, service completion,
  settlement, reconciliation, and support playbooks end to end.
- Complete accessibility, performance, security, privacy, crash, and poor-network
  testing.
- Finalize partner agreements, user-facing terms, privacy disclosures, support
  escalation, analytics, and launch measurements.
- Fix pilot findings and prepare a controlled January rollout.

### 1 January 2027 — controlled public beta

- Open only where savings custody and care-partner operations are ready.
- Use feature flags and invite/geographic limits when needed.
- Expand partners and states only after reconciliation and support remain
  reliable under real usage.

## 6. Core domain model

### User profile

```text
UserProfile
- userId
- fullName
- email
- phoneNumber (optional, unverified in MVP)
- stateOfResidence
- basic personal/emergency-contact information
- emailVerified
- notificationPreferences
- createdAt
- updatedAt
```

The account model retains extension points for future phone verification and
regulated KYC, but MVP clients must not collect or fabricate those results.

### Personal HealthPocket

```text
PersonalHealthPocket
- id
- userId
- currency
- status (active | restricted | closed)
- providerAccountReference (optional)
- createdAt
- updatedAt
```

### Savings plan

```text
SavingsPlan
- id
- userId
- personalHealthPocketId
- contributionAmount
- frequency (daily | weekly | monthly)
- startDate
- nextContributionDate (optional)
- status (active | paused)
- fundingSourceId (optional)
- createdAt
- updatedAt
```

Editing a plan changes future instructions and never rewrites contribution
history.

### Contribution

```text
Contribution
- id
- contributorUserId
- personalHealthPocketId OR familyPocketId
- savingsPlanId (optional)
- providerReference (optional)
- amount
- currency
- status (pending | completed | failed | reversed)
- source (manualTest | provider)
- note (optional)
- createdAt
- confirmedAt (optional)
```

Completed contributions, less valid reversals and authorized/settled debits,
form the balance. Production clients must not let a user create a “completed”
contribution merely by entering an amount.

### Family Pocket and membership

```text
FamilyPocket
- id
- name
- currency
- status (active | restricted | archived)
- createdBy
- createdAt
- updatedAt

FamilyMembership
- id
- pocketId
- userId
- role (admin | contributor | beneficiary)
- invitationStatus (pending | accepted | removed)
- joinedAt
- removedAt (optional)
```

### Care partner and authorization

```text
CarePartnerLocation
- id
- partnerId
- name
- type (clinic | hospital | pharmacy)
- state
- address
- status (active | suspended)
- qrReference

CareAuthorization
- id
- userId
- personalHealthPocketId OR familyPocketId
- partnerLocationId
- amount
- currency
- status
- expiresAt
- createdAt
- authorizedAt (optional)
- completedAt (optional)
- settlementReference (optional)
```

Every balance-affecting event and authorization transition must be auditable
and idempotent.

## 7. Technical direction and guardrails

- Flutter mobile application, mobile first
- Firebase Authentication for MVP identity
- Cloud Firestore for current application data
- Repository interfaces between features and Firebase/provider SDKs
- Modular monolith and one trusted backend when real financial workflows begin
- Separate DEV and PROD projects, credentials, application IDs, and deploy paths
- Emulator-backed rules tests and least-privilege access
- Integer minor currency units or another explicit money representation at the
  partner boundary; never floating-point arithmetic for money
- No secrets, provider signing keys, webhook validation, balance authority, or
  settlement authority in the mobile client
- No direct production data changes during normal development

## 8. Launch gates

The January beta does not open until all of these are true:

- Licensed custody/funding partner agreement and technical integration approved
- Real deposits confirmed from trusted provider events
- Ledger and partner reconciliation tested
- QR authorization cannot overspend, replay, or remain valid after expiry
- Manual settlement and exception procedures rehearsed
- Pilot partners trained on **AUTHORIZED** versus **PAID**
- Privacy, terms, user support, and incident ownership approved
- Critical auth, data-isolation, and money-flow tests pass
- Monitoring and launch metrics are available

## 9. MVP success measures

Primary measures:

- Verified-account onboarding completion
- First successful deposit rate
- Recurring contribution adherence and 30-day saver retention
- Number and value of completed contributions
- Care-partner discovery-to-authorization conversion
- Authorization-to-service-completion rate
- Settlement accuracy and time
- Support, failed-deposit, expired-authorization, and dispute rates

Family Pocket adoption is a secondary measure until the regulated operating
model is confirmed. The MVP succeeds when real users repeatedly save for
healthcare and a small partner network can reliably honor and settle approved
care—not when the app merely demonstrates more features.
