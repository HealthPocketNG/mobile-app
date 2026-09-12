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
      contributionAmount: 5000,
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
    await setDoc(doc(db, 'family_pockets/family-secure'), {
      name: 'Secure Family',
      beneficiary: 'The family',
      createdBy: 'admin',
      currency: 'NGN',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    });
    for (const [uid, role] of [
      ['admin', 'admin'],
      ['member', 'contributor'],
      ['beneficiary', 'beneficiary'],
    ]) {
      await setDoc(doc(db, `family_pockets/family-secure/members/${uid}`), {
        pocketId: 'family-secure',
        userId: uid,
        name: uid,
        role,
        invitationStatus: 'accepted',
        joinedAt: now,
      });
    }
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
      updatedAt: Timestamp.fromDate(new Date('2026-01-02T00:00:00Z')),
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
  await assertSucceeds(
    setDoc(doc(ownerDb, 'users/owner'), {
      ...profileFor('owner'),
      fullName: 'Ada Nwosu',
    }),
  );
  const batch = writeBatch(ownerDb);
  batch.set(doc(ownerDb, 'family_pockets/family-1'), {
    name: 'Nwosu Family',
    beneficiary: 'The family',
    createdBy: 'owner',
    currency: 'NGN',
    status: 'active',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batch.set(doc(ownerDb, 'family_pockets/family-1/members/owner'), {
    pocketId: 'family-1',
    userId: 'owner',
    name: 'Ada Nwosu',
    role: 'admin',
    invitationStatus: 'accepted',
    joinedAt: serverTimestamp(),
  });

  await assertSucceeds(batch.commit());
  await assertSucceeds(
    getDocs(query(
      collectionGroup(ownerDb, 'members'),
      where('userId', '==', 'owner'),
      where('invitationStatus', '==', 'accepted'),
      orderBy('joinedAt', 'desc'),
    )),
  );
  await assertSucceeds(
    getDocs(collection(ownerDb, 'family_pockets/family-1/members')),
  );
  await assertFails(
    getDocs(
      collection(
        verifiedContext('stranger').firestore(),
        'family_pockets/family-1/members',
      ),
    ),
  );
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
      role: 'admin',
      invitationStatus: 'accepted',
      joinedAt: now,
    });
    await setDoc(doc(db, 'family_pockets/family-1/members/member'), {
      pocketId: 'family-1',
      userId: 'member',
      name: 'Member',
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

  await assertFails(
    updateDoc(doc(verifiedContext('admin').firestore(), 'family_pockets/family-1/members/member'), {
      role: 'admin',
    }),
  );

  const adminDb = verifiedContext('admin').firestore();
  await assertSucceeds(
    updateDoc(doc(adminDb, 'family_pockets/family-1/members/member'), {
      invitationStatus: 'removed',
      removedAt: serverTimestamp(),
    }),
  );
});

test('Family invitations keep email PII admin-only', async () => {
  await seedFamilyPocket();
  const adminDb = verifiedContext('admin').firestore();
  const memberDb = verifiedContext('member').firestore();
  const invitePath = 'family_pockets/family-secure/invites/invite-1';
  await assertSucceeds(
    setDoc(doc(adminDb, invitePath), {
      pocketId: 'family-secure',
      name: 'Tola Family',
      email: 'tola@example.com',
      role: 'contributor',
      status: 'pending',
      createdBy: 'admin',
      createdAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(getDoc(doc(adminDb, invitePath)));
  await assertFails(getDoc(doc(memberDb, invitePath)));
  await assertFails(
    setDoc(doc(memberDb, 'family_pockets/family-secure/invites/attack'), {
      pocketId: 'family-secure',
      name: 'Attack',
      email: 'attack@example.com',
      role: 'contributor',
      status: 'pending',
      createdBy: 'member',
      createdAt: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(doc(adminDb, 'family_pockets/family-secure/invites/polluted'), {
      pocketId: 'family-secure',
      name: 'x'.repeat(101),
      email: 'bad@example.com',
      role: 'admin',
      status: 'accepted',
      createdBy: 'admin',
      createdAt: now,
      extraData: true,
    }),
  );
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
      invitationStatus: 'removed',
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
