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
  doc,
  getDoc,
  getDocs,
  query,
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
  notificationPreferences: {
    savingsReminders: true,
    familyActivity: true,
    healthReminders: true,
    productUpdates: false,
  },
  createdAt: now,
  updatedAt: now,
});

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

test('an owner can create and edit the default savings plan', async () => {
  const ownerDb = verifiedContext('owner').firestore();
  await assertSucceeds(
    setDoc(doc(ownerDb, 'personal_health_pockets/personal-owner'), {
      userId: 'owner',
      currency: 'NGN',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    }),
  );
  await assertSucceeds(
    setDoc(doc(ownerDb, 'savings_plans/personal-plan-owner'), {
      userId: 'owner',
      personalHealthPocketId: 'personal-owner',
      contributionAmount: 5000,
      frequency: 'weekly',
      startDate: now,
      nextContributionDate: null,
      status: 'active',
      fundingSourceId: null,
      createdAt: now,
      updatedAt: now,
    }),
  );
  await assertSucceeds(
    updateDoc(doc(ownerDb, 'savings_plans/personal-plan-owner'), {
      contributionAmount: 7500,
      frequency: 'monthly',
      status: 'paused',
      updatedAt: Timestamp.fromDate(new Date('2026-01-02T00:00:00Z')),
    }),
  );
});

test('Family Pocket and founding admin are created atomically', async () => {
  const ownerDb = verifiedContext('owner').firestore();
  const batch = writeBatch(ownerDb);
  batch.set(doc(ownerDb, 'family_pockets/family-1'), {
    name: 'Nwosu Family',
    beneficiary: 'The family',
    createdBy: 'owner',
    currency: 'NGN',
    status: 'active',
    createdAt: now,
    updatedAt: now,
  });
  batch.set(doc(ownerDb, 'family_pockets/family-1/members/owner'), {
    pocketId: 'family-1',
    userId: 'owner',
    name: 'Ada Nwosu',
    email: 'ada@example.com',
    role: 'admin',
    invitationStatus: 'accepted',
    joinedAt: now,
  });

  await assertSucceeds(batch.commit());
});

test('only an admin can soft-remove a Family Pocket contributor', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'family_pockets/family-1'), {
      name: 'Nwosu Family',
      beneficiary: 'The family',
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
      email: 'admin@example.com',
      role: 'admin',
      invitationStatus: 'accepted',
      joinedAt: now,
    });
    await setDoc(doc(db, 'family_pockets/family-1/members/member'), {
      pocketId: 'family-1',
      userId: 'member',
      name: 'Member',
      email: 'member@example.com',
      role: 'contributor',
      invitationStatus: 'accepted',
      joinedAt: now,
    });
  });

  const contributorDb = verifiedContext('member').firestore();
  await assertFails(
    updateDoc(doc(contributorDb, 'family_pockets/family-1/members/member'), {
      invitationStatus: 'removed',
      removedAt: now,
    }),
  );

  const adminDb = verifiedContext('admin').firestore();
  await assertSucceeds(
    updateDoc(doc(adminDb, 'family_pockets/family-1/members/member'), {
      invitationStatus: 'removed',
      removedAt: now,
    }),
  );
});

test('contributions are append-only and scoped to an owned pocket', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'personal_health_pockets/personal-1'), {
      userId: 'owner',
      currency: 'NGN',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    });
  });
  const ownerDb = verifiedContext('owner').firestore();
  const contribution = {
    contributorUserId: 'owner',
    personalHealthPocketId: 'personal-1',
    amount: 5000,
    currency: 'NGN',
    status: 'completed',
    source: 'manual',
    createdAt: now,
  };

  await assertSucceeds(
    setDoc(doc(ownerDb, 'contributions/contribution-1'), contribution),
  );
  await assertFails(
    updateDoc(doc(ownerDb, 'contributions/contribution-1'), { amount: 6000 }),
  );

  const strangerDb = verifiedContext('stranger').firestore();
  await assertFails(
    setDoc(doc(strangerDb, 'contributions/contribution-2'), {
      ...contribution,
      contributorUserId: 'stranger',
    }),
  );
});

test('a non-member cannot write into a Family Pocket activity feed', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'family_pockets/family-1'), {
      name: 'Nwosu Family',
      beneficiary: 'The family',
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

test('a verified phone identity remains a post-MVP authorization extension', async () => {
  const phoneDb = environment.authenticatedContext('phone-user', {
    phone_number: '+2348012345678',
  }).firestore();

  await assertSucceeds(
    setDoc(doc(phoneDb, 'users/phone-user'), {
      ...profileFor('phone-user'),
      email: '',
      emailVerified: false,
    }),
  );
  await assertSucceeds(
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
