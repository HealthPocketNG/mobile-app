"use strict";

const {
  BackendError,
  ERROR_CODES,
  assertVerifiedGoogleIdentity,
  runCallable,
} = require("./errors/backend-error");
const { buildRateLimitService } = require("./abuse/rate-limit-service");

const OUTER_FIELDS = new Set(["action", "payload"]);
const ACTION_RATE_LIMITS = Object.freeze({
  "family.invite_create": limits([5, 3600], [20, 86400]),
  "family.invite_resolve": limits([20, 600], [100, 86400]),
  "family.invite_respond": limits([10, 600], [50, 86400]),
  "funding.initialize": limits([5, 600], [20, 3600]),
  "funding.verify": limits([20, 300], [100, 3600]),
  "family.contribution_initialize": limits([5, 600], [20, 3600]),
  "family.contribution_verify": limits([20, 300], [100, 3600]),
  "healthcare.partner_initialize": limits([5, 600], [20, 3600]),
  "healthcare.non_partner_initialize": limits([5, 600], [20, 3600]),
  "healthcare.verify": limits([20, 300], [100, 3600]),
  "notifications.register_device": limits([10, 600], [50, 86400]),
});

function buildTrustedBackend({
  db,
  services,
  logger = console,
  moneyEnabled = false,
  rateLimiter,
}) {
  if (!db || typeof db.collection !== "function") {
    throw new TypeError("A Firestore Admin database is required.");
  }
  const required = [
    "ledger", "payments", "savings", "family", "healthcare", "coverage",
    "notifications", "activity", "receipts",
  ];
  for (const name of required) {
    if (!services?.[name] || typeof services[name] !== "object") {
      throw new TypeError(`Trusted service ${name} is required.`);
    }
  }
  const limiter = rateLimiter || (typeof db.runTransaction === "function"
    ? buildRateLimitService({ db, logger })
    : { async consume() {} });

  const actions = {
    "wallet.ensure": command([], ({ identity }) =>
      services.ledger.ensureWallet(identity.userId)),

    "funding.initialize": moneyCommand(
      ["amountKobo", "idempotencyKey"],
      ({ identity, payload }) => services.payments.initializeFunding({
        userId: identity.userId,
        amountKobo: payload.amountKobo,
        idempotencyKey: payload.idempotencyKey,
        ledgerSource: "funding",
      }),
    ),
    "funding.verify": moneyCommand(["attemptId"], async ({ identity, payload }) => {
      await assertRecordOwner(db, "payment_attempts", payload.attemptId,
        identity.userId, "userId");
      return services.payments.verifyFunding({ attemptId: payload.attemptId });
    }),

    "savings.create": command([
      "personalHealthPocketId", "contributionAmountKobo", "frequency",
      "startDate", "fundingSourceId", "idempotencyKey",
    ], ({ identity, payload }) => services.savings.createPlan({
      ...payload, userId: identity.userId,
    })),
    "savings.update": command([
      "contributionAmountKobo", "frequency", "startDate", "fundingSourceId",
      "idempotencyKey",
    ], ({ identity, payload }) => services.savings.updatePlan({
      ...payload, userId: identity.userId,
    })),
    "savings.pause": planTransition(services.savings.pausePlan),
    "savings.resume": planTransition(services.savings.resumePlan),
    "savings.cancel": planTransition(services.savings.cancelPlan),

    "family.create": command([
      "idempotencyKey", "name", "description", "imagePath", "frequency",
      "defaultContributionAmountKobo",
    ], ({ identity, payload }) => services.family.createPocket({
      ...payload,
      ownerId: identity.userId,
      ownerName: identity.displayName,
    })),
    "family.update": command([
      "pocketId", "name", "description", "imagePath", "frequency",
      "defaultContributionAmountKobo",
    ], ({ identity, payload }) => services.family.updatePocket({
      ...payload, actorId: identity.userId,
    })),
    "family.invite_create": command([
      "pocketId", "idempotencyKey", "inviteeName", "email", "role",
      "canContribute",
    ], ({ identity, payload }) => services.family.createInvite({
      ...payload, actorId: identity.userId,
    })),
    "family.invite_resolve": command(["code"], ({ payload }) =>
      services.family.resolveInviteCode(payload)),
    "family.invite_respond": command(["code", "accept"], ({ identity, payload }) => {
      if (!identity.email) throw new BackendError(ERROR_CODES.PERMISSION_DENIED);
      return services.family.respondToInvite({
        ...payload,
        userId: identity.userId,
        userName: identity.displayName,
        email: identity.email,
        emailVerified: true,
      });
    }),
    "family.membership_change": command(
      ["pocketId", "memberId", "action"],
      ({ identity, payload }) => services.family.changeMembership({
        ...payload, actorId: identity.userId,
      }),
    ),
    "family.ownership_transfer": command(
      ["pocketId", "newOwnerId"],
      ({ identity, payload }) => services.family.transferOwnership({
        ...payload, ownerId: identity.userId,
      }),
    ),
    "family.close": command(["pocketId"], ({ identity, payload }) =>
      services.family.closePocket({ ...payload, ownerId: identity.userId })),
    "family.contribution_initialize": moneyCommand(
      ["pocketId", "amountKobo", "idempotencyKey"],
      ({ identity, payload }) => services.family.initializeContribution({
        ...payload, userId: identity.userId,
      }),
    ),
    "family.contribution_verify": moneyCommand(
      ["attemptId"],
      async ({ identity, payload }) => {
        await assertRecordOwner(db, "family_contribution_attempts",
          payload.attemptId, identity.userId, "contributorUserId");
        return services.family.verifyContribution(payload);
      },
    ),

    "healthcare.partner_initialize": moneyCommand(
      ["providerId", "amountKobo", "idempotencyKey"],
      ({ identity, payload }) => services.healthcare.initiatePartnerPayment({
        ...payload, userId: identity.userId,
      }),
    ),
    "healthcare.non_partner_initialize": moneyCommand(
      ["providerId", "amountKobo", "idempotencyKey", "bankAccount"],
      ({ identity, payload }) => services.healthcare.initiateNonPartnerPayment({
        ...payload, userId: identity.userId,
      }),
    ),
    "healthcare.verify": moneyCommand(["paymentId"], ({ identity, payload }) =>
      services.healthcare.verifyPayment({
        paymentId: payload.paymentId,
        userId: identity.userId,
      })),

    "coverage.evaluate": command(["limit"], ({ identity, payload }) =>
      services.coverage.evaluateCoverage({
        actorId: identity.userId,
        limit: payload.limit,
      })),

    "notifications.list": command(
      ["readState", "pageSize", "cursor"],
      ({ identity, payload }) => services.notifications.list({
        ...payload, actorId: identity.userId,
      }),
    ),
    "notifications.mark_read": command(["notificationId"], ({ identity, payload }) =>
      services.notifications.markRead({ ...payload, actorId: identity.userId })),
    "notifications.mark_all_read": command([], ({ identity }) =>
      services.notifications.markAllRead({ actorId: identity.userId })),
    "notifications.register_device": command(["token", "platform"],
      ({ identity, payload }) => services.notifications.registerDevice({
        ...payload, actorId: identity.userId,
      })),
    "notifications.remove_device": command(["token"], ({ identity, payload }) =>
      services.notifications.removeDevice({ ...payload, actorId: identity.userId })),
    "notifications.refresh_device": command(
      ["oldToken", "newToken", "platform"],
      ({ identity, payload }) => services.notifications.refreshDevice({
        ...payload, actorId: identity.userId,
      }),
    ),

    "activity.list": command([
      "familyPocketId", "activityType", "startDate", "endDate", "pageSize",
      "cursor",
    ], ({ identity, payload }) => services.activity.listHistory({
      ...payload, actorId: identity.userId,
    })),
    "activity.detail": command(["activityId"], ({ identity, payload }) =>
      services.activity.getTransactionDetail({
        ...payload, actorId: identity.userId,
      })),
    "activity.statement": command([
      "familyPocketId", "activityType", "startDate", "endDate", "maxRecords",
    ], ({ identity, payload }) => services.activity.prepareStatement({
      ...payload, actorId: identity.userId,
    })),
    "receipt.get": command(["receiptNumber"], ({ identity, payload }) =>
      services.receipts.getReceipt({ ...payload, userId: identity.userId })),
    "receipt.export": command(["receiptNumber", "format"], ({ identity, payload }) =>
      services.receipts.exportReceipt({ ...payload, userId: identity.userId })),
  };

  function command(allowedFields, execute) {
    return { allowedFields: new Set(allowedFields), execute, money: false };
  }

  function moneyCommand(allowedFields, execute) {
    return { allowedFields: new Set(allowedFields), execute, money: true };
  }

  function planTransition(method) {
    return command(["idempotencyKey"], ({ identity, payload }) =>
      method({ ...payload, userId: identity.userId }));
  }

  async function callable(request) {
    const requestedAction = request?.data?.action;
    const operation = typeof requestedAction === "string" &&
      /^[a-z][a-z0-9_.]{2,63}$/.test(requestedAction)
      ? requestedAction.replaceAll(".", "_")
      : "trusted_backend";
    return runCallable({
      operation,
      logger,
      handler: async () => {
        const outer = requireObject(request?.data, "request");
        assertOnlyFields(outer, OUTER_FIELDS);
        const action = requireAction(outer.action);
        const definition = actions[action];
        if (!definition) throw new BackendError(ERROR_CODES.INVALID_ARGUMENT);
        const payload = requireObject(outer.payload ?? {}, "payload");
        assertOnlyFields(payload, definition.allowedFields);
        const identity = assertVerifiedGoogleIdentity(request.auth);
        if (definition.money && !moneyEnabled) {
          throw new BackendError(ERROR_CODES.UNAVAILABLE);
        }
        const rateRules = ACTION_RATE_LIMITS[action];
        if (rateRules) {
          await limiter.consume({
            subjectId: identity.userId,
            operation: action,
            rules: rateRules,
          });
        }
        return definition.execute({ identity, payload });
      },
    });
  }

  return Object.freeze({ callable, actions: Object.freeze(Object.keys(actions)) });
}

function limits(...entries) {
  return Object.freeze(entries.map(([maxAttempts, windowSeconds]) =>
    Object.freeze({ maxAttempts, windowSeconds })));
}

async function assertRecordOwner(db, collection, documentId, userId, ownerField) {
  if (typeof documentId !== "string" || !/^[A-Za-z0-9_-]{1,256}$/.test(documentId)) {
    throw new BackendError(ERROR_CODES.INVALID_ARGUMENT);
  }
  const snapshot = await db.collection(collection).doc(documentId).get();
  if (!snapshot.exists || snapshot.data()?.[ownerField] !== userId) {
    // Avoid confirming that another user's financial record exists.
    throw new BackendError(ERROR_CODES.NOT_FOUND);
  }
}

function requireObject(value, _name) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new BackendError(ERROR_CODES.INVALID_ARGUMENT);
  }
  return value;
}

function assertOnlyFields(value, allowed) {
  if (Object.keys(value).length > 20 ||
      Object.keys(value).some((field) => !allowed.has(field))) {
    throw new BackendError(ERROR_CODES.INVALID_ARGUMENT);
  }
}

function requireAction(value) {
  if (typeof value !== "string" || !/^[a-z][a-z0-9_.]{2,63}$/.test(value)) {
    throw new BackendError(ERROR_CODES.INVALID_ARGUMENT);
  }
  return value;
}

module.exports = { ACTION_RATE_LIMITS, buildTrustedBackend, assertRecordOwner };
