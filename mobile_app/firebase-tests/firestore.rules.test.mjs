import { after, before, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-healthpocket';
const now = Timestamp.fromDate(new Date('2026-01-01T00:00:00Z'));
let environment;

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
  const ownerDb = environment.authenticatedContext('owner').firestore();
  const strangerDb = environment.authenticatedContext('stranger').firestore();
  const profile = {
    userId: 'owner',
    createdAt: now,
    updatedAt: now,
  };

  await assertSucceeds(setDoc(doc(ownerDb, 'users/owner'), profile));
  await assertSucceeds(getDoc(doc(ownerDb, 'users/owner')));
  await assertFails(getDoc(doc(strangerDb, 'users/owner')));
  await assertFails(
    getDoc(doc(environment.unauthenticatedContext().firestore(), 'users/owner')),
  );
});

test('Family Pocket and founding admin are created atomically', async () => {
  const ownerDb = environment.authenticatedContext('owner').firestore();
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

  const contributorDb = environment.authenticatedContext('member').firestore();
  await assertFails(
    updateDoc(doc(contributorDb, 'family_pockets/family-1/members/member'), {
      invitationStatus: 'removed',
      removedAt: now,
    }),
  );

  const adminDb = environment.authenticatedContext('admin').firestore();
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
  const ownerDb = environment.authenticatedContext('owner').firestore();
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

  const strangerDb = environment.authenticatedContext('stranger').firestore();
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
  const strangerDb = environment.authenticatedContext('stranger').firestore();

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
