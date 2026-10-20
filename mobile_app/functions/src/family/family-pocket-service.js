"use strict";

const { createHash, randomBytes } = require("node:crypto");
const { FieldPath, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { PaymentGatewayError, PAYMENT_STATUS } = require("../payments/payment-gateway");
const { notificationDocument } = require("../notifications/notification-model");

const CURRENCY = "NGN";
const SAFE_ID = /^[A-Za-z0-9_-]{1,256}$/;
const REQUEST_KEY = /^[A-Za-z0-9_-]{16,80}$/;
const IMAGE_OBJECT_NAME = /^[A-Fa-f0-9]{32}\.(?:jpg|png|webp)$/;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const FREQUENCIES = new Set(["daily", "weekly", "monthly"]);
const ROLES = new Set(["owner", "admin", "member"]);
const MIN_CONTRIBUTION_KOBO = 50000;
const MAX_CONTRIBUTION_KOBO = 100000000;
const INVITE_LIFETIME_DAYS = 7;

class FamilyPocketError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "FamilyPocketError";
    this.code = code;
  }
}

function buildFamilyPocketService({ db, gateway, logger = console }) {
  if (!db || typeof db.runTransaction !== "function") {
    throw new TypeError("A Firestore Admin database is required.");
  }
  if (!gateway || typeof gateway.initializeFunding !== "function" ||
      typeof gateway.verifyFunding !== "function") {
    throw new TypeError("A payment gateway adapter is required.");
  }

  const pockets = db.collection("family_pockets");
  const inviteKeys = db.collection("family_invite_keys");
  const inviteCodes = db.collection("family_invite_codes");
  const attempts = db.collection("family_contribution_attempts");
  const ledgerEntries = db.collection("family_ledger_entries");
  const activities = db.collection("activities");
  const notifications = db.collection("notification_events");

  async function createPocket(input) {
    const value = normalizePocket(input);
    const pocketId = `family_${hash({ ownerId: value.ownerId, key: value.idempotencyKey }).slice(0, 48)}`;
    requireFamilyImagePath(value.imagePath, pocketId);
    const pocketRef = pockets.doc(pocketId);
    const ownerRef = pocketRef.collection("members").doc(value.ownerId);
    await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(pocketRef);
      if (existing.exists) {
        assertPocketRequest(existing.data(), value);
        return;
      }
      const now = Timestamp.now();
      transaction.create(pocketRef, {
        schemaVersion: 2,
        name: value.name,
        description: value.description,
        imagePath: value.imagePath,
        frequency: value.frequency,
        defaultContributionAmountKobo: value.defaultContributionAmountKobo,
        ownerId: value.ownerId,
        createdBy: value.ownerId,
        currency: CURRENCY,
        status: "active",
        balanceKobo: 0,
        version: 0,
        requestFingerprint: hash(value),
        createdAt: now,
        updatedAt: now,
        closedAt: null,
      });
      transaction.create(ownerRef, membershipDocument({
        pocketId,
        userId: value.ownerId,
        name: value.ownerName,
        role: "owner",
        canContribute: true,
        now,
      }));
    });
    log(logger, "create_pocket", "success");
    return { pocketId };
  }

  async function updatePocket({ actorId, pocketId, ...changes }) {
    requireSafeId(actorId, "actorId");
    requireSafeId(pocketId, "pocketId");
    const patch = normalizePocketChanges(changes, pocketId);
    await db.runTransaction(async (transaction) => {
      const pocketRef = pockets.doc(pocketId);
      const [pocket, actor] = await Promise.all([
        transaction.get(pocketRef),
        transaction.get(pocketRef.collection("members").doc(actorId)),
      ]);
      requireActivePocket(pocket);
      requireRole(actor, ["owner", "admin"]);
      transaction.update(pocketRef, { ...patch, updatedAt: Timestamp.now() });
    });
    return { pocketId };
  }

  async function createInvite(input) {
    const value = normalizeInvite(input);
    const pocketRef = pockets.doc(value.pocketId);
    const uniquenessId = hash({ pocketId: value.pocketId, email: value.email });
    const uniquenessRef = inviteKeys.doc(uniquenessId);
    const rawCode = randomBytes(32).toString("base64url");
    const codeHash = hash(rawCode);
    const inviteId = `invite_${hash({
      pocketId: value.pocketId,
      email: value.email,
      key: value.idempotencyKey,
    }).slice(0, 48)}`;
    const inviteRef = pocketRef.collection("invites").doc(inviteId);
    const codeRef = inviteCodes.doc(codeHash);

    await db.runTransaction(async (transaction) => {
      const [pocket, actor, duplicate, existingInvite] = await Promise.all([
        transaction.get(pocketRef),
        transaction.get(pocketRef.collection("members").doc(value.actorId)),
        transaction.get(uniquenessRef),
        transaction.get(inviteRef),
      ]);
      requireActivePocket(pocket);
      requireRole(actor, ["owner", "admin"]);
      if (existingInvite.exists) {
        assertInviteRequest(existingInvite.data(), value);
        throw new FamilyPocketError(
          "invite-already-created",
          "This invitation was already created; use its original link.",
        );
      }
      if (duplicate.exists && duplicate.data().status === "pending") {
        throw new FamilyPocketError(
          "duplicate-invite",
          "This email already has a pending invitation.",
        );
      }
      const now = Timestamp.now();
      const expiresAt = Timestamp.fromMillis(
        now.toMillis() + INVITE_LIFETIME_DAYS * 24 * 60 * 60 * 1000,
      );
      transaction.create(inviteRef, {
        schemaVersion: 2,
        pocketId: value.pocketId,
        pocketName: pocket.data().name,
        inviteeName: value.inviteeName,
        email: value.email,
        role: value.role,
        permissions: permissionsFor(value.role, value.canContribute),
        status: "pending",
        createdBy: value.actorId,
        codeHash,
        requestFingerprint: hash(value),
        createdAt: now,
        expiresAt,
        respondedBy: null,
        respondedAt: null,
      });
      transaction.set(uniquenessRef, {
        pocketId: value.pocketId,
        inviteId,
        emailHash: hash(value.email),
        status: "pending",
        updatedAt: now,
      });
      transaction.create(codeRef, {
        pocketId: value.pocketId,
        inviteId,
        expiresAt,
        createdAt: now,
      });
    });
    log(logger, "create_invite", "success");
    return { inviteId, code: rawCode };
  }

  async function resolveInviteCode({ code }) {
    const codeHash = hashInviteCode(code);
    const mapping = await inviteCodes.doc(codeHash).get();
    if (!mapping.exists) throw notFoundInvite();
    const value = mapping.data();
    const invite = await pockets.doc(value.pocketId)
      .collection("invites").doc(value.inviteId).get();
    if (!invite.exists || invite.data().status !== "pending" ||
        invite.data().expiresAt.toMillis() <= Date.now()) {
      throw notFoundInvite();
    }
    return {
      pocketName: invite.data().pocketName,
      inviteeName: invite.data().inviteeName,
      expiresAt: invite.data().expiresAt,
    };
  }

  async function respondToInvite({ code, userId, userName, email, emailVerified, accept }) {
    requireSafeId(userId, "userId");
    requireBoundedString(userName, "userName", 100);
    const normalizedEmail = normalizeEmail(email);
    if (emailVerified !== true) {
      throw new FamilyPocketError("email-not-verified", "A verified email is required.");
    }
    if (typeof accept !== "boolean") {
      throw new FamilyPocketError("invalid-argument", "Invite response is invalid.");
    }
    const codeHash = hashInviteCode(code);
    const codeRef = inviteCodes.doc(codeHash);
    let response;
    await db.runTransaction(async (transaction) => {
      const mapping = await transaction.get(codeRef);
      if (!mapping.exists) throw notFoundInvite();
      const { pocketId, inviteId } = mapping.data();
      const pocketRef = pockets.doc(pocketId);
      const inviteRef = pocketRef.collection("invites").doc(inviteId);
      const memberRef = pocketRef.collection("members").doc(userId);
      const [pocket, invite, member] = await Promise.all([
        transaction.get(pocketRef),
        transaction.get(inviteRef),
        transaction.get(memberRef),
      ]);
      if (!invite.exists || invite.data().status !== "pending") throw notFoundInvite();
      const inviteData = invite.data();
      if (inviteData.email !== normalizedEmail) {
        throw new FamilyPocketError("permission-denied", "This invitation belongs to another account.");
      }
      const now = Timestamp.now();
      if (inviteData.expiresAt.toMillis() <= now.toMillis()) {
        transaction.update(inviteRef, { status: "expired", respondedAt: now });
        transaction.update(inviteKeys.doc(hash({ pocketId, email: normalizedEmail })), {
          status: "expired", updatedAt: now,
        });
        transaction.delete(codeRef);
        response = { status: "expired", pocketId };
        return;
      }
      if (accept) requireActivePocket(pocket);
      if (accept && member.exists && member.data().status === "active") {
        throw new FamilyPocketError("already-member", "This account is already a member.");
      }
      const status = accept ? "accepted" : "declined";
      transaction.update(inviteRef, {
        status,
        respondedBy: userId,
        respondedAt: now,
      });
      transaction.update(inviteKeys.doc(hash({ pocketId, email: normalizedEmail })), {
        status, updatedAt: now,
      });
      transaction.delete(codeRef);
      if (accept) {
        transaction.set(memberRef, membershipDocument({
          pocketId,
          userId,
          name: userName,
          role: inviteData.role,
          canContribute: inviteData.permissions.canContribute,
          invitationId: inviteId,
          now,
        }));
      }
      response = { status, pocketId };
    });
    log(logger, "respond_invite", response.status);
    return response;
  }

  async function changeMembership({ actorId, pocketId, memberId, action }) {
    requireSafeId(actorId, "actorId");
    requireSafeId(pocketId, "pocketId");
    requireSafeId(memberId, "memberId");
    if (!new Set(["leave", "remove"]).has(action)) {
      throw new FamilyPocketError("invalid-argument", "Membership action is invalid.");
    }
    await db.runTransaction(async (transaction) => {
      const pocketRef = pockets.doc(pocketId);
      const actorRef = pocketRef.collection("members").doc(actorId);
      const memberRef = pocketRef.collection("members").doc(memberId);
      const [pocket, actor, member] = await Promise.all([
        transaction.get(pocketRef), transaction.get(actorRef), transaction.get(memberRef),
      ]);
      requireActivePocket(pocket);
      requireActiveMembership(member);
      const actorData = requireActiveMembership(actor);
      const target = member.data();
      if (target.role === "owner") {
        throw new FamilyPocketError(
          "owner-transfer-required",
          "Transfer ownership or close the pocket before the owner leaves.",
        );
      }
      if (action === "leave") {
        if (actorId !== memberId) throw permissionDenied();
      } else {
        if (actorId === memberId) {
          throw new FamilyPocketError("invalid-argument", "Use leave for your own membership.");
        }
        if (actorData.role === "member" ||
            (actorData.role === "admin" && target.role !== "member")) {
          throw permissionDenied();
        }
      }
      const now = Timestamp.now();
      transaction.update(memberRef, {
        status: action === "leave" ? "left" : "removed",
        [action === "leave" ? "leftAt" : "removedAt"]: now,
        updatedAt: now,
      });
    });
    return { status: action === "leave" ? "left" : "removed" };
  }

  async function transferOwnership({ ownerId, pocketId, newOwnerId }) {
    requireSafeId(ownerId, "ownerId");
    requireSafeId(pocketId, "pocketId");
    requireSafeId(newOwnerId, "newOwnerId");
    if (ownerId === newOwnerId) return { pocketId, ownerId };
    await db.runTransaction(async (transaction) => {
      const pocketRef = pockets.doc(pocketId);
      const currentRef = pocketRef.collection("members").doc(ownerId);
      const nextRef = pocketRef.collection("members").doc(newOwnerId);
      const [pocket, current, next] = await Promise.all([
        transaction.get(pocketRef), transaction.get(currentRef), transaction.get(nextRef),
      ]);
      requireActivePocket(pocket);
      if (pocket.data().ownerId !== ownerId || requireActiveMembership(current).role !== "owner") {
        throw permissionDenied();
      }
      requireActiveMembership(next);
      const now = Timestamp.now();
      transaction.update(currentRef, {
        role: "admin", permissions: permissionsFor("admin", true), updatedAt: now,
      });
      transaction.update(nextRef, {
        role: "owner", permissions: permissionsFor("owner", true), updatedAt: now,
      });
      transaction.update(pocketRef, { ownerId: newOwnerId, updatedAt: now });
    });
    return { pocketId, ownerId: newOwnerId };
  }

  async function closePocket({ ownerId, pocketId }) {
    requireSafeId(ownerId, "ownerId");
    requireSafeId(pocketId, "pocketId");
    await db.runTransaction(async (transaction) => {
      const pocketRef = pockets.doc(pocketId);
      const pocket = await transaction.get(pocketRef);
      requireActivePocket(pocket);
      if (pocket.data().ownerId !== ownerId) throw permissionDenied();
      const now = Timestamp.now();
      transaction.update(pocketRef, { status: "closed", closedAt: now, updatedAt: now });
    });
    return { pocketId, status: "closed" };
  }

  async function initializeContribution(input) {
    const value = normalizeContribution(input);
    const pocketRef = pockets.doc(value.pocketId);
    const attemptId = `family_pay_${hash({
      pocketId: value.pocketId,
      userId: value.userId,
      key: value.idempotencyKey,
    }).slice(0, 48)}`;
    const attemptRef = attempts.doc(attemptId);
    const fingerprint = hash(value);
    const existing = await db.runTransaction(async (transaction) => {
      const [pocket, member, attempt] = await Promise.all([
        transaction.get(pocketRef),
        transaction.get(pocketRef.collection("members").doc(value.userId)),
        transaction.get(attemptRef),
      ]);
      requireActivePocket(pocket);
      const memberData = requireActiveMembership(member);
      if (!memberData.permissions.canContribute) throw permissionDenied();
      if (attempt.exists) {
        if (attempt.data().requestFingerprint !== fingerprint) {
          throw new FamilyPocketError("idempotency-conflict", "Request key was reused.");
        }
        return attempt.data();
      }
      const now = Timestamp.now();
      transaction.create(attemptRef, {
        schemaVersion: 1,
        pocketId: value.pocketId,
        contributorUserId: value.userId,
        amountKobo: value.amountKobo,
        currency: CURRENCY,
        status: "created",
        provider: gateway.name,
        providerReference: null,
        requestFingerprint: fingerprint,
        createdAt: now,
        updatedAt: now,
        completedAt: null,
        failureCode: null,
      });
      return null;
    });
    if (existing && existing.status !== "created") return contributionResult(attemptId, existing);

    let provider;
    try {
      provider = await gateway.initializeFunding({
        requestId: attemptId,
        userId: value.userId,
        amountKobo: value.amountKobo,
        currency: CURRENCY,
      });
    } catch (error) {
      if (error instanceof PaymentGatewayError && error.code === "provider-timeout") {
        await attemptRef.update({
          status: "timed_out", failureCode: "provider-timeout", updatedAt: Timestamp.now(),
        });
        return contributionResult(attemptId, (await attemptRef.get()).data());
      }
      throw error;
    }
    const status = provider.status === PAYMENT_STATUS.FAILED ? "failed" : "pending";
    await attemptRef.update({
      status,
      providerReference: provider.providerReference || null,
      failureCode: status === "failed" ? "provider-failed" : null,
      updatedAt: Timestamp.now(),
    });
    return contributionResult(attemptId, (await attemptRef.get()).data());
  }

  async function verifyContribution({ attemptId }) {
    requireSafeId(attemptId, "attemptId");
    const attemptRef = attempts.doc(attemptId);
    const snapshot = await attemptRef.get();
    if (!snapshot.exists) throw new FamilyPocketError("not-found", "Contribution was not found.");
    const attempt = snapshot.data();
    if (attempt.status === "completed") return contributionResult(attemptId, attempt);
    if (!attempt.providerReference) {
      throw new FamilyPocketError("not-verifiable", "Contribution has no provider reference.");
    }
    let result;
    try {
      result = await gateway.verifyFunding({
        requestId: attemptId,
        providerReference: attempt.providerReference,
      });
    } catch (error) {
      if (error instanceof PaymentGatewayError && error.code === "provider-timeout") {
        await attemptRef.update({
          status: "timed_out", failureCode: "provider-timeout", updatedAt: Timestamp.now(),
        });
        return contributionResult(attemptId, (await attemptRef.get()).data());
      }
      throw error;
    }
    if (result.status !== PAYMENT_STATUS.SUCCEEDED) {
      const status = result.status === PAYMENT_STATUS.FAILED ? "failed" : "pending";
      await attemptRef.update({
        status, failureCode: status === "failed" ? "provider-failed" : null,
        updatedAt: Timestamp.now(),
      });
      return contributionResult(attemptId, (await attemptRef.get()).data());
    }
    return completeContribution(attemptId);
  }

  async function completeContribution(attemptId) {
    const attemptRef = attempts.doc(attemptId);
    const ledgerRef = ledgerEntries.doc(`family_entry_${hash(attemptId).slice(0, 48)}`);
    const activityRef = activities.doc(`family_activity_${hash(attemptId).slice(0, 48)}`);
    const notificationRef = notifications.doc(`family_notice_${hash(attemptId).slice(0, 48)}`);
    let result;
    await db.runTransaction(async (transaction) => {
      const attempt = await transaction.get(attemptRef);
      if (!attempt.exists) throw new FamilyPocketError("not-found", "Contribution was not found.");
      const data = attempt.data();
      if (data.status === "completed") {
        result = contributionResult(attemptId, data);
        return;
      }
      const pocketRef = pockets.doc(data.pocketId);
      const memberRef = pocketRef.collection("members").doc(data.contributorUserId);
      const [pocket, member, existingLedger] = await Promise.all([
        transaction.get(pocketRef), transaction.get(memberRef), transaction.get(ledgerRef),
      ]);
      requireActivePocket(pocket);
      requireActiveMembership(member);
      if (existingLedger.exists) {
        throw new FamilyPocketError("integrity-error", "Contribution ledger already exists.");
      }
      const now = Timestamp.now();
      transaction.create(ledgerRef, {
        schemaVersion: 1,
        familyPocketId: data.pocketId,
        contributorUserId: data.contributorUserId,
        contributionAttemptId: attemptId,
        direction: "credit",
        amountKobo: data.amountKobo,
        currency: CURRENCY,
        status: "completed",
        providerReference: data.providerReference,
        createdAt: now,
      });
      transaction.update(pocketRef, {
        balanceKobo: FieldValue.increment(data.amountKobo),
        version: FieldValue.increment(1),
        updatedAt: now,
      });
      transaction.update(memberRef, {
        lifetimeContributionKobo: FieldValue.increment(data.amountKobo),
        updatedAt: now,
      });
      transaction.update(attemptRef, {
        status: "completed", ledgerEntryId: ledgerRef.id,
        completedAt: now, failureCode: null, updatedAt: now,
      });
      transaction.create(activityRef, {
        userId: data.contributorUserId,
        familyPocketId: data.pocketId,
        activityType: "family_contribution_completed",
        relatedEntityType: "family_contribution",
        relatedEntityId: attemptId,
        metadata: { amountKobo: data.amountKobo, currency: CURRENCY },
        createdAt: now,
      });
      transaction.create(notificationRef, notificationDocument({
        userId: data.contributorUserId,
        familyPocketId: data.pocketId,
        type: "family_contribution_completed",
        category: "family_pocket",
        title: "Family Pocket contribution received",
        body: "Your Family Pocket balance has been updated.",
        relatedEntityType: "family_contribution",
        relatedEntityId: attemptId,
        now,
      }));
      result = { ...contributionResult(attemptId, data), status: "completed", ledgerEntryId: ledgerRef.id };
    });
    log(logger, "complete_contribution", "success");
    return result;
  }

  async function reconcilePocket(pocketId) {
    requireSafeId(pocketId, "pocketId");
    const pocket = await pockets.doc(pocketId).get();
    if (!pocket.exists) throw new FamilyPocketError("not-found", "Pocket was not found.");
    let expectedBalanceKobo = 0;
    let entryCount = 0;
    let cursor = null;
    do {
      let query = ledgerEntries.where("familyPocketId", "==", pocketId)
        .where("status", "==", "completed")
        .orderBy("createdAt", "asc")
        .orderBy(FieldPath.documentId(), "asc")
        .limit(500);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      for (const entry of page.docs) expectedBalanceKobo += entry.data().amountKobo;
      entryCount += page.size;
      cursor = page.size === 500 ? page.docs.at(-1) : null;
    } while (cursor);
    return {
      matches: expectedBalanceKobo === pocket.data().balanceKobo,
      expectedBalanceKobo,
      actualBalanceKobo: pocket.data().balanceKobo,
      entryCount,
    };
  }

  return {
    createPocket,
    updatePocket,
    createInvite,
    resolveInviteCode,
    respondToInvite,
    changeMembership,
    transferOwnership,
    closePocket,
    initializeContribution,
    verifyContribution,
    reconcilePocket,
  };
}

function normalizePocket(input) {
  if (!input || typeof input !== "object") invalid("Pocket input is required.");
  requireSafeId(input.ownerId, "ownerId");
  requireRequestKey(input.idempotencyKey);
  requireBoundedString(input.ownerName, "ownerName", 100);
  requireBoundedString(input.name, "name", 100);
  const description = optionalBoundedString(input.description, "description", 500);
  const imagePath = optionalBoundedString(input.imagePath, "imagePath", 500);
  requireFrequency(input.frequency);
  requireAmount(input.defaultContributionAmountKobo);
  return {
    ownerId: input.ownerId,
    ownerName: input.ownerName.trim(),
    idempotencyKey: input.idempotencyKey,
    name: input.name.trim(),
    description,
    imagePath,
    frequency: input.frequency,
    defaultContributionAmountKobo: input.defaultContributionAmountKobo,
  };
}

function normalizePocketChanges(input, pocketId) {
  const result = {};
  if (Object.hasOwn(input, "name")) {
    requireBoundedString(input.name, "name", 100);
    result.name = input.name.trim();
  }
  if (Object.hasOwn(input, "description")) {
    result.description = optionalBoundedString(input.description, "description", 500);
  }
  if (Object.hasOwn(input, "imagePath")) {
    result.imagePath = optionalBoundedString(input.imagePath, "imagePath", 500);
    requireFamilyImagePath(result.imagePath, pocketId);
  }
  if (Object.hasOwn(input, "frequency")) {
    requireFrequency(input.frequency);
    result.frequency = input.frequency;
  }
  if (Object.hasOwn(input, "defaultContributionAmountKobo")) {
    requireAmount(input.defaultContributionAmountKobo);
    result.defaultContributionAmountKobo = input.defaultContributionAmountKobo;
  }
  if (Object.keys(result).length === 0) invalid("No supported changes were supplied.");
  return result;
}

function requireFamilyImagePath(imagePath, pocketId) {
  if (imagePath === null) return;
  const prefix = `family_pockets/${pocketId}/profile/`;
  const objectName = imagePath.startsWith(prefix)
    ? imagePath.slice(prefix.length)
    : "";
  if (!IMAGE_OBJECT_NAME.test(objectName)) {
    invalid("imagePath must reference this Family Pocket's protected image area.");
  }
}

function normalizeInvite(input) {
  if (!input || typeof input !== "object") invalid("Invite input is required.");
  requireSafeId(input.actorId, "actorId");
  requireSafeId(input.pocketId, "pocketId");
  requireRequestKey(input.idempotencyKey);
  requireBoundedString(input.inviteeName, "inviteeName", 100);
  const email = normalizeEmail(input.email);
  const role = input.role || "member";
  if (!new Set(["admin", "member"]).has(role)) invalid("Invite role is invalid.");
  return {
    actorId: input.actorId,
    pocketId: input.pocketId,
    idempotencyKey: input.idempotencyKey,
    inviteeName: input.inviteeName.trim(),
    email,
    role,
    canContribute: input.canContribute !== false,
  };
}

function normalizeContribution(input) {
  if (!input || typeof input !== "object") invalid("Contribution input is required.");
  requireSafeId(input.userId, "userId");
  requireSafeId(input.pocketId, "pocketId");
  requireRequestKey(input.idempotencyKey);
  requireAmount(input.amountKobo);
  return {
    userId: input.userId,
    pocketId: input.pocketId,
    idempotencyKey: input.idempotencyKey,
    amountKobo: input.amountKobo,
  };
}

function membershipDocument({ pocketId, userId, name, role, canContribute, invitationId = null, now }) {
  if (!ROLES.has(role)) invalid("Membership role is invalid.");
  return {
    schemaVersion: 2,
    pocketId,
    userId,
    invitationId,
    name,
    role,
    permissions: permissionsFor(role, canContribute),
    status: "active",
    lifetimeContributionKobo: 0,
    joinedAt: now,
    updatedAt: now,
    leftAt: null,
    removedAt: null,
  };
}

function permissionsFor(role, canContribute) {
  return {
    canContribute: role === "owner" || canContribute === true,
    canInvite: role === "owner" || role === "admin",
    canManageMembers: role === "owner" || role === "admin",
  };
}

function requireActivePocket(snapshot) {
  if (!snapshot.exists) throw new FamilyPocketError("not-found", "Pocket was not found.");
  if (snapshot.data().status !== "active") {
    throw new FamilyPocketError("pocket-closed", "Pocket is not active.");
  }
  return snapshot.data();
}

function requireActiveMembership(snapshot) {
  if (!snapshot.exists || snapshot.data().status !== "active") throw permissionDenied();
  return snapshot.data();
}

function requireRole(snapshot, allowed) {
  const member = requireActiveMembership(snapshot);
  if (!allowed.includes(member.role)) throw permissionDenied();
  return member;
}

function assertPocketRequest(existing, input) {
  if (existing.requestFingerprint !== hash(input)) {
    throw new FamilyPocketError("idempotency-conflict", "Request key was reused.");
  }
}

function assertInviteRequest(existing, input) {
  if (existing.requestFingerprint !== hash(input)) {
    throw new FamilyPocketError("idempotency-conflict", "Request key was reused.");
  }
}

function contributionResult(attemptId, data) {
  return {
    attemptId,
    status: data.status,
    providerReference: data.providerReference || null,
    ledgerEntryId: data.ledgerEntryId || null,
    failureCode: data.failureCode || null,
  };
}

function hashInviteCode(code) {
  if (typeof code !== "string" || !/^[A-Za-z0-9_-]{40,100}$/.test(code)) throw notFoundInvite();
  return hash(code);
}

function notFoundInvite() {
  return new FamilyPocketError("invite-not-found", "Invitation is invalid or expired.");
}

function permissionDenied() {
  return new FamilyPocketError("permission-denied", "This action is not permitted.");
}

function invalid(message) {
  throw new FamilyPocketError("invalid-argument", message);
}

function normalizeEmail(value) {
  if (typeof value !== "string") invalid("Email is invalid.");
  const email = value.trim().toLowerCase();
  if (email.length > 254 || !EMAIL.test(email)) invalid("Email is invalid.");
  return email;
}

function requireFrequency(value) {
  if (!FREQUENCIES.has(value)) invalid("Frequency is invalid.");
}

function requireAmount(value) {
  if (!Number.isSafeInteger(value) || value < MIN_CONTRIBUTION_KOBO ||
      value > MAX_CONTRIBUTION_KOBO) {
    throw new FamilyPocketError(
      "invalid-amount",
      `Contribution must be between ${MIN_CONTRIBUTION_KOBO} and ${MAX_CONTRIBUTION_KOBO} kobo.`,
    );
  }
}

function requireSafeId(value, name) {
  if (typeof value !== "string" || !SAFE_ID.test(value)) invalid(`${name} is invalid.`);
}

function requireRequestKey(value) {
  if (typeof value !== "string" || !REQUEST_KEY.test(value)) invalid("Idempotency key is invalid.");
}

function requireBoundedString(value, name, maximum) {
  if (typeof value !== "string" || value.trim().length < 1 || value.length > maximum) {
    invalid(`${name} is invalid.`);
  }
}

function optionalBoundedString(value, name, maximum) {
  if (value === undefined || value === null || value === "") return null;
  requireBoundedString(value, name, maximum);
  return value.trim();
}

function hash(value) {
  const encoded = typeof value === "string" ? value : JSON.stringify(value);
  return createHash("sha256").update(encoded).digest("hex");
}

function log(logger, operation, outcome) {
  logger.info("healthpocket_backend", {
    component: "family_pocket",
    operation,
    outcome,
  });
}

module.exports = {
  buildFamilyPocketService,
  FamilyPocketError,
  MIN_CONTRIBUTION_KOBO,
  MAX_CONTRIBUTION_KOBO,
};
