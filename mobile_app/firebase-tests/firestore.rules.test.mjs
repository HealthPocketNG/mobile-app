import { after, before, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-healthpocket';
const now = Timestamp.fromDate(new Date('2026-01-01T00:00:00Z'));
let environment;

const verifiedContext = (uid, email = `${uid}@example.com`) =>
  environment.authenticatedContext(uid, {
    email,
    email_verified: true,
    firebase: { sign_in_provider: 'google.com' },
  });

const profileFor = (uid, email = `${uid}@example.com`) => ({
  userId: uid,
  fullName: 'HealthPocket User',
  email,
  phoneNumber: '',
  stateOfResidence: 'Lagos',
  dateOfBirth: null,
  gender: null,
  residentialAddress: '',
  nextOfKinName: '',
  nextOfKinPhone: '',
  emailVerified: true,
  phoneVerified: false,
  kycStatus: 'notStarted',
  onboardingStatus: 'incomplete',
  notificationPreferences: {
    savingsReminders: true,
    familyActivity: true,
    healthReminders: true,
    productUpdates: false,
  },
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
});

const seedPersonalSavings = async (uid = 'owner') => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, `personal_health_pockets/personal-${uid}`), {
      userId: uid,
      currency: 'NGN',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    });
    await setDoc(doc(db, `savings_plans/personal-plan-${uid}`), {
      userId: uid,
      personalHealthPocketId: `personal-${uid}`,
      contributionAmountKobo: 500000,
      frequency: 'weekly',
      startDate: now,
      nextContributionDate: null,
      status: 'active',
      fundingSourceId: null,
      createdAt: now,
      updatedAt: now,
    });
  });
};

const seedFamilyPocket = async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const uid of ['admin', 'member', 'beneficiary']) {
      await setDoc(doc(db, `users/${uid}`), profileFor(uid));
    }
    await setDoc(doc(db, 'family_pockets/family-secure'), {
      name: 'Secure Family',
      beneficiaryLimit: 2,
      createdBy: 'admin',
      currency: 'NGN',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    });
    for (const [uid, role, canContribute, isBeneficiary] of [
      ['admin', 'admin', true, false],
      ['member', 'member', true, false],
      ['beneficiary', 'member', false, true],
    ]) {
      await setDoc(doc(db, `family_pockets/family-secure/members/${uid}`), {
        pocketId: 'family-secure',
        userId: uid,
        name: uid,
        role,
        canContribute,
        isBeneficiary,
        ...(isBeneficiary ? { beneficiarySlot: 1 } : {}),
        status: 'accepted',
        joinedAt: now,
      });
    }
    await setDoc(
      doc(db, 'family_pockets/family-secure/beneficiary_slots/1'),
      {
        pocketId: 'family-secure',
        slot: 1,
        state: 'accepted',
        invitationId: 'historical-beneficiary-invite',
        memberUserId: 'beneficiary',
        updatedAt: now,
      },
    );
  });
};

const familyDevelopmentContribution = (
  uid,
  key,
  overrides = {},
) => ({
  contributorUserId: uid,
  familyPocketId: 'family-secure',
  contributorName: uid,
  amountKobo: 500000,
  currency: 'NGN',
  status: 'recorded',
  origin: 'dev_simulation',
  moneyMovement: false,
  idempotencyKey: key,
  createdAt: serverTimestamp(),
  ...overrides,
});

const developmentContribution = (
  uid,
  idempotencyKey,
  overrides = {},
) => ({
  contributorUserId: uid,
  personalHealthPocketId: `personal-${uid}`,
  savingsPlanId: `personal-plan-${uid}`,
  amountKobo: 500000,
  currency: 'NGN',
  status: 'recorded',
  origin: 'dev_simulation',
  moneyMovement: false,
  idempotencyKey,
  createdAt: serverTimestamp(),
  ...overrides,
});

const recordIdempotently = async (db, uid, key, amountKobo = 500000) => {
  const reference = doc(db, `contributions/dev_${uid}_${key}`);
  await runTransaction(db, async (transaction) => {
    const existing = await transaction.get(reference);
    if (existing.exists()) return;
    transaction.set(
      reference,
      developmentContribution(uid, key, { amountKobo }),
    );
  });
};

before(async () => {
  const rules = await readFile(
    new URL('../firestore.rules', import.meta.url),
    'utf8',
  );
  environment = await initializeTestEnvironment({
    projectId,
    firestore: { host: '127.0.0.1', port: 8080, rules },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

test('user profiles are private to their owner', async () => {
  const ownerDb = verifiedContext('owner').firestore();
  const strangerDb = verifiedContext('stranger').firestore();
  const profile = profileFor('owner');

  await assertSucceeds(setDoc(doc(ownerDb, 'users/owner'), profile));
  await assertSucceeds(getDoc(doc(ownerDb, 'users/owner')));
  await assertFails(getDoc(doc(strangerDb, 'users/owner')));
  await assertFails(
    getDoc(doc(environment.unauthenticatedContext().firestore(), 'users/owner')),
  );
});

test('membership identity is bound to its document path', async () => {
  await seedFamilyPocket();
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'family_pockets/family-secure/members/alias'),
      {
        pocketId: 'family-secure',
        userId: 'victim',
        name: 'Victim',
        role: 'member',
        canContribute: true,
        isBeneficiary: false,
        status: 'accepted',
        joinedAt: now,
      },
    );
  });
  await assertFails(
    getDoc(
      doc(
        verifiedContext('victim').firestore(),
        'family_pockets/family-secure/members/alias',
      ),
    ),
  );
});

test('unverified email accounts cannot access application data', async () => {
  const unverifiedDb = environment.authenticatedContext('owner', {
    email: 'owner@example.com',
    email_verified: false,
  }).firestore();

  await assertFails(
    setDoc(doc(unverifiedDb, 'users/owner'), {
      ...profileFor('owner'),
      emailVerified: false,
    }),
  );
});

test('an owner-scoped empty query can precede private document creation', async () => {
  const ownerDb = verifiedContext('owner').firestore();

  await assertSucceeds(
    getDocs(
      query(
        collection(ownerDb, 'personal_health_pockets'),
        where('userId', '==', 'owner'),
      ),
    ),
  );
  await assertSucceeds(
    getDocs(
      query(
        collection(ownerDb, 'savings_plans'),
        where('userId', '==', 'owner'),
      ),
    ),
  );

  // A missing document has no resource.data.userId with which to prove
  // ownership, which is why repository create-or-update checks use queries.
  await assertFails(
    getDoc(doc(ownerDb, 'personal_health_pockets/personal-owner')),
  );
});

test('profile schema and immutable identity cannot be polluted', async () => {
  const ownerDb = verifiedContext('owner').firestore();
  await assertSucceeds(
    setDoc(doc(ownerDb, 'users/owner'), profileFor('owner')),
  );

  await assertSucceeds(
    updateDoc(doc(ownerDb, 'users/owner'), {
      notificationPreferences: {
        savingsReminders: false,
        familyActivity: true,
        healthReminders: false,
        productUpdates: true,
      },
      updatedAt: serverTimestamp(),
    }),
  );
  const strangerDb = verifiedContext('stranger').firestore();
  await assertFails(
    updateDoc(doc(strangerDb, 'users/owner'), {
      notificationPreferences: {
        savingsReminders: true,
        familyActivity: true,
        healthReminders: true,
        productUpdates: true,
      },
    }),
  );

  await assertFails(
    updateDoc(doc(ownerDb, 'users/owner'), { userId: 'stranger' }),
  );
  await assertFails(
    updateDoc(doc(ownerDb, 'users/owner'), { isAdmin: true }),
  );
  await assertFails(
    updateDoc(doc(ownerDb, 'users/owner'), { fullName: 'x'.repeat(101) }),
  );
  await assertFails(
    updateDoc(doc(ownerDb, 'users/owner'), { kycStatus: 'verified' }),
  );
});

test('profile image references stay inside the owners storage path', async () => {
  const ownerDb = verifiedContext('owner').firestore();
  const reference = doc(ownerDb, 'users/owner');
  await assertSucceeds(setDoc(reference, profileFor('owner')));

  await assertSucceeds(
    updateDoc(reference, {
      profileImagePath:
        'users/owner/profile/0123456789abcdef0123456789abcdef.jpg',
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(reference, {
      profileImagePath:
        'users/stranger/profile/0123456789abcdef0123456789abcdef.jpg',
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(reference, {
      profileImagePath: 'https://example.com/untrusted.jpg',
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    updateDoc(reference, {
      profileImagePath: null,
      updatedAt: serverTimestamp(),
    }),
  );
});

test('onboarding completion requires profile details and cannot be reverted', async () => {
  const ownerDb = verifiedContext('owner').firestore();
  const reference = doc(ownerDb, 'users/owner');
  await assertSucceeds(setDoc(reference, profileFor('owner')));

  await assertFails(
    updateDoc(reference, {
      onboardingStatus: 'complete',
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    updateDoc(reference, {
      dateOfBirth: now,
      gender: 'Female',
      residentialAddress: '12 Health Street',
      onboardingStatus: 'complete',
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(reference, {
      onboardingStatus: 'incomplete',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('client-selected audit timestamps are rejected', async () => {
  const ownerDb = verifiedContext('owner').firestore();
  await assertFails(
    setDoc(doc(ownerDb, 'users/owner'), {
      ...profileFor('owner'),
      createdAt: now,
      updatedAt: now,
    }),
  );
  await assertFails(
    setDoc(doc(ownerDb, 'personal_health_pockets/personal-owner'), {
      userId: 'owner',
      currency: 'NGN',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    }),
  );
});

test('owner IDs are canonical and cannot be duplicated on alternate paths', async () => {
  const ownerDb = verifiedContext('owner').firestore();
  await assertFails(
    setDoc(doc(ownerDb, 'personal_health_pockets/alternate-pocket'), {
      userId: 'owner',
      currency: 'NGN',
      status: 'active',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    setDoc(doc(ownerDb, 'personal_health_pockets/personal-owner'), {
      userId: 'owner',
      currency: 'NGN',
      status: 'active',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(doc(ownerDb, 'savings_plans/alternate-plan'), {
      userId: 'owner',
      personalHealthPocketId: 'personal-owner',
      contributionAmountKobo: 500000,
      frequency: 'weekly',
      startDate: now,
      nextContributionDate: null,
      status: 'active',
      fundingSourceId: null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});

test('a Family Pocket requires a canonical ID and atomic founding admin', async () => {
  const ownerDb = verifiedContext('owner').firestore();
  await assertFails(
    setDoc(doc(ownerDb, 'family_pockets/family-owner'), {
      name: 'Orphan Family',
      beneficiaryLimit: 2,
      createdBy: 'owner',
      currency: 'NGN',
      status: 'active',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(
      doc(
        ownerDb,
        'family_pockets/family_owner_00000000000000000000000000000009',
      ),
      {
        name: 'Orphan Family',
        beneficiaryLimit: 2,
        createdBy: 'owner',
        currency: 'NGN',
        status: 'active',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
    ),
  );
});

test('an owner can create and edit the default savings plan', async () => {
  const ownerDb = verifiedContext('owner').firestore();
  await assertSucceeds(
    setDoc(doc(ownerDb, 'personal_health_pockets/personal-owner'), {
      userId: 'owner',
      currency: 'NGN',
      status: 'active',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    setDoc(doc(ownerDb, 'savings_plans/personal-plan-owner'), {
      userId: 'owner',
      personalHealthPocketId: 'personal-owner',
      contributionAmountKobo: 500000,
      frequency: 'weekly',
      startDate: now,
      nextContributionDate: null,
      status: 'active',
      fundingSourceId: null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    updateDoc(doc(ownerDb, 'savings_plans/personal-plan-owner'), {
      contributionAmountKobo: 750000,
      frequency: 'monthly',
      status: 'paused',
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    updateDoc(doc(ownerDb, 'savings_plans/personal-plan-owner'), {
      status: 'active',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('savings plan ownership, initial state, and terminal cancellation are enforced', async () => {
  await seedPersonalSavings();
  const ownerDb = verifiedContext('owner').firestore();
  const strangerDb = verifiedContext('stranger').firestore();

  await assertFails(getDoc(
    doc(strangerDb, 'savings_plans/personal-plan-owner'),
  ));
  await assertFails(updateDoc(
    doc(strangerDb, 'savings_plans/personal-plan-owner'),
    { contributionAmountKobo: 1, updatedAt: serverTimestamp() },
  ));
  await assertFails(
    setDoc(doc(strangerDb, 'savings_plans/personal-plan-stranger'), {
      userId: 'owner',
      personalHealthPocketId: 'personal-owner',
      contributionAmountKobo: 500000,
      frequency: 'weekly',
      startDate: now,
      nextContributionDate: null,
      status: 'active',
      fundingSourceId: null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );

  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'personal_health_pockets/personal-new-owner'),
      {
        userId: 'new-owner',
        currency: 'NGN',
        status: 'active',
        createdAt: now,
        updatedAt: now,
      },
    );
  });
  const newOwnerDb = verifiedContext('new-owner').firestore();
  await assertFails(
    setDoc(doc(newOwnerDb, 'savings_plans/personal-plan-new-owner'), {
      userId: 'new-owner',
      personalHealthPocketId: 'personal-new-owner',
      contributionAmountKobo: 500000,
      frequency: 'weekly',
      startDate: now,
      nextContributionDate: null,
      status: 'paused',
      fundingSourceId: null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );

  await environment.withSecurityRulesDisabled(async (context) => {
    await updateDoc(
      doc(context.firestore(), 'savings_plans/personal-plan-owner'),
      { status: 'cancelled', updatedAt: now },
    );
  });
  await assertSucceeds(getDoc(
    doc(ownerDb, 'savings_plans/personal-plan-owner'),
  ));
  await assertFails(updateDoc(
    doc(ownerDb, 'savings_plans/personal-plan-owner'),
    { status: 'active', updatedAt: serverTimestamp() },
  ));
  await assertFails(updateDoc(
    doc(ownerDb, 'savings_plans/personal-plan-owner'),
    { contributionAmountKobo: 750000, updatedAt: serverTimestamp() },
  ));
});

test('scheduled contributions are owner-readable and server-write-only', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const uid of ['owner', 'stranger']) {
      await setDoc(doc(db, `scheduled_contributions/scheduled-${uid}`), {
        userId: uid,
        savingsPlanId: `personal-plan-${uid}`,
        amountKobo: 500000,
        currency: 'NGN',
        status: 'pending',
        scheduledFor: now,
        createdAt: now,
        updatedAt: now,
      });
    }
  });

  const ownerDb = verifiedContext('owner').firestore();
  await assertSucceeds(getDoc(
    doc(ownerDb, 'scheduled_contributions/scheduled-owner'),
  ));
  await assertFails(getDoc(
    doc(ownerDb, 'scheduled_contributions/scheduled-stranger'),
  ));
  await assertSucceeds(getDocs(query(
    collection(ownerDb, 'scheduled_contributions'),
    where('userId', '==', 'owner'),
  )));
  await assertFails(getDocs(collection(ownerDb, 'scheduled_contributions')));
  await assertFails(
    setDoc(doc(ownerDb, 'scheduled_contributions/forged'), {
      userId: 'owner',
      savingsPlanId: 'personal-plan-owner',
      amountKobo: 999999,
      status: 'completed',
    }),
  );
  await assertFails(updateDoc(
    doc(ownerDb, 'scheduled_contributions/scheduled-owner'),
    { status: 'completed' },
  ));

  await assertFails(
    setDoc(doc(ownerDb, 'savings_plan_operations/forged'), {
      userId: 'owner',
      status: 'completed',
    }),
  );
  await assertFails(getDoc(
    doc(ownerDb, 'savings_plan_operations/server-record'),
  ));
});

test('Family Pocket and founding admin are created atomically', async () => {
  const ownerDb = verifiedContext('owner').firestore();
  const pocketId = 'family_owner_00000000000000000000000000000001';
  await assertSucceeds(
    setDoc(doc(ownerDb, 'users/owner'), {
      ...profileFor('owner'),
      fullName: 'Ada Nwosu',
    }),
  );
  const batch = writeBatch(ownerDb);
  batch.set(doc(ownerDb, `family_pockets/${pocketId}`), {
    name: 'Nwosu Family',
    beneficiaryLimit: 2,
    createdBy: 'owner',
    currency: 'NGN',
    status: 'active',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batch.set(doc(ownerDb, `family_pockets/${pocketId}/members/owner`), {
    pocketId,
    userId: 'owner',
    name: 'Ada Nwosu',
    role: 'admin',
    canContribute: true,
    isBeneficiary: false,
    status: 'accepted',
    joinedAt: serverTimestamp(),
  });

  await assertSucceeds(batch.commit());
  await assertSucceeds(
    getDocs(query(
      collectionGroup(ownerDb, 'members'),
      where('userId', '==', 'owner'),
      where('status', '==', 'accepted'),
      orderBy('joinedAt', 'desc'),
    )),
  );
  await assertSucceeds(
    getDocs(collection(ownerDb, `family_pockets/${pocketId}/members`)),
  );
  await assertFails(
    getDocs(
      collection(
        verifiedContext('stranger').firestore(),
        `family_pockets/${pocketId}/members`,
      ),
    ),
  );
});

test('only an admin can soft-remove a Family Pocket contributor', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'family_pockets/family-1'), {
      name: 'Nwosu Family',
      beneficiaryLimit: 2,
      createdBy: 'admin',
      currency: 'NGN',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    });
    await setDoc(doc(db, 'family_pockets/family-1/members/admin'), {
      pocketId: 'family-1',
      userId: 'admin',
      name: 'Admin',
      role: 'admin',
      canContribute: true,
      isBeneficiary: false,
      status: 'accepted',
      joinedAt: now,
    });
    await setDoc(doc(db, 'family_pockets/family-1/members/member'), {
      pocketId: 'family-1',
      userId: 'member',
      name: 'Member',
      role: 'member',
      canContribute: true,
      isBeneficiary: false,
      status: 'accepted',
      joinedAt: now,
    });
  });

  const contributorDb = verifiedContext('member').firestore();
  await assertFails(
    updateDoc(doc(contributorDb, 'family_pockets/family-1/members/member'), {
      status: 'removed',
      removedAt: now,
    }),
  );

  await assertFails(
    updateDoc(doc(verifiedContext('admin').firestore(), 'family_pockets/family-1/members/member'), {
      role: 'admin',
    }),
  );

  const adminDb = verifiedContext('admin').firestore();
  await assertSucceeds(
    updateDoc(doc(adminDb, 'family_pockets/family-1/members/member'), {
      status: 'removed',
      removedAt: serverTimestamp(),
    }),
  );
});

test('an invitee can discover and accept only their verified-email invite', async () => {
  await seedFamilyPocket();
  const adminDb = verifiedContext('admin').firestore();
  const memberDb = verifiedContext('member').firestore();
  const inviteeDb = verifiedContext('invitee', 'tola@example.com').firestore();
  await assertSucceeds(
    setDoc(
      doc(inviteeDb, 'users/invitee'),
      profileFor('invitee', 'tola@example.com'),
    ),
  );
  const inviteId = 'invite_admin_00000000000000000000000000000001';
  const invitePath = `family_pockets/family-secure/invites/${inviteId}`;
  await assertSucceeds(
    setDoc(doc(adminDb, invitePath), {
      pocketId: 'family-secure',
      pocketName: 'Secure Family',
      inviteeName: 'Tola Family',
      email: 'tola@example.com',
      inviterName: 'HealthPocket User',
      role: 'member',
      canContribute: true,
      isBeneficiary: false,
      status: 'pending',
      createdBy: 'admin',
      createdAt: serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000),
    }),
  );
  await assertSucceeds(getDoc(doc(adminDb, invitePath)));
  await assertFails(getDoc(doc(memberDb, invitePath)));
  await assertSucceeds(getDoc(doc(inviteeDb, invitePath)));
  const unverifiedInviteeDb = environment.authenticatedContext(
    'unverified-invitee',
    { email: 'tola@example.com', email_verified: false },
  ).firestore();
  await assertFails(getDoc(doc(unverifiedInviteeDb, invitePath)));
  await assertFails(
    updateDoc(doc(inviteeDb, invitePath), {
      status: 'accepted',
      respondedBy: 'invitee',
      respondedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(doc(inviteeDb, invitePath), {
      status: 'declined',
      canContribute: false,
      respondedBy: 'invitee',
      respondedAt: serverTimestamp(),
    }),
  );
  const ownInvites = query(
    collectionGroup(inviteeDb, 'invites'),
    where('email', '==', 'tola@example.com'),
    where('status', '==', 'pending'),
    orderBy('createdAt', 'desc'),
  );
  const ownSnapshot = await assertSucceeds(getDocs(ownInvites));
  if (ownSnapshot.size !== 1) {
    throw new Error(`Expected one matching invitation, got ${ownSnapshot.size}.`);
  }
  await assertFails(
    getDocs(query(
      collectionGroup(memberDb, 'invites'),
      where('email', '==', 'tola@example.com'),
      where('status', '==', 'pending'),
      orderBy('createdAt', 'desc'),
    )),
  );

  const acceptance = writeBatch(inviteeDb);
  acceptance.update(doc(inviteeDb, invitePath), {
    status: 'accepted',
    respondedBy: 'invitee',
    respondedAt: serverTimestamp(),
  });
  acceptance.set(
    doc(inviteeDb, 'family_pockets/family-secure/members/invitee'),
    {
      pocketId: 'family-secure',
      userId: 'invitee',
      invitationId: inviteId,
      name: 'HealthPocket User',
      role: 'member',
      canContribute: true,
      isBeneficiary: false,
      status: 'accepted',
      joinedAt: serverTimestamp(),
    },
  );
  await assertSucceeds(acceptance.commit());
  await assertSucceeds(getDoc(doc(inviteeDb, 'family_pockets/family-secure')));

  await assertFails(
    setDoc(doc(memberDb, 'family_pockets/family-secure/invites/invite_member_00000000000000000000000000000001'), {
      pocketId: 'family-secure',
      pocketName: 'Secure Family',
      inviteeName: 'Attack',
      email: 'attack@example.com',
      inviterName: 'Member',
      role: 'member',
      canContribute: true,
      isBeneficiary: false,
      status: 'pending',
      createdBy: 'member',
      createdAt: serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000),
    }),
  );
  await assertFails(
    setDoc(doc(adminDb, 'family_pockets/family-secure/invites/invite_admin_00000000000000000000000000000002'), {
      pocketId: 'family-secure',
      pocketName: 'Secure Family',
      inviteeName: 'x'.repeat(101),
      email: 'bad@example.com',
      inviterName: 'HealthPocket User',
      role: 'admin',
      canContribute: true,
      isBeneficiary: false,
      status: 'pending',
      createdBy: 'admin',
      createdAt: serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000),
      extraData: true,
    }),
  );
});

test('beneficiary invitations reserve at most two slots and release declined slots', async () => {
  await seedFamilyPocket();
  const adminDb = verifiedContext('admin').firestore();
  const expiry = Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000);

  const reserve = async (id, email, slot) => {
    const batch = writeBatch(adminDb);
    batch.set(doc(adminDb, `family_pockets/family-secure/invites/${id}`), {
      pocketId: 'family-secure',
      pocketName: 'Secure Family',
      inviteeName: `Beneficiary ${slot}`,
      email,
      inviterName: 'HealthPocket User',
      role: 'member',
      canContribute: false,
      isBeneficiary: true,
      beneficiarySlot: slot,
      status: 'pending',
      createdBy: 'admin',
      createdAt: serverTimestamp(),
      expiresAt: expiry,
    });
    batch.set(
      doc(adminDb, `family_pockets/family-secure/beneficiary_slots/${slot}`),
      {
        pocketId: 'family-secure',
        slot,
        state: 'reserved',
        invitationId: id,
        updatedAt: serverTimestamp(),
      },
    );
    return batch.commit();
  };

  const invite2 = 'invite_admin_00000000000000000000000000000012';
  const invite3 = 'invite_admin_00000000000000000000000000000013';
  const invite4 = 'invite_admin_00000000000000000000000000000014';
  await assertSucceeds(reserve(invite2, 'two@example.com', 2));
  await assertFails(reserve(invite3, 'three@example.com', 3));

  const inviteeDb = verifiedContext('invitee-two', 'two@example.com').firestore();
  const decline = writeBatch(inviteeDb);
  decline.update(
    doc(
      inviteeDb,
      `family_pockets/family-secure/invites/${invite2}`,
    ),
    {
      status: 'declined',
      respondedBy: 'invitee-two',
      respondedAt: serverTimestamp(),
    },
  );
  decline.delete(
    doc(inviteeDb, 'family_pockets/family-secure/beneficiary_slots/2'),
  );
  await assertSucceeds(decline.commit());

  await assertSucceeds(reserve(invite4, 'four@example.com', 2));
  const fourthDb = verifiedContext('invitee-four', 'four@example.com').firestore();
  await assertSucceeds(
    setDoc(
      doc(fourthDb, 'users/invitee-four'),
      profileFor('invitee-four', 'four@example.com'),
    ),
  );
  const acceptance = writeBatch(fourthDb);
  acceptance.update(
    doc(
      fourthDb,
      `family_pockets/family-secure/invites/${invite4}`,
    ),
    {
      status: 'accepted',
      respondedBy: 'invitee-four',
      respondedAt: serverTimestamp(),
    },
  );
  acceptance.set(
    doc(fourthDb, 'family_pockets/family-secure/members/invitee-four'),
    {
      pocketId: 'family-secure',
      userId: 'invitee-four',
      invitationId: invite4,
      name: 'HealthPocket User',
      role: 'member',
      canContribute: false,
      isBeneficiary: true,
      beneficiarySlot: 2,
      status: 'accepted',
      joinedAt: serverTimestamp(),
    },
  );
  acceptance.update(
    doc(fourthDb, 'family_pockets/family-secure/beneficiary_slots/2'),
    {
      state: 'accepted',
      memberUserId: 'invitee-four',
      updatedAt: serverTimestamp(),
    },
  );
  await assertSucceeds(acceptance.commit());

  const removal = writeBatch(adminDb);
  removal.update(
    doc(adminDb, 'family_pockets/family-secure/members/invitee-four'),
    { status: 'removed', removedAt: serverTimestamp() },
  );
  removal.delete(
    doc(adminDb, 'family_pockets/family-secure/beneficiary_slots/2'),
  );
  await assertSucceeds(removal.commit());
});

test('Family DEV contributions are member-scoped, idempotent and immutable', async () => {
  await seedFamilyPocket();
  const memberDb = verifiedContext('member').firestore();
  const adminDb = verifiedContext('admin').firestore();
  const key = 'familyrecord0001';
  const reference = doc(memberDb, `contributions/dev_family_member_${key}`);

  const write = () => runTransaction(memberDb, async (transaction) => {
    const existing = await transaction.get(reference);
    if (!existing.exists()) {
      transaction.set(
        reference,
        familyDevelopmentContribution('member', key),
      );
    }
  });
  await assertSucceeds(write());
  await assertSucceeds(write());
  const familyQuery = query(
    collection(adminDb, 'contributions'),
    where('familyPocketId', '==', 'family-secure'),
    orderBy('createdAt', 'desc'),
  );
  const snapshot = await assertSucceeds(getDocs(familyQuery));
  if (snapshot.size !== 1) {
    throw new Error(`Expected one Family record, got ${snapshot.size}.`);
  }
  await assertFails(updateDoc(reference, { amountKobo: 900000 }));

  const beneficiaryDb = verifiedContext('beneficiary').firestore();
  await assertFails(
    setDoc(
      doc(
        beneficiaryDb,
        'contributions/dev_family_beneficiary_familyrecord0002',
      ),
      familyDevelopmentContribution('beneficiary', 'familyrecord0002'),
    ),
  );
  const strangerDb = verifiedContext('stranger').firestore();
  await assertFails(getDocs(query(
    collection(strangerDb, 'contributions'),
    where('familyPocketId', '==', 'family-secure'),
  )));
  await assertFails(
    setDoc(
      doc(strangerDb, 'contributions/dev_family_stranger_familyrecord0003'),
      familyDevelopmentContribution('stranger', 'familyrecord0003'),
    ),
  );

  for (const [index, overrides] of [
    { amountKobo: 0 },
    { amountKobo: '500000' },
    { currency: 'USD' },
    { moneyMovement: true },
    { origin: 'provider' },
    { contributorName: 'Spoofed name' },
    { createdAt: now },
    { extraData: 'pollution' },
  ].entries()) {
    const invalidKey = `familyinvalid${String(index).padStart(3, '0')}`;
    await assertFails(
      setDoc(
        doc(memberDb, `contributions/dev_family_member_${invalidKey}`),
        familyDevelopmentContribution('member', invalidKey, overrides),
      ),
    );
  }

  await assertSucceeds(
    updateDoc(doc(adminDb, 'family_pockets/family-secure/members/member'), {
      status: 'removed',
      removedAt: serverTimestamp(),
    }),
  );
  await assertFails(getDoc(doc(memberDb, 'family_pockets/family-secure')));
  await assertFails(getDocs(query(
    collection(memberDb, 'contributions'),
    where('familyPocketId', '==', 'family-secure'),
  )));
  const preserved = await assertSucceeds(getDocs(familyQuery));
  if (preserved.size !== 1) {
    throw new Error('Removing a member deleted historical contributions.');
  }
});

test('DEV contributions are idempotent, append-only and owner scoped', async () => {
  await seedPersonalSavings();
  const ownerDb = verifiedContext('owner').firestore();
  const key = '1111111111111111';

  await assertSucceeds(recordIdempotently(ownerDb, 'owner', key));
  await assertSucceeds(recordIdempotently(ownerDb, 'owner', key));
  const ownedQuery = query(
    collection(ownerDb, 'contributions'),
    where('contributorUserId', '==', 'owner'),
    where('personalHealthPocketId', '==', 'personal-owner'),
    orderBy('createdAt', 'desc'),
  );
  const snapshot = await assertSucceeds(getDocs(ownedQuery));
  if (snapshot.size !== 1) {
    throw new Error(`Expected one idempotent record, got ${snapshot.size}.`);
  }
  await assertFails(
    updateDoc(doc(ownerDb, `contributions/dev_owner_${key}`), {
      amountKobo: 600000,
    }),
  );

  const strangerDb = verifiedContext('stranger').firestore();
  await assertFails(
    getDoc(doc(strangerDb, `contributions/dev_owner_${key}`)),
  );
  await assertFails(
    getDocs(
      query(
        collection(strangerDb, 'contributions'),
        where('contributorUserId', '==', 'owner'),
        where('personalHealthPocketId', '==', 'personal-owner'),
      ),
    ),
  );
  await assertFails(
    setDoc(
      doc(strangerDb, 'contributions/dev_stranger_2222222222222222'),
      developmentContribution('stranger', '2222222222222222', {
        personalHealthPocketId: 'personal-owner',
        savingsPlanId: 'personal-plan-owner',
      }),
    ),
  );

  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(
        context.firestore(),
        'contributions/dev_owner_9999999999999999',
      ),
      developmentContribution('stranger', '9999999999999999'),
    );
  });
  await assertFails(
    getDoc(doc(ownerDb, 'contributions/dev_owner_9999999999999999')),
  );
});

test('DEV contribution validation rejects money-like and malformed records', async () => {
  await seedPersonalSavings();
  const ownerDb = verifiedContext('owner').firestore();
  const attempts = [
    { amountKobo: 0 },
    { amountKobo: -100 },
    { amountKobo: 100000000001 },
    { amountKobo: '500000' },
    { currency: 'USD' },
    { status: 'completed' },
    { origin: 'provider' },
    { moneyMovement: true },
    { createdAt: now },
    { extraData: 'schema pollution' },
    { note: 'x'.repeat(281) },
    { savingsPlanId: 'some-other-plan' },
  ];

  for (const [index, overrides] of attempts.entries()) {
    const key = `invalidrecord${String(index).padStart(4, '0')}`;
    await assertFails(
      setDoc(
        doc(ownerDb, `contributions/dev_owner_${key}`),
        developmentContribution('owner', key, overrides),
      ),
    );
  }

  await assertFails(
    setDoc(
      doc(ownerDb, 'contributions/dev_owner_3333333333333333'),
      developmentContribution('owner', 'mismatchedkey0000'),
    ),
  );
});

test('a non-member cannot write into a Family Pocket activity feed', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'family_pockets/family-1'), {
      name: 'Nwosu Family',
      beneficiaryLimit: 2,
      createdBy: 'admin',
      currency: 'NGN',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    });
  });
  const strangerDb = verifiedContext('stranger').firestore();

  await assertFails(
    setDoc(doc(strangerDb, 'activities/activity-1'), {
      userId: 'stranger',
      activityType: 'contributionRecorded',
      metadata: { amount: 5000 },
      relatedEntityType: 'contribution',
      relatedEntityId: 'contribution-1',
      familyPocketId: 'family-1',
      createdAt: now,
    }),
  );
});

test('even active members cannot manufacture audit activity', async () => {
  await seedFamilyPocket();
  const memberDb = verifiedContext('member').firestore();
  await assertFails(
    setDoc(doc(memberDb, 'activities/member-forged-event'), {
      userId: 'member',
      activityType: 'contributionRecorded',
      metadata: { amount: 5000 },
      relatedEntityType: 'contribution',
      relatedEntityId: 'forged-contribution',
      familyPocketId: 'family-secure',
      createdAt: serverTimestamp(),
    }),
  );
});

test('phone identity cannot access Google-only MVP data', async () => {
  const phoneDb = environment.authenticatedContext('phone-user', {
    phone_number: '+2348012345678',
  }).firestore();

  await assertFails(
    setDoc(doc(phoneDb, 'users/phone-user'), {
      ...profileFor('phone-user'),
      email: '',
      emailVerified: false,
    }),
  );
  await assertFails(
    setDoc(doc(phoneDb, 'personal_health_pockets/phone-pocket'), {
      userId: 'phone-user',
      currency: 'NGN',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    }),
  );
});

test('unknown collections remain denied', async () => {
  const ownerDb = verifiedContext('owner').firestore();
  await assertFails(
    setDoc(doc(ownerDb, 'admin_roles/owner'), { role: 'admin' }),
  );
});

test('payment attempts and provider events remain server-only', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'payment_attempts/pay-server-owned'), {
      userId: 'owner',
      kind: 'funding',
      amountKobo: 5000,
      currency: 'NGN',
      status: 'pending',
      provider: 'mock',
      providerReference: null,
    });
    await setDoc(doc(db, 'provider_events/event-server-owned'), {
      provider: 'mock',
      paymentAttemptId: 'pay-server-owned',
      normalizedStatus: 'pending',
      status: 'processed',
    });
  });

  const ownerDb = verifiedContext('owner').firestore();
  for (const path of [
    'payment_attempts/pay-server-owned',
    'provider_events/event-server-owned',
  ]) {
    await assertFails(getDoc(doc(ownerDb, path)));
    await assertFails(updateDoc(doc(ownerDb, path), { status: 'succeeded' }));
  }
  await assertFails(
    setDoc(doc(ownerDb, 'payment_attempts/pay-forged'), {
      userId: 'owner',
      status: 'succeeded',
    }),
  );
  await assertFails(getDocs(collection(ownerDb, 'payment_attempts')));
  await assertFails(getDocs(collection(ownerDb, 'provider_events')));
});

test('funding transactions and notification events are owner-readable and server-write-only', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const uid of ['owner', 'stranger']) {
      await setDoc(doc(db, `funding_transactions/funding-${uid}`), {
        schemaVersion: 1,
        userId: uid,
        paymentAttemptId: `attempt-${uid}`,
        amountKobo: 500000,
        currency: 'NGN',
        status: 'completed',
        provider: 'mock',
        providerReference: `mock-${uid}`,
        ledgerOperationId: `operation-${uid}`,
        failureCode: null,
        transactionReference: `attempt-${uid}`,
        receiptNumber: `HPF-${uid.toUpperCase()}`,
        description: 'HealthPocket wallet funding',
        channel: 'mock',
        completedAt: now,
        createdAt: now,
        updatedAt: now,
      });
      await setDoc(doc(db, `notification_events/notification-${uid}`), {
        userId: uid,
        type: 'funding_completed',
        title: 'Money added',
        body: 'Your HealthPocket balance has been updated.',
        status: 'queued',
        relatedEntityType: 'funding_transaction',
        relatedEntityId: `funding-${uid}`,
        createdAt: now,
      });
    }
  });

  const ownerDb = verifiedContext('owner').firestore();
  const strangerDb = verifiedContext('stranger').firestore();
  const anonymousDb = environment.unauthenticatedContext().firestore();
  for (const collectionName of [
    'funding_transactions',
    'notification_events',
  ]) {
    const singular = collectionName === 'funding_transactions'
      ? 'funding'
      : 'notification';
    const ownerPath = `${collectionName}/${singular}-owner`;
    const strangerPath = `${collectionName}/${singular}-stranger`;

    await assertSucceeds(getDoc(doc(ownerDb, ownerPath)));
    await assertFails(getDoc(doc(ownerDb, strangerPath)));
    await assertFails(getDoc(doc(strangerDb, ownerPath)));
    await assertFails(getDoc(doc(anonymousDb, ownerPath)));
    await assertSucceeds(getDocs(query(
      collection(ownerDb, collectionName),
      where('userId', '==', 'owner'),
      orderBy('createdAt', 'desc'),
    )));
    await assertFails(getDocs(collection(ownerDb, collectionName)));
    await assertFails(getDocs(query(
      collection(ownerDb, collectionName),
      where('userId', '==', 'stranger'),
    )));
    await assertFails(setDoc(doc(ownerDb, `${collectionName}/forged`), {
      userId: 'owner',
      status: 'completed',
      extraData: 'x'.repeat(10000),
    }));
    await assertFails(updateDoc(doc(ownerDb, ownerPath), {
      userId: 'owner',
      status: 'failed',
    }));
    await assertFails(deleteDoc(doc(ownerDb, ownerPath)));
  }
});

test('wallet and financial history are owner-readable but client-immutable', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'wallets/owner'), {
      schemaVersion: 1,
      userId: 'owner',
      currency: 'NGN',
      availableBalanceKobo: 50000,
      status: 'active',
      version: 1,
      createdAt: now,
      updatedAt: now,
    });
    await setDoc(doc(db, 'ledger_entries/entry-owner-1'), {
      schemaVersion: 1,
      operationId: 'op-owner-1',
      userId: 'owner',
      walletId: 'owner',
      direction: 'credit',
      amountKobo: 50000,
      currency: 'NGN',
      status: 'completed',
      source: 'mock',
      providerReference: null,
      familyPocketId: null,
      reversesLedgerEntryId: null,
      createdAt: now,
    });
    await setDoc(doc(db, 'financial_operations/op-owner-1'), {
      schemaVersion: 1,
      userId: 'owner',
      walletId: 'owner',
      direction: 'credit',
      amountKobo: 50000,
      currency: 'NGN',
      status: 'completed',
      source: 'mock',
      requestFingerprint: 'a'.repeat(64),
      providerReference: null,
      familyPocketId: null,
      ledgerEntryId: 'entry-owner-1',
      failureCode: null,
      createdAt: now,
      updatedAt: now,
    });
  });

  const ownerDb = verifiedContext('owner').firestore();
  const strangerDb = verifiedContext('stranger').firestore();
  const anonymousDb = environment.unauthenticatedContext().firestore();
  for (const path of [
    'wallets/owner',
    'ledger_entries/entry-owner-1',
    'financial_operations/op-owner-1',
  ]) {
    await assertSucceeds(getDoc(doc(ownerDb, path)));
    await assertFails(getDoc(doc(strangerDb, path)));
    await assertFails(getDoc(doc(anonymousDb, path)));
    await assertFails(updateDoc(doc(ownerDb, path), { amountKobo: 999999 }));
  }
  await assertFails(
    setDoc(doc(ownerDb, 'wallets/forged'), {
      userId: 'owner',
      availableBalanceKobo: 999999,
    }),
  );
  await assertFails(
    setDoc(doc(ownerDb, 'ledger_entries/forged'), {
      userId: 'owner',
      walletId: 'owner',
      amountKobo: 999999,
    }),
  );
});

test('financial list queries must be scoped to the authenticated owner', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const uid of ['owner', 'stranger']) {
      await setDoc(doc(db, `ledger_entries/entry-${uid}`), {
        schemaVersion: 1,
        operationId: `op-${uid}`,
        userId: uid,
        walletId: uid,
        direction: 'credit',
        amountKobo: 100,
        currency: 'NGN',
        status: 'completed',
        source: 'mock',
        providerReference: null,
        familyPocketId: null,
        reversesLedgerEntryId: null,
        createdAt: now,
      });
      await setDoc(doc(db, `financial_operations/op-${uid}`), {
        schemaVersion: 1,
        userId: uid,
        walletId: uid,
        direction: 'credit',
        amountKobo: 100,
        currency: 'NGN',
        status: 'completed',
        source: 'mock',
        requestFingerprint: 'b'.repeat(64),
        providerReference: null,
        familyPocketId: null,
        ledgerEntryId: `entry-${uid}`,
        failureCode: null,
        createdAt: now,
        updatedAt: now,
      });
    }
  });
  const ownerDb = verifiedContext('owner').firestore();
  await assertSucceeds(
    getDocs(
      query(
        collection(ownerDb, 'ledger_entries'),
        where('userId', '==', 'owner'),
        orderBy('createdAt', 'desc'),
      ),
    ),
  );
  await assertFails(getDocs(collection(ownerDb, 'ledger_entries')));
  await assertFails(
    getDocs(
      query(
        collection(ownerDb, 'ledger_entries'),
        where('userId', '==', 'stranger'),
      ),
    ),
  );
  await assertSucceeds(
    getDocs(
      query(
        collection(ownerDb, 'financial_operations'),
        where('userId', '==', 'owner'),
        orderBy('createdAt', 'desc'),
      ),
    ),
  );
  await assertFails(getDocs(collection(ownerDb, 'financial_operations')));
});
