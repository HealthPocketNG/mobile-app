# HealthPocket trusted backend

This Node 22 Cloud Functions codebase owns authoritative wallet and ledger
mutations. Flutter has no API that can set a balance or create a completed
ledger entry.

`createWalletForNewProfile` creates a zero-balance wallet after a user profile
is created. `ensureMyWallet` is an authenticated, idempotent backfill path and
cannot accept an amount. Future funding and payment functions must import
`src/ledger-service.js` only after their provider-side verification succeeds.

Run the transaction suite from the repository root:

```powershell
firebase emulators:exec --only firestore "npm --prefix functions test" --project demo-healthpocket
```

Run Functions and Firestore together to validate function discovery:

```powershell
firebase emulators:exec --only firestore,functions "npm --prefix functions test" --project demo-healthpocket
```

DEV deployment and existing-user wallet backfill are intentionally deferred
until Cloud Billing is available. Do not treat the older `dev_simulation`
contribution records as real money or migrate them into authoritative wallets.
