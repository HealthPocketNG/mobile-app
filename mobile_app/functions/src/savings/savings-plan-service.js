"use strict";

const { createHash } = require("node:crypto");
const { Timestamp } = require("firebase-admin/firestore");
const { PAYMENT_STATUS } = require("../payments/payment-gateway");

const CURRENCY = "NGN";
const DEFAULT_CONTRIBUTION_AMOUNT_KOBO = 50000;
const MAX_AMOUNT_KOBO = 100000000000;
const SAFE_ID = /^[A-Za-z0-9_-]{1,256}$/;
const USER_ID = /^[A-Za-z0-9_-]{1,128}$/;
const REQUEST_KEY = /^[A-Za-z0-9_-]{16,80}$/;
const FREQUENCIES = new Set(["daily", "weekly", "monthly"]);
const PLAN_STATUSES = new Set(["active", "paused", "cancelled"]);
const CONTRIBUTION_STATUSES = new Set(["pending", "succeeded", "failed"]);

class SavingsPlanError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "SavingsPlanError";
    this.code = code;
  }
}

function buildSavingsPlanService({
  db,
  payments,
  clock = () => new Date(),
  logger = console,
}) {
  if (!db || typeof db.runTransaction !== "function") {
    throw new TypeError("A Firestore Admin database is required.");
  }
  if (!payments || typeof payments.initializeFunding !== "function" ||
      typeof payments.verifyFunding !== "function") {
    throw new TypeError("The trusted payment service is required.");
  }

  const plans = db.collection("savings_plans");
  const pockets = db.collection("personal_health_pockets");
  const operations = db.collection("savings_plan_operations");
  const scheduledContributions = db.collection("scheduled_contributions");
  const activities = db.collection("activities");

  async function createPlan(input) {
    const now = nowFrom(clock);
    const userId = requireUserId(input?.userId);
    const planId = planIdFor(userId);
    const pocketId = input.personalHealthPocketId || pocketIdFor(userId);
    requireSafeId(pocketId, "personalHealthPocketId");
    const amountKobo = input.contributionAmountKobo ??
      DEFAULT_CONTRIBUTION_AMOUNT_KOBO;
    requireAmount(amountKobo);
    const frequency = input.frequency || "monthly";
    requireFrequency(frequency);
    const startDate = requireDate(input.startDate ?? now, "startDate");
    requireRequestKey(input.idempotencyKey);
    const normalized = {
      action: "create",
      userId,
      planId,
      pocketId,
      amountKobo,
      frequency,
      startDate: startDate.toISOString(),
      fundingSourceId: optionalBoundedString(
        input.fundingSourceId,
        "fundingSourceId",
        128,
      ),
      idempotencyKey: input.idempotencyKey,
    };

    await applyMutation(normalized, async (transaction, planRef) => {
      const [planSnapshot, pocketSnapshot] = await Promise.all([
        transaction.get(planRef),
        transaction.get(pockets.doc(pocketId)),
      ]);
      if (planSnapshot.exists) {
        throw new SavingsPlanError(
          "plan-already-exists",
          "A savings plan already exists for this user.",
        );
      }
      if (!pocketSnapshot.exists || pocketSnapshot.data().userId !== userId ||
          pocketSnapshot.data().status !== "active") {
        throw new SavingsPlanError(
          "pocket-unavailable",
          "The personal health pocket is unavailable.",
        );
      }
      transaction.create(planRef, {
        userId,
        personalHealthPocketId: pocketId,
        contributionAmountKobo: amountKobo,
        frequency,
        startDate: Timestamp.fromDate(startDate),
        nextContributionDate: Timestamp.fromDate(
          calculateNextContributionDate({ startDate, frequency, after: now }),
        ),
        status: "active",
        fundingSourceId: normalized.fundingSourceId,
        createdAt: Timestamp.fromDate(now),
        updatedAt: Timestamp.fromDate(now),
      });
    });
    log(logger, "create_plan", "success");
    return getPlan(userId);
  }

  async function updatePlan(input) {
    const userId = requireUserId(input?.userId);
    requireRequestKey(input.idempotencyKey);
    if (input.contributionAmountKobo === undefined &&
        input.frequency === undefined && input.startDate === undefined &&
        input.fundingSourceId === undefined) {
      throw new SavingsPlanError("invalid-argument", "No plan changes were supplied.");
    }
    if (input.contributionAmountKobo !== undefined) {
      requireAmount(input.contributionAmountKobo);
    }
    if (input.frequency !== undefined) requireFrequency(input.frequency);
    const startDate = input.startDate === undefined
      ? undefined
      : requireDate(input.startDate, "startDate");
    const fundingSourceId = input.fundingSourceId === undefined
      ? undefined
      : optionalBoundedString(input.fundingSourceId, "fundingSourceId", 128);
    const normalized = {
      action: "update",
      userId,
      planId: planIdFor(userId),
      contributionAmountKobo: input.contributionAmountKobo ?? null,
      frequency: input.frequency ?? null,
      startDate: startDate?.toISOString() ?? null,
      fundingSourceId: fundingSourceId ?? null,
      fundingSourceSupplied: input.fundingSourceId !== undefined,
      idempotencyKey: input.idempotencyKey,
    };

    await applyMutation(normalized, async (transaction, planRef, plan) => {
      requireMutablePlan(plan);
      const now = nowFrom(clock);
      const nextStartDate = startDate || plan.startDate.toDate();
      const nextFrequency = input.frequency || plan.frequency;
      const update = {
        contributionAmountKobo:
          input.contributionAmountKobo ?? plan.contributionAmountKobo,
        frequency: nextFrequency,
        startDate: Timestamp.fromDate(nextStartDate),
        nextContributionDate: plan.status === "active"
          ? Timestamp.fromDate(calculateNextContributionDate({
            startDate: nextStartDate,
            frequency: nextFrequency,
            after: now,
          }))
          : null,
        updatedAt: Timestamp.fromDate(now),
      };
      if (input.fundingSourceId !== undefined) {
        update.fundingSourceId = fundingSourceId;
      }
      transaction.update(planRef, update);
    });
    log(logger, "update_plan", "success");
    return getPlan(userId);
  }

  async function pausePlan(input) {
    return transitionPlan(input, "pause", "active", "paused", null);
  }

  async function resumePlan(input) {
    return transitionPlan(input, "resume", "paused", "active", "calculate");
  }

  async function cancelPlan(input) {
    const userId = requireUserId(input?.userId);
    requireRequestKey(input.idempotencyKey);
    const normalized = {
      action: "cancel",
      userId,
      planId: planIdFor(userId),
      idempotencyKey: input.idempotencyKey,
    };
    await applyMutation(normalized, async (transaction, planRef, plan) => {
      requireMutablePlan(plan);
      transaction.update(planRef, {
        status: "cancelled",
        nextContributionDate: null,
        updatedAt: Timestamp.fromDate(nowFrom(clock)),
      });
    });
    log(logger, "cancel_plan", "success");
    return getPlan(userId);
  }

  async function transitionPlan(input, action, from, to, schedule) {
    const userId = requireUserId(input?.userId);
    requireRequestKey(input.idempotencyKey);
    const normalized = {
      action,
      userId,
      planId: planIdFor(userId),
      idempotencyKey: input.idempotencyKey,
    };
    await applyMutation(normalized, async (transaction, planRef, plan) => {
      if (plan.status !== from) {
        throw new SavingsPlanError(
          "invalid-state",
          `Only a ${from} savings plan can be ${action}d.`,
        );
      }
      const now = nowFrom(clock);
      transaction.update(planRef, {
        status: to,
        nextContributionDate: schedule === "calculate"
          ? Timestamp.fromDate(calculateNextContributionDate({
            startDate: plan.startDate.toDate(),
            frequency: plan.frequency,
            after: now,
          }))
          : null,
        updatedAt: Timestamp.fromDate(now),
      });
    });
    log(logger, `${action}_plan`, "success");
    return getPlan(userId);
  }

  async function applyMutation(normalized, mutate) {
    const operationId = operationIdFor(
      normalized.userId,
      normalized.idempotencyKey,
    );
    const operationRef = operations.doc(operationId);
    const planRef = plans.doc(normalized.planId);
    const activityRef = activities.doc(`activity_${operationId.slice(10)}`);
    const fingerprint = hash(normalized);

    await db.runTransaction(async (transaction) => {
      const [operationSnapshot, planSnapshot] = await Promise.all([
        transaction.get(operationRef),
        transaction.get(planRef),
      ]);
      if (operationSnapshot.exists) {
        if (operationSnapshot.data().requestFingerprint !== fingerprint) {
          throw new SavingsPlanError(
            "idempotency-conflict",
            "The idempotency key was reused for another plan change.",
          );
        }
        return;
      }
      const plan = planSnapshot.exists ? planSnapshot.data() : null;
      if (normalized.action !== "create" && !plan) {
        throw new SavingsPlanError("plan-not-found", "Savings plan was not found.");
      }
      await mutate(transaction, planRef, plan);
      const now = Timestamp.fromDate(nowFrom(clock));
      transaction.create(operationRef, {
        userId: normalized.userId,
        planId: normalized.planId,
        action: normalized.action,
        requestFingerprint: fingerprint,
        createdAt: now,
      });
      transaction.create(activityRef, {
        userId: normalized.userId,
        activityType: `savings_plan_${normalized.action}`,
        metadata: {
          action: normalized.action,
        },
        relatedEntityType: "savings_plan",
        relatedEntityId: normalized.planId,
        status: "recorded",
        moneyMovement: false,
        createdAt: now,
      });
    });
  }

  async function getPlan(userId) {
    const normalizedUserId = requireUserId(userId);
    const snapshot = await plans.doc(planIdFor(normalizedUserId)).get();
    return snapshot.exists ? planResult(snapshot.id, snapshot.data()) : null;
  }

  async function listDuePlans({ asOf = nowFrom(clock), limit = 100 } = {}) {
    const date = requireDate(asOf, "asOf");
    if (!Number.isInteger(limit) || limit < 1 || limit > 500) {
      throw new SavingsPlanError("invalid-argument", "Due-plan limit is invalid.");
    }
    const snapshot = await plans
      .where("status", "==", "active")
      .where("nextContributionDate", "<=", Timestamp.fromDate(date))
      .orderBy("nextContributionDate", "asc")
      .limit(limit)
      .get();
    return snapshot.docs.map((document) => planResult(document.id, document.data()));
  }

  async function processDueContribution({ planId, scheduledFor }) {
    requireSafeId(planId, "planId");
    const scheduleDate = requireDate(scheduledFor, "scheduledFor");
    const contributionId = scheduledContributionIdFor(planId, scheduleDate);
    const contributionRef = scheduledContributions.doc(contributionId);
    const planRef = plans.doc(planId);
    const now = nowFrom(clock);

    let contribution = await db.runTransaction(async (transaction) => {
      const [existing, planSnapshot] = await Promise.all([
        transaction.get(contributionRef),
        transaction.get(planRef),
      ]);
      if (existing.exists) return existing.data();
      if (!planSnapshot.exists) {
        throw new SavingsPlanError("plan-not-found", "Savings plan was not found.");
      }
      const plan = planSnapshot.data();
      if (plan.status !== "active" || !plan.nextContributionDate ||
          plan.nextContributionDate.toMillis() !== scheduleDate.getTime() ||
          scheduleDate.getTime() > now.getTime()) {
        throw new SavingsPlanError(
          "not-due",
          "Savings contribution is not currently due.",
        );
      }
      const document = {
        userId: plan.userId,
        savingsPlanId: planId,
        scheduledFor: Timestamp.fromDate(scheduleDate),
        amountKobo: plan.contributionAmountKobo,
        currency: CURRENCY,
        status: "pending",
        paymentAttemptId: null,
        providerReference: null,
        ledgerOperationId: null,
        failureCode: null,
        createdAt: Timestamp.fromDate(now),
        updatedAt: Timestamp.fromDate(now),
      };
      transaction.create(contributionRef, document);
      return document;
    });

    if (contribution.status !== "pending") {
      return scheduledContributionResult(contributionId, contribution);
    }

    let paymentAttempt;
    if (contribution.paymentAttemptId) {
      paymentAttempt = {
        attemptId: contribution.paymentAttemptId,
        status: PAYMENT_STATUS.PENDING,
        providerReference: contribution.providerReference,
      };
    } else {
      paymentAttempt = await payments.initializeFunding({
        userId: contribution.userId,
        idempotencyKey: `scheduled_${hash({ contributionId }).slice(0, 40)}`,
        amountKobo: contribution.amountKobo,
        ledgerSource: "savings_contribution",
      });
      contribution = await persistPaymentAttempt(contributionRef, paymentAttempt);
    }

    let outcome;
    if ([PAYMENT_STATUS.FAILED, PAYMENT_STATUS.CANCELLED,
      PAYMENT_STATUS.TIMED_OUT].includes(paymentAttempt.status)) {
      outcome = {
        status: "failed",
        ledgerOperationId: null,
        failureCode: paymentAttempt.failureCode || paymentAttempt.status,
      };
    } else {
      try {
        const verification = await payments.verifyFunding({
          attemptId: paymentAttempt.attemptId,
        });
        outcome = contributionOutcome(verification);
      } catch (error) {
        if (error?.code !== "provider-timeout") throw error;
        outcome = {
          status: "pending",
          ledgerOperationId: null,
          failureCode: "verification-timeout",
        };
      }
    }

    await contributionRef.update({
      status: outcome.status,
      ledgerOperationId: outcome.ledgerOperationId,
      failureCode: outcome.failureCode,
      updatedAt: Timestamp.fromDate(nowFrom(clock)),
    });
    await advanceSchedule(planRef, scheduleDate);
    await recordContributionActivity(contributionId, contribution, outcome.status);
    contribution = (await contributionRef.get()).data();
    log(logger, "process_scheduled_contribution", outcome.status);
    return scheduledContributionResult(contributionId, contribution);
  }

  async function persistPaymentAttempt(reference, paymentAttempt) {
    const status = [PAYMENT_STATUS.FAILED, PAYMENT_STATUS.CANCELLED,
      PAYMENT_STATUS.TIMED_OUT].includes(paymentAttempt.status)
      ? "failed"
      : "pending";
    await reference.update({
      paymentAttemptId: paymentAttempt.attemptId,
      providerReference: paymentAttempt.providerReference,
      status,
      failureCode: status === "failed"
        ? paymentAttempt.failureCode || paymentAttempt.status
        : null,
      updatedAt: Timestamp.fromDate(nowFrom(clock)),
    });
    return (await reference.get()).data();
  }

  async function advanceSchedule(planRef, scheduledFor) {
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(planRef);
      if (!snapshot.exists) return;
      const plan = snapshot.data();
      if (plan.status !== "active" || !plan.nextContributionDate ||
          plan.nextContributionDate.toMillis() !== scheduledFor.getTime()) {
        return;
      }
      const now = nowFrom(clock);
      transaction.update(planRef, {
        nextContributionDate: Timestamp.fromDate(calculateNextContributionDate({
          startDate: plan.startDate.toDate(),
          frequency: plan.frequency,
          after: new Date(Math.max(now.getTime(), scheduledFor.getTime() + 1)),
        })),
        updatedAt: Timestamp.fromDate(now),
      });
    });
  }

  async function recordContributionActivity(contributionId, contribution, status) {
    const activityId = `activity_${hash({ contributionId, status }).slice(0, 48)}`;
    const reference = activities.doc(activityId);
    await db.runTransaction(async (transaction) => {
      if ((await transaction.get(reference)).exists) return;
      transaction.create(reference, {
        userId: contribution.userId,
        activityType: "scheduled_savings_contribution",
        metadata: {
          amountKobo: contribution.amountKobo,
          currency: CURRENCY,
          status,
        },
        relatedEntityType: "scheduled_contribution",
        relatedEntityId: contributionId,
        status,
        moneyMovement: status === "succeeded",
        amountKobo: contribution.amountKobo,
        currency: CURRENCY,
        createdAt: Timestamp.fromDate(nowFrom(clock)),
      });
    });
  }

  async function runDueContributions({ asOf = nowFrom(clock), limit = 100 } = {}) {
    const duePlans = await listDuePlans({ asOf, limit });
    const results = [];
    for (const plan of duePlans) {
      results.push(await processDueContribution({
        planId: plan.planId,
        scheduledFor: plan.nextContributionDate,
      }));
    }
    return results;
  }

  return {
    createPlan,
    getPlan,
    updatePlan,
    pausePlan,
    resumePlan,
    cancelPlan,
    listDuePlans,
    processDueContribution,
    runDueContributions,
  };
}

function calculateNextContributionDate({ startDate, frequency, after }) {
  const start = requireDate(startDate, "startDate");
  const reference = requireDate(after, "after");
  requireFrequency(frequency);
  if (start.getTime() >= reference.getTime()) return new Date(start.getTime());

  if (frequency === "daily" || frequency === "weekly") {
    const interval = frequency === "daily" ? 86400000 : 604800000;
    const elapsed = reference.getTime() - start.getTime();
    const steps = Math.ceil(elapsed / interval);
    const candidate = new Date(start.getTime() + steps * interval);
    return candidate.getTime() < reference.getTime()
      ? new Date(candidate.getTime() + interval)
      : candidate;
  }

  let months = (reference.getUTCFullYear() - start.getUTCFullYear()) * 12 +
    reference.getUTCMonth() - start.getUTCMonth();
  let candidate = addUtcMonthsClamped(start, Math.max(0, months));
  if (candidate.getTime() < reference.getTime()) {
    candidate = addUtcMonthsClamped(start, Math.max(0, months) + 1);
  }
  return candidate;
}

function addUtcMonthsClamped(start, months) {
  const targetMonth = start.getUTCMonth() + months;
  const year = start.getUTCFullYear() + Math.floor(targetMonth / 12);
  const month = ((targetMonth % 12) + 12) % 12;
  const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  return new Date(Date.UTC(
    year,
    month,
    Math.min(start.getUTCDate(), lastDay),
    start.getUTCHours(),
    start.getUTCMinutes(),
    start.getUTCSeconds(),
    start.getUTCMilliseconds(),
  ));
}

function contributionOutcome(verification) {
  if (verification.status === PAYMENT_STATUS.SUCCEEDED) {
    return {
      status: "succeeded",
      ledgerOperationId: verification.ledgerOperationId,
      failureCode: null,
    };
  }
  if (verification.status === PAYMENT_STATUS.PENDING ||
      verification.status === PAYMENT_STATUS.CREATED) {
    return { status: "pending", ledgerOperationId: null, failureCode: null };
  }
  return {
    status: "failed",
    ledgerOperationId: verification.ledgerOperationId || null,
    failureCode: verification.failureCode || verification.status,
  };
}

function planResult(planId, plan) {
  if (!PLAN_STATUSES.has(plan.status)) {
    throw new SavingsPlanError("integrity-error", "Savings plan status is invalid.");
  }
  return {
    planId,
    userId: plan.userId,
    personalHealthPocketId: plan.personalHealthPocketId,
    contributionAmountKobo: plan.contributionAmountKobo,
    currency: CURRENCY,
    frequency: plan.frequency,
    startDate: plan.startDate.toDate(),
    nextContributionDate: plan.nextContributionDate?.toDate() || null,
    status: plan.status,
    fundingSourceId: plan.fundingSourceId ?? null,
  };
}

function scheduledContributionResult(contributionId, contribution) {
  if (!CONTRIBUTION_STATUSES.has(contribution.status)) {
    throw new SavingsPlanError(
      "integrity-error",
      "Scheduled contribution status is invalid.",
    );
  }
  return {
    contributionId,
    userId: contribution.userId,
    savingsPlanId: contribution.savingsPlanId,
    scheduledFor: contribution.scheduledFor.toDate(),
    amountKobo: contribution.amountKobo,
    currency: contribution.currency,
    status: contribution.status,
    paymentAttemptId: contribution.paymentAttemptId ?? null,
    providerReference: contribution.providerReference ?? null,
    ledgerOperationId: contribution.ledgerOperationId ?? null,
    failureCode: contribution.failureCode ?? null,
  };
}

function requireMutablePlan(plan) {
  if (!plan || !PLAN_STATUSES.has(plan.status)) {
    throw new SavingsPlanError("integrity-error", "Savings plan data is invalid.");
  }
  if (plan.status === "cancelled") {
    throw new SavingsPlanError(
      "plan-cancelled",
      "A cancelled savings plan cannot be changed or resumed.",
    );
  }
}

function planIdFor(userId) {
  return `personal-plan-${userId}`;
}

function pocketIdFor(userId) {
  return `personal-${userId}`;
}

function operationIdFor(userId, idempotencyKey) {
  return `savingsop_${hash({ userId, idempotencyKey }).slice(0, 48)}`;
}

function scheduledContributionIdFor(planId, scheduledFor) {
  return `scheduled_${hash({ planId, scheduledFor: scheduledFor.toISOString() }).slice(0, 48)}`;
}

function requireUserId(value) {
  if (typeof value !== "string" || !USER_ID.test(value)) {
    throw new SavingsPlanError("invalid-argument", "userId is invalid.");
  }
  return value;
}

function requireSafeId(value, name) {
  if (typeof value !== "string" || !SAFE_ID.test(value)) {
    throw new SavingsPlanError("invalid-argument", `${name} is invalid.`);
  }
}

function requireRequestKey(value) {
  if (typeof value !== "string" || !REQUEST_KEY.test(value)) {
    throw new SavingsPlanError("invalid-argument", "Idempotency key is invalid.");
  }
}

function requireAmount(value) {
  if (!Number.isSafeInteger(value) || value <= 0 || value > MAX_AMOUNT_KOBO) {
    throw new SavingsPlanError(
      "invalid-amount",
      "Contribution amount must be positive integer kobo.",
    );
  }
}

function requireFrequency(value) {
  if (!FREQUENCIES.has(value)) {
    throw new SavingsPlanError("invalid-argument", "Savings frequency is invalid.");
  }
}

function requireDate(value, name) {
  if (!(value instanceof Date) || !Number.isFinite(value.getTime())) {
    throw new SavingsPlanError("invalid-argument", `${name} is invalid.`);
  }
  return new Date(value.getTime());
}

function optionalBoundedString(value, name, maximum) {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string" || value.length < 1 || value.length > maximum) {
    throw new SavingsPlanError("invalid-argument", `${name} is invalid.`);
  }
  return value;
}

function nowFrom(clock) {
  return requireDate(clock(), "clock");
}

function hash(value) {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function log(logger, operation, outcome) {
  logger.info("healthpocket_backend", {
    component: "savings",
    operation,
    outcome,
  });
}

module.exports = {
  buildSavingsPlanService,
  calculateNextContributionDate,
  SavingsPlanError,
  DEFAULT_CONTRIBUTION_AMOUNT_KOBO,
};
