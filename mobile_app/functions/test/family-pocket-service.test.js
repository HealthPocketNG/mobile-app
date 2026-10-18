"use strict";

const { after, before, beforeEach, test } = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const {
  buildFamilyPocketService,
} = require("../src/family/family-pocket-service");
const { MockPaymentGateway } = require("../src/payments/mock-payment-gateway");

let app;
let db;
let gateway;
let family;
const silentLogger = { info() {} };

before(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("Run these tests through the Firebase Firestore emulator.");
  }
  app = initializeApp({ projectId: "demo-healthpocket" }, "family-pocket-tests");
  db = getFirestore(app);
});

beforeEach(async () => {
  await Promise.all([
    db.recursiveDelete(db.collection("family_pockets")),
    db.recursiveDelete(db.collection("family_invite_keys")),
    db.recursiveDelete(db.collection("family_invite_codes")),
    db.recursiveDelete(db.collection("family_contribution_attempts")),
    db.recursiveDelete(db.collection("family_ledger_entries")),
    db.recursiveDelete(db.collection("activities")),
    db.recursiveDelete(db.collection("notification_events")),
  ]);
  gateway = new MockPaymentGateway();
  family = buildFamilyPocketService({ db, gateway, logger: silentLogger });
});

after(async () => deleteApp(app));

async function createPocket({ ownerId = "owner-1", key = "createpocket00001" } = {}) {
  return family.createPocket({
    ownerId,
    ownerName: "Amara Owner",
    idempotencyKey: key,
    name: "Okafor Family Care",
    description: "Shared family healthcare savings",
    imagePath: null,
    frequency: "monthly",
    defaultContributionAmountKobo: 50000,
  });
}

async function inviteAndAccept({ pocketId, actorId = "owner-1", userId, email, role = "member" }) {
  const invite = await family.createInvite({
    actorId,
    pocketId,
    idempotencyKey: `invite${userId}0000000000`.slice(0, 24),
    inviteeName: `Member ${userId}`,
    email,
    role,
    canContribute: true,
  });
  await family.respondToInvite({
    code: invite.code,
    userId,
    userName: `Member ${userId}`,
    email,
    emailVerified: true,
    accept: true,
  });
}

test("creates a complete Family Pocket and founding owner idempotently", async () => {
  const first = await createPocket();
  const retry = await createPocket();
  assert.equal(retry.pocketId, first.pocketId);

  const pocket = await db.collection("family_pockets").doc(first.pocketId).get();
  const owner = await pocket.ref.collection("members").doc("owner-1").get();
  assert.deepEqual(
    {
      name: pocket.data().name,
      description: pocket.data().description,
      imagePath: pocket.data().imagePath,
      frequency: pocket.data().frequency,
      defaultContributionAmountKobo: pocket.data().defaultContributionAmountKobo,
      ownerId: pocket.data().ownerId,
      status: pocket.data().status,
      balanceKobo: pocket.data().balanceKobo,
    },
    {
      name: "Okafor Family Care",
      description: "Shared family healthcare savings",
      imagePath: null,
      frequency: "monthly",
      defaultContributionAmountKobo: 50000,
      ownerId: "owner-1",
      status: "active",
      balanceKobo: 0,
    },
  );
  assert.equal(owner.data().role, "owner");
  assert.deepEqual(owner.data().permissions, {
    canContribute: true,
    canInvite: true,
    canManageMembers: true,
  });
});

test("validates pocket contribution defaults and editable scheduling centrally", async () => {
  await assert.rejects(
    family.createPocket({
      ownerId: "owner-1",
      ownerName: "Amara",
      idempotencyKey: "badamountpocket01",
      name: "Invalid",
      frequency: "weekly",
      defaultContributionAmountKobo: 49999,
    }),
    (error) => error.code === "invalid-amount",
  );
  const { pocketId } = await createPocket();
  await family.updatePocket({
    actorId: "owner-1",
    pocketId,
    frequency: "weekly",
    defaultContributionAmountKobo: 75000,
    description: "Updated",
  });
  const pocket = (await db.collection("family_pockets").doc(pocketId).get()).data();
  assert.equal(pocket.frequency, "weekly");
  assert.equal(pocket.defaultContributionAmountKobo, 75000);
});

test("uses opaque invite codes, blocks duplicates and verifies invite ownership", async () => {
  const { pocketId } = await createPocket();
  const invite = await family.createInvite({
    actorId: "owner-1",
    pocketId,
    idempotencyKey: "firstinvite000001",
    inviteeName: "Tola",
    email: "TOLA@example.com",
    role: "member",
    canContribute: true,
  });
  assert.ok(invite.code.length >= 40);
  const stored = (await db.collection("family_pockets").doc(pocketId)
    .collection("invites").doc(invite.inviteId).get()).data();
  assert.equal(stored.email, "tola@example.com");
  assert.notEqual(stored.codeHash, invite.code);
  assert.equal(JSON.stringify(stored).includes(invite.code), false);

  assert.deepEqual(
    (await family.resolveInviteCode({ code: invite.code })).pocketName,
    "Okafor Family Care",
  );
  await assert.rejects(
    family.createInvite({
      actorId: "owner-1",
      pocketId,
      idempotencyKey: "secondinvite00001",
      inviteeName: "Tola Again",
      email: "tola@example.com",
      role: "member",
    }),
    (error) => error.code === "duplicate-invite",
  );
  await assert.rejects(
    family.respondToInvite({
      code: invite.code,
      userId: "stranger",
      userName: "Stranger",
      email: "stranger@example.com",
      emailVerified: true,
      accept: true,
    }),
    (error) => error.code === "permission-denied",
  );
  await assert.rejects(
    family.respondToInvite({
      code: invite.code,
      userId: "tola",
      userName: "Tola",
      email: "tola@example.com",
      emailVerified: false,
      accept: true,
    }),
    (error) => error.code === "email-not-verified",
  );
});

test("accepts and declines invites without leaking membership authority", async () => {
  const { pocketId } = await createPocket();
  const accepted = await family.createInvite({
    actorId: "owner-1",
    pocketId,
    idempotencyKey: "acceptinvite00001",
    inviteeName: "Tola",
    email: "tola@example.com",
    role: "admin",
  });
  const response = await family.respondToInvite({
    code: accepted.code,
    userId: "tola-user",
    userName: "Tola",
    email: "TOLA@example.com",
    emailVerified: true,
    accept: true,
  });
  assert.equal(response.status, "accepted");
  const member = (await db.collection("family_pockets").doc(pocketId)
    .collection("members").doc("tola-user").get()).data();
  assert.equal(member.role, "admin");
  assert.equal(member.permissions.canManageMembers, true);

  const declined = await family.createInvite({
    actorId: "owner-1",
    pocketId,
    idempotencyKey: "declineinvite0001",
    inviteeName: "Chidi",
    email: "chidi@example.com",
    role: "member",
  });
  assert.equal((await family.respondToInvite({
    code: declined.code,
    userId: "chidi-user",
    userName: "Chidi",
    email: "chidi@example.com",
    emailVerified: true,
    accept: false,
  })).status, "declined");
  assert.equal((await db.collection("family_pockets").doc(pocketId)
    .collection("members").doc("chidi-user").get()).exists, false);
});

test("enforces owner, admin and member removal/leave boundaries", async () => {
  const { pocketId } = await createPocket();
  await inviteAndAccept({
    pocketId,
    userId: "admin-1",
    email: "admin@example.com",
    role: "admin",
  });
  await inviteAndAccept({
    pocketId,
    userId: "member-1",
    email: "member@example.com",
  });

  await assert.rejects(
    family.changeMembership({
      actorId: "member-1", pocketId, memberId: "admin-1", action: "remove",
    }),
    (error) => error.code === "permission-denied",
  );
  await assert.rejects(
    family.changeMembership({
      actorId: "admin-1", pocketId, memberId: "owner-1", action: "remove",
    }),
    (error) => error.code === "owner-transfer-required",
  );
  await family.changeMembership({
    actorId: "admin-1", pocketId, memberId: "member-1", action: "remove",
  });
  assert.equal((await db.collection("family_pockets").doc(pocketId)
    .collection("members").doc("member-1").get()).data().status, "removed");
});

test("requires ownership transfer or pocket closure before an owner leaves", async () => {
  const { pocketId } = await createPocket();
  await inviteAndAccept({
    pocketId,
    userId: "next-owner",
    email: "next@example.com",
  });
  await assert.rejects(
    family.changeMembership({
      actorId: "owner-1", pocketId, memberId: "owner-1", action: "leave",
    }),
    (error) => error.code === "owner-transfer-required",
  );
  await family.transferOwnership({ ownerId: "owner-1", pocketId, newOwnerId: "next-owner" });
  await family.changeMembership({
    actorId: "owner-1", pocketId, memberId: "owner-1", action: "leave",
  });
  const pocket = (await db.collection("family_pockets").doc(pocketId).get()).data();
  assert.equal(pocket.ownerId, "next-owner");

  await family.closePocket({ ownerId: "next-owner", pocketId });
  assert.equal((await db.collection("family_pockets").doc(pocketId).get()).data().status, "closed");
});

test("credits a Family Pocket only after trusted verification and only once", async () => {
  const { pocketId } = await createPocket();
  const pending = await family.initializeContribution({
    userId: "owner-1",
    pocketId,
    idempotencyKey: "familyfunding0001",
    amountKobo: 250000,
  });
  assert.equal(pending.status, "pending");
  assert.equal((await db.collection("family_pockets").doc(pocketId).get()).data().balanceKobo, 0);

  gateway.setNextOutcome("verifyFunding", "success");
  const completed = await family.verifyContribution({ attemptId: pending.attemptId });
  const retry = await family.verifyContribution({ attemptId: pending.attemptId });
  assert.equal(completed.status, "completed");
  assert.equal(retry.status, "completed");
  assert.equal((await db.collection("family_pockets").doc(pocketId).get()).data().balanceKobo, 250000);
  assert.equal((await db.collection("family_ledger_entries").get()).size, 1);
  assert.equal((await db.collection("activities").get()).size, 1);
  assert.equal((await db.collection("notification_events").get()).size, 1);
});

test("keeps concurrent member contributions independent and ledger-backed", async () => {
  const { pocketId } = await createPocket();
  await inviteAndAccept({
    pocketId,
    userId: "member-2",
    email: "member2@example.com",
  });
  const [ownerAttempt, memberAttempt] = await Promise.all([
    family.initializeContribution({
      userId: "owner-1", pocketId,
      idempotencyKey: "ownercontribute001", amountKobo: 150000,
    }),
    family.initializeContribution({
      userId: "member-2", pocketId,
      idempotencyKey: "membercontribute01", amountKobo: 350000,
    }),
  ]);
  gateway.setNextOutcome("verifyFunding", "success");
  gateway.setNextOutcome("verifyFunding", "success");
  await Promise.all([
    family.verifyContribution({ attemptId: ownerAttempt.attemptId }),
    family.verifyContribution({ attemptId: memberAttempt.attemptId }),
  ]);

  const pocketRef = db.collection("family_pockets").doc(pocketId);
  assert.equal((await pocketRef.get()).data().balanceKobo, 500000);
  assert.equal((await pocketRef.collection("members").doc("owner-1").get())
    .data().lifetimeContributionKobo, 150000);
  assert.equal((await pocketRef.collection("members").doc("member-2").get())
    .data().lifetimeContributionKobo, 350000);
  assert.deepEqual(await family.reconcilePocket(pocketId), {
    matches: true,
    expectedBalanceKobo: 500000,
    actualBalanceKobo: 500000,
    entryCount: 2,
  });
});

test("failure and timeout never change the Family Pocket balance", async () => {
  const { pocketId } = await createPocket();
  gateway.setNextOutcome("initializeFunding", "failure");
  const failed = await family.initializeContribution({
    userId: "owner-1", pocketId,
    idempotencyKey: "familyfailure0001", amountKobo: 100000,
  });
  assert.equal(failed.status, "failed");

  const pending = await family.initializeContribution({
    userId: "owner-1", pocketId,
    idempotencyKey: "familytimeout0001", amountKobo: 200000,
  });
  gateway.setNextOutcome("verifyFunding", "timeout");
  assert.equal((await family.verifyContribution({ attemptId: pending.attemptId })).status, "timed_out");
  assert.equal((await db.collection("family_pockets").doc(pocketId).get()).data().balanceKobo, 0);
  assert.equal((await db.collection("family_ledger_entries").get()).size, 0);

  gateway.setNextOutcome("verifyFunding", "success");
  assert.equal((await family.verifyContribution({ attemptId: pending.attemptId })).status, "completed");
  assert.equal((await db.collection("family_pockets").doc(pocketId).get()).data().balanceKobo, 200000);
});
