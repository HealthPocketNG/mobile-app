# Backend emulator and automated tests

HealthPocket backend development uses the Firebase Emulator Suite with the
demo project `demo-healthpocket`. Emulator tests must never target a live
Firebase project.

## Test commands

Run the Functions and service suite against Firestore:

```powershell
firebase emulators:exec --only firestore --project demo-healthpocket "npm --prefix functions test"
```

Run the Firestore and Storage security-rule suites:

```powershell
firebase emulators:exec --only firestore,storage --project demo-healthpocket "npm --prefix firebase-tests test"
```

Start the actual Functions runtime and exercise the exported callable protocol:

```powershell
firebase emulators:exec --only functions,firestore --project demo-healthpocket "npm --prefix functions run test:emulator-smoke"
```

Run Flutter repository, service, and client integration tests:

```powershell
flutter test
```

If the Functions emulator uses a non-default port, set
`FUNCTIONS_EMULATOR_ORIGIN` to the complete regional base URL before running
the smoke script.

## Coverage map

- `functions/test/backend-journey.test.js` drives realistic authenticated
  funding, healthcare, Family Pocket, savings scheduling, coverage, history,
  notification, receipt, idempotency, reconciliation, and unauthorized-access
  journeys through `trustedBackend`.
- `test/mvp_auth_journey_test.dart` covers the complete new-user onboarding,
  PIN restoration, and logout boundary. The activity ledger tests cover
  category/date filtering and case-insensitive text search.
- The remaining Functions tests cover wallet/ledger invariants, concurrent
  credits and debits, funding and healthcare lifecycle outcomes, non-partner
  verification, savings scheduling, Family Pocket permissions and concurrent
  contributions, notifications, and receipts.
- `firebase-tests/firestore.rules.test.mjs` and
  `firebase-tests/storage.rules.test.mjs` red-team cross-user reads, writes,
  ownership, identity strength, immutable financial records, and image paths.
- `functions/scripts/smoke-functions-emulator.js` confirms that the deployed
  callable shape loads in the emulator and rejects an unauthenticated request
  with the safe public error contract.

## Verified baseline

On 2026-10-21, Firestore Standard produced these local results:

- Functions/services: 130/130 passing.
- Firestore rules: 48/48 passing.
- Storage rules: 6/6 passing.
- Flutter: 94/94 passing.
- Realistic trusted-backend journeys: 5/5 passing (included in the Functions
  total).
- Functions emulator: all three exports discovered and the callable boundary
  smoke test passed.

No live Firebase resources were changed by this test phase.

The Number 23 readiness additions cover server-only polling reconciliation and
signed-callback matching for provider reference, amount, currency, and
beneficiary. See `real-payment-readiness.md` for the gate audit and production
cutover requirements.

## MVP journey evidence

The Number 22 journey suite proves the following against local/mock
infrastructure:

- Auth, onboarding, profile, PIN restoration, and the logout boundary.
- Savings-plan create/update/pause/resume plus scheduled success, retry, and
  failure outcomes.
- Manual funding and healthcare payment lifecycles, including non-partner
  verification, insufficient funds, receipts, notifications, and idempotency.
- Family Pocket creation, canonical image-path persistence, invitation and
  membership, concurrent contributions, reconciliation, and outsider denial.
- Provider discovery with valid coordinates, transaction filtering/search,
  receipt/statement export, and coverage bands from zero through high balance.

Storage emulator tests prove the Family Pocket image path is writable only by
an authenticated administrator and readable only by active members. Live image
selection/upload remains intentionally disabled until Firebase billing is
resolved; the app continues to use initials or the Google account photo.
