# Backend hardening and frontend readiness

Status as of 2026-10-21: the local/mock MVP backend is ready to be connected to
the Flutter feature UI. This is not a production-payment or live-deployment
approval.

## Audit outcome

| Area | Status | Evidence |
| --- | --- | --- |
| Firestore and Storage authorization | DONE | Security review score 5/5; 54/54 adversarial rules tests pass |
| Callable command boundary | DONE | 33 allowlisted actions; verified identity; server-derived ownership; runtime smoke passes |
| Flutter callable transport | DONE | Region-aware typed action client, emulator routing, safe error decoding, and 60-second timeout |
| Frontend/backend contract drift protection | DONE | Versioned manifest is checked against both the Functions router and Dart action enum |
| Date transport | DONE | Callable dates use UTC ISO-8601 strings; timezone-ambiguous strings fail closed |
| Settlement-result binding | DONE | Reference, amount, currency, and beneficiary are checked before wallet or Family Pocket credit |
| Privacy-safe diagnostics | DONE | Logs exclude payloads and personal/financial fields; clients receive safe codes and correlation IDs |
| App Check enforcement | BLOCKED | Register and activate each real app first, observe valid-token traffic, then enable enforcement on callable Functions |
| Live Firebase deployment/backfill | BLOCKED | Requires an explicit deployment window and production verification |
| Live Storage uploads | BLOCKED | Billing issue remains unresolved; initials or Google account photo stay active |
| Real payment/MCC adapters | BLOCKED | Requires regulated provider, credentials, compliance approval, webhook endpoint, and production reconciliation |
| Real push/email delivery | BLOCKED | Requires provider credentials and device/provider validation; current adapters remain mock/server-only |
| Partner coverage/provider data | BLOCKED | Requires approved real source data and release ownership |

## Frontend integration contract

- Inject `TrustedBackendClient` from `AppState`; do not call Cloud Functions or
  write financial collections directly from screens.
- Use `TrustedBackendAction` rather than handwritten action strings. The source
  of truth is `config/trusted-backend-contract.json`.
- Send money as integer kobo and dates through `backendUtcDate`, which emits a
  UTC ISO-8601 value.
- Convert callable failures with `backendFailureFromCallable`. Display the safe
  message/action and include the correlation ID only when the user needs to
  contact support.
- Treat `pending` and `timed_out` as unresolved. Refresh or verify status; never
  infer success from a client timeout.
- Continue using initials or the verified Google photo until the live Storage
  gate is cleared.

## Before any production rollout

1. Resolve billing and test profile/Family Pocket images in the live dev project.
2. Register App Check providers for every shipped platform, activate the client,
   monitor valid-token traffic, and only then enforce App Check on callables.
3. Deploy rules, indexes, and Functions to the dev project; run wallet backfill
   and catalog seeds in dry-run mode before applying them.
4. Run the complete UI journey suite against dev Firebase, including offline,
   retry, duplicate-tap, expired-session, and interrupted-payment cases.
5. Configure monitoring, budget alerts, backups/restore drills, secret access,
   and an incident rollback owner.
6. Keep every real-money command fail-closed until the regulated-provider
   cutover checklist in `real-payment-readiness.md` is satisfied.

## Verified local baseline

- Functions/services: 135/135 passing.
- Firestore and Storage rules: 54/54 passing.
- Flutter: 99/99 passing.
- Flutter static analysis: no issues.
- Functions emulator: all three exports loaded and the callable protocol smoke
  test passed.

No live Firebase resource, production credential, webhook, settlement adapter,
or App Check enforcement setting was changed during this phase.
