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
  documentId,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  startAfter,
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

const seedAuthoritativeFamilyPocket = async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'family_pockets/family-modern'), {
      schemaVersion: 2,
      name: 'Modern Family',
      description: 'Shared healthcare savings',
      imagePath: null,
      frequency: 'monthly',
      defaultContributionAmountKobo: 50000,
      ownerId: 'modern-owner',
      createdBy: 'modern-owner',
      currency: 'NGN',
      status: 'active',
      balanceKobo: 250000,
      version: 1,
      requestFingerprint: 'a'.repeat(64),
      createdAt: now,
      updatedAt: now,
      closedAt: null,
    });
    for (const [uid, role] of [
      ['modern-owner', 'owner'],
      ['modern-admin', 'admin'],
      ['modern-member', 'member'],
      ['modern-observer', 'member'],
    ]) {
      await setDoc(doc(db, `family_pockets/family-modern/members/${uid}`), {
        schemaVersion: 2,
        pocketId: 'family-modern',
        userId: uid,
        invitationId: null,
        name: uid,
        role,
        permissions: {
          canContribute: uid !== 'modern-observer',
          canInvite: role !== 'member',
          canManageMembers: role !== 'member',
        },
        status: 'active',
        lifetimeContributionKobo: 0,
        joinedAt: now,
        updatedAt: now,
        leftAt: null,
        removedAt: null,
      });
    }
  });
};

const healthcareProvider = ({
  name,
  category,
  partnerStatus,
  state,
  city,
  active = true,
  locationCell,
}) => ({
  schemaVersion: 1,
  name,
  normalizedName: name.toLowerCase(),
  category,
  partnerStatus,
  address: `${city}, ${state}`,
  state,
  city,
  coordinates: { latitude: 6.6018, longitude: 3.3515 },
  locationCell,
  contact: {
    phone: null,
    email: null,
    website: null,
  },
  openingInformation: null,
  logoUrl: null,
  imageUrls: [],
  services: ['Consultation'],
  searchPrefixes: [name[0].toLowerCase(), name.slice(0, 4).toLowerCase()],
  active,
  createdAt: now,
  updatedAt: now,
  deactivatedAt: active ? null : now,
});

const seedHealthcareProviders = async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(
      doc(db, 'healthcare_providers/evercare-ikeja'),
      healthcareProvider({
        name: 'Evercare Hospital',
        category: 'hospital',
        partnerStatus: 'partner',
        state: 'Lagos',
        city: 'Ikeja',
        locationCell: ['lagos', 'lagos-ikeja'],
      }),
    );
    await setDoc(
      doc(db, 'healthcare_providers/central-pharmacy-yaba'),
      healthcareProvider({
        name: 'Central Pharmacy',
        category: 'pharmacy',
        partnerStatus: 'non_partner',
        state: 'Lagos',
        city: 'Yaba',
        locationCell: ['lagos', 'lagos-yaba'],
      }),
    );
    await setDoc(
      doc(db, 'healthcare_providers/retired-clinic'),
      healthcareProvider({
        name: 'Retired Clinic',
        category: 'clinic',
        partnerStatus: 'partner',
        state: 'Lagos',
        city: 'Ikeja',
        active: false,
        locationCell: ['lagos', 'lagos-ikeja'],
      }),
    );
  });
};

const coverageItem = ({
  name,
  category,
  indicativePriceKobo,
  active = true,
  sourceName = 'HealthPocket partner pricing',
  sourceReference = null,
  providerId = null,
  state = 'Lagos',
  city = 'Ikeja',
}) => ({
  schemaVersion: 1,
  name,
  normalizedName: name.toLowerCase(),
  category,
  indicativePriceKobo,
  currency: 'NGN',
  priceType: 'indicative_estimate',
  sourceName,
  sourceReference,
  providerId,
  locationContext: { state, city },
  disclaimer: 'Indicative estimate only. Actual healthcare costs may vary.',
  active,
  createdAt: now,
  updatedAt: now,
  lastUpdatedAt: now,
  deactivatedAt: active ? null : now,
});

const seedCoverageItems = async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(
      doc(db, 'coverage_items/basic-consultation'),
      coverageItem({
        name: 'Basic consultation',
        category: 'consultation',
        indicativePriceKobo: 500000,
      }),
    );
    await setDoc(
      doc(db, 'coverage_items/basic-diagnostics'),
      coverageItem({
        name: 'Basic diagnostics',
        category: 'diagnostics',
        indicativePriceKobo: 750000,
        sourceReference: 'partner-price-list-2026-10',
      }),
    );
    await setDoc(
      doc(db, 'coverage_items/stale-pharmacy-estimate'),
      coverageItem({
        name: 'Stale pharmacy estimate',
        category: 'pharmacy',
        indicativePriceKobo: 250000,
        active: false,
      }),
    );
  });
};

const healthcarePayment = (uid, flowType, overrides = {}) => ({
  schemaVersion: 1,
  userId: uid,
  paymentAttemptId: `attempt-${uid}-${flowType}`,
  flowType,
  providerId: flowType === 'partner' ? 'evercare-ikeja' : 'community-chemist',
  providerName: flowType === 'partner'
    ? 'Evercare Hospital'
    : 'Community Chemist',
  providerCategory: flowType === 'partner' ? 'hospital' : 'pharmacy',
  providerCity: 'Ikeja',
  providerState: 'Lagos',
  amountKobo: 250000,
  currency: 'NGN',
  status: 'completed',
  verificationStatus: flowType === 'partner' ? 'not_required' : 'verified',
  verificationSource: flowType === 'partner' ? null : 'beta_mock',
  verificationReference: flowType === 'partner'
    ? null
    : `verification-${uid}`,
  failureCode: null,
  paymentProvider: 'mock',
  providerReference: `provider-${uid}-${flowType}`,
  ledgerOperationId: `operation-${uid}-${flowType}`,
  ledgerEntryId: `entry-${uid}-${flowType}`,
  transactionReference: `healthcare-${uid}-${flowType}`,
  receiptNumber: `HPC-${uid.toUpperCase()}-${flowType.toUpperCase()}`,
  description: 'Healthcare payment',
  channel: 'mock',
  beneficiary: flowType === 'partner'
    ? null
    : {
        accountNumberLast4: '1234',
        bankCode: '999',
        bankName: 'Mock Bank',
        accountName: 'Community Chemist',
        beneficiaryReference: `beneficiary-${uid}`,
      },
  requestFingerprint: 'c'.repeat(64),
  createdAt: now,
  updatedAt: now,
  completedAt: now,
  ...overrides,
});

const seedHealthcarePayments = async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(
      doc(db, 'healthcare_payments/payment-owner-partner'),
      healthcarePayment('owner', 'partner'),
    );
    await setDoc(
      doc(db, 'healthcare_payments/payment-owner-non-partner'),
      healthcarePayment('owner', 'non_partner'),
    );
    await setDoc(
      doc(db, 'healthcare_payments/payment-stranger-partner'),
      healthcarePayment('stranger', 'partner'),
    );
  });
};

const receiptRecord = (
  uid,
  receiptNumber,
  transactionType,
  overrides = {},
) => ({
  schemaVersion: 1,
  receiptNumber,
  healthPocketReferenceId: receiptNumber,
  userId: uid,
  transactionId: `transaction-${uid}-${transactionType}`,
  transactionType,
  transactionReference: `reference-${uid}-${transactionType}`,
  status: 'completed',
  amountKobo: 250000,
  currency: 'NGN',
  provider: transactionType === 'healthcare_payment'
    ? {
        id: 'evercare-ikeja',
        name: 'Evercare Hospital',
        category: 'hospital',
        city: 'Ikeja',
        state: 'Lagos',
      }
    : { id: 'mock', name: 'HealthPocket mock payment provider' },
  recipient: transactionType === 'healthcare_payment'
    ? { id: 'evercare-ikeja', name: 'Evercare Hospital' }
    : { id: 'healthpocket_wallet', name: 'HealthPocket Wallet' },
  paymentMethod: {
    type: transactionType === 'healthcare_payment'
      ? 'healthpocket_partner'
      : 'payment_gateway',
    provider: 'mock',
    channel: 'mock',
    externalReference: `provider-${uid}-${transactionType}`,
  },
  ...(transactionType === 'healthcare_payment'
    ? { flowType: 'partner' }
    : {}),
  description: transactionType === 'healthcare_payment'
    ? 'Healthcare payment'
    : 'HealthPocket wallet funding',
  ledgerOperationId: `operation-${uid}-${transactionType}`,
  ledgerEntryId: transactionType === 'healthcare_payment'
    ? `entry-${uid}-${transactionType}`
    : null,
  issuedAt: now,
  createdAt: now,
  sourceFingerprint: 'd'.repeat(64),
  ...overrides,
});

const seedReceipts = async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(
      doc(db, 'receipts/HPF-A1B2C3D4E5F6'),
      receiptRecord('owner', 'HPF-A1B2C3D4E5F6', 'wallet_funding'),
    );
    await setDoc(
      doc(db, 'receipts/HPC-1234ABCDEF56'),
      receiptRecord('owner', 'HPC-1234ABCDEF56', 'healthcare_payment'),
    );
    await setDoc(
      doc(db, 'receipts/HPC-ABCDEF123456'),
      receiptRecord('stranger', 'HPC-ABCDEF123456', 'healthcare_payment'),
    );
  });
};

const seedActivityHistory = async () => {
  await seedAuthoritativeFamilyPocket();
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const activity = ({
      userId,
      activityType,
      relatedEntityId,
      createdAt,
      familyPocketId,
    }) => ({
      userId,
      activityType,
      metadata: { amountKobo: 250000, currency: 'NGN' },
      relatedEntityType: activityType.includes('healthcare')
        ? 'healthcare_payment'
        : 'family_contribution',
      relatedEntityId,
      ...(familyPocketId ? { familyPocketId } : {}),
      createdAt,
    });

    await setDoc(doc(db, 'activities/personal-owner-healthcare'), activity({
      userId: 'owner',
      activityType: 'healthcare_payment_completed',
      relatedEntityId: 'payment-owner-partner',
      createdAt: Timestamp.fromDate(new Date('2026-01-05T12:00:00Z')),
    }));
    await setDoc(doc(db, 'activities/personal-owner-funding'), activity({
      userId: 'owner',
      activityType: 'funding_completed',
      relatedEntityId: 'funding-owner',
      createdAt: Timestamp.fromDate(new Date('2026-01-03T12:00:00Z')),
    }));
    await setDoc(doc(db, 'activities/personal-stranger-healthcare'), activity({
      userId: 'stranger',
      activityType: 'healthcare_payment_completed',
      relatedEntityId: 'payment-stranger-partner',
      createdAt: Timestamp.fromDate(new Date('2026-01-04T12:00:00Z')),
    }));
    await setDoc(doc(db, 'activities/family-modern-contribution'), activity({
      userId: 'modern-member',
      activityType: 'family_contribution_completed',
      relatedEntityId: 'family-contribution-modern',
      familyPocketId: 'family-modern',
      createdAt: Timestamp.fromDate(new Date('2026-01-04T12:00:00Z')),
    }));
    await setDoc(doc(db, 'activities/family-modern-payment'), activity({
      userId: 'modern-owner',
      activityType: 'family_healthcare_payment_completed',
      relatedEntityId: 'family-payment-modern',
      familyPocketId: 'family-modern',
      createdAt: Timestamp.fromDate(new Date('2026-01-02T12:00:00Z')),
    }));
    await setDoc(doc(db, 'family_pockets/family-other'), {
      ownerId: 'other-owner',
      createdBy: 'other-owner',
      status: 'active',
    });
    await setDoc(doc(db, 'family_pockets/family-other/members/other-owner'), {
      pocketId: 'family-other',
      userId: 'other-owner',
      role: 'owner',
      status: 'active',
      removedAt: null,
      leftAt: null,
    });
    await setDoc(doc(db, 'activities/family-other-contribution'), activity({
      userId: 'other-owner',
      activityType: 'family_contribution_completed',
      relatedEntityId: 'family-contribution-other',
      familyPocketId: 'family-other',
      createdAt: Timestamp.fromDate(new Date('2026-01-03T12:00:00Z')),
    }));
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

test('active members can discover and read only their Family Pockets', async () => {
  await seedFamilyPocket();
  const memberDb = verifiedContext('member').firestore();
  const strangerDb = verifiedContext('stranger').firestore();

  await assertSucceeds(
    getDocs(query(
      collectionGroup(memberDb, 'members'),
      where('userId', '==', 'member'),
      where('status', '==', 'accepted'),
      orderBy('joinedAt', 'desc'),
    )),
  );
  await assertSucceeds(getDoc(
    doc(memberDb, 'family_pockets/family-secure'),
  ));
  await assertSucceeds(
    getDocs(collection(memberDb, 'family_pockets/family-secure/members')),
  );
  await assertFails(getDoc(
    doc(strangerDb, 'family_pockets/family-secure'),
  ));
  await assertFails(getDocs(
    collection(strangerDb, 'family_pockets/family-secure/members'),
  ));
  await assertFails(getDocs(collection(strangerDb, 'family_pockets')));
});

test('authoritative owner, admin and member roles have scoped read access', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'family_pockets/family-modern'), {
      schemaVersion: 2,
      name: 'Modern Family',
      description: 'Shared healthcare savings',
      imagePath: null,
      frequency: 'monthly',
      defaultContributionAmountKobo: 50000,
      ownerId: 'modern-owner',
      createdBy: 'modern-owner',
      currency: 'NGN',
      status: 'active',
      balanceKobo: 250000,
      version: 1,
      requestFingerprint: 'a'.repeat(64),
      createdAt: now,
      updatedAt: now,
      closedAt: null,
    });
    for (const [uid, role] of [
      ['modern-owner', 'owner'],
      ['modern-admin', 'admin'],
      ['modern-member', 'member'],
      ['modern-observer', 'member'],
    ]) {
      await setDoc(doc(db, `family_pockets/family-modern/members/${uid}`), {
        schemaVersion: 2,
        pocketId: 'family-modern',
        userId: uid,
        invitationId: null,
        name: uid,
        role,
        permissions: {
          canContribute: uid !== 'modern-observer',
          canInvite: role !== 'member',
          canManageMembers: role !== 'member',
        },
        status: 'active',
        lifetimeContributionKobo: 0,
        joinedAt: now,
        updatedAt: now,
        leftAt: null,
        removedAt: null,
      });
    }
  });

  for (const uid of ['modern-owner', 'modern-admin', 'modern-member']) {
    const db = verifiedContext(uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'family_pockets/family-modern')));
    await assertSucceeds(getDocs(query(
      collectionGroup(db, 'members'),
      where('userId', '==', uid),
      where('status', '==', 'active'),
      orderBy('joinedAt', 'desc'),
    )));
    await assertSucceeds(getDocs(
      collection(db, 'family_pockets/family-modern/members'),
    ));
  }

  const strangerDb = verifiedContext('modern-stranger').firestore();
  await assertFails(getDoc(doc(strangerDb, 'family_pockets/family-modern')));
  await assertFails(getDoc(
    doc(strangerDb, 'family_pockets/family-modern/members/modern-member'),
  ));
});

test('Family financial records are member-scoped and backend-write-only', async () => {
  await seedAuthoritativeFamilyPocket();
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'family_contribution_attempts/attempt-modern'), {
      schemaVersion: 1,
      pocketId: 'family-modern',
      contributorUserId: 'modern-member',
      amountKobo: 250000,
      currency: 'NGN',
      status: 'completed',
      provider: 'mock',
      providerReference: 'mock-modern',
      requestFingerprint: 'b'.repeat(64),
      ledgerEntryId: 'entry-modern',
      createdAt: now,
      updatedAt: now,
      completedAt: now,
      failureCode: null,
    });
    await setDoc(doc(db, 'family_ledger_entries/entry-modern'), {
      schemaVersion: 1,
      familyPocketId: 'family-modern',
      contributorUserId: 'modern-member',
      contributionAttemptId: 'attempt-modern',
      direction: 'credit',
      amountKobo: 250000,
      currency: 'NGN',
      status: 'completed',
      providerReference: 'mock-modern',
      createdAt: now,
    });
    await setDoc(doc(db, 'activities/family-activity-modern'), {
      userId: 'modern-member',
      familyPocketId: 'family-modern',
      activityType: 'family_contribution_completed',
      relatedEntityType: 'family_contribution',
      relatedEntityId: 'attempt-modern',
      metadata: { amountKobo: 250000, currency: 'NGN' },
      createdAt: now,
    });
    await setDoc(doc(db, 'notification_events/family-notice-modern'), {
      userId: 'modern-member',
      familyPocketId: 'family-modern',
      type: 'family_contribution_completed',
      title: 'Family Pocket contribution received',
      body: 'Your Family Pocket balance has been updated.',
      relatedEntityId: 'attempt-modern',
      createdAt: now,
    });
  });

  const ownerDb = verifiedContext('modern-owner').firestore();
  const memberDb = verifiedContext('modern-member').firestore();
  const observerDb = verifiedContext('modern-observer').firestore();
  const strangerDb = verifiedContext('modern-stranger').firestore();
  await assertSucceeds(getDoc(
    doc(memberDb, 'family_contribution_attempts/attempt-modern'),
  ));
  await assertSucceeds(getDoc(
    doc(ownerDb, 'family_contribution_attempts/attempt-modern'),
  ));
  await assertFails(getDoc(
    doc(observerDb, 'family_contribution_attempts/attempt-modern'),
  ));
  await assertFails(getDoc(
    doc(strangerDb, 'family_contribution_attempts/attempt-modern'),
  ));
  await assertSucceeds(getDocs(query(
    collection(ownerDb, 'family_contribution_attempts'),
    where('pocketId', '==', 'family-modern'),
    orderBy('createdAt', 'desc'),
  )));
  await assertSucceeds(getDocs(query(
    collection(memberDb, 'family_contribution_attempts'),
    where('pocketId', '==', 'family-modern'),
    where('contributorUserId', '==', 'modern-member'),
    orderBy('createdAt', 'desc'),
  )));
  await assertFails(getDocs(query(
    collection(observerDb, 'family_contribution_attempts'),
    where('pocketId', '==', 'family-modern'),
  )));
  await assertFails(getDocs(
    collection(memberDb, 'family_contribution_attempts'),
  ));
  for (const db of [ownerDb, memberDb, observerDb]) {
    await assertSucceeds(getDoc(doc(db, 'family_ledger_entries/entry-modern')));
    await assertSucceeds(getDocs(query(
      collection(db, 'family_ledger_entries'),
      where('familyPocketId', '==', 'family-modern'),
      orderBy('createdAt', 'desc'),
    )));
  }
  await assertFails(getDoc(
    doc(strangerDb, 'family_ledger_entries/entry-modern'),
  ));
  await assertFails(getDocs(collection(memberDb, 'family_ledger_entries')));
  await assertSucceeds(getDoc(
    doc(observerDb, 'activities/family-activity-modern'),
  ));
  await assertFails(getDoc(
    doc(strangerDb, 'activities/family-activity-modern'),
  ));
  await assertSucceeds(getDoc(
    doc(memberDb, 'notification_events/family-notice-modern'),
  ));
  await assertFails(getDoc(
    doc(observerDb, 'notification_events/family-notice-modern'),
  ));
  await assertFails(setDoc(
    doc(memberDb, 'family_contribution_attempts/forged'),
    {
      pocketId: 'family-modern',
      contributorUserId: 'modern-member',
      amountKobo: 999999999,
      status: 'completed',
    },
  ));
  await assertFails(updateDoc(
    doc(ownerDb, 'family_ledger_entries/entry-modern'),
    { amountKobo: 999999999 },
  ));
  await assertFails(deleteDoc(
    doc(ownerDb, 'family_ledger_entries/entry-modern'),
  ));
});

test('Family Pocket membership and authority changes are backend-only', async () => {
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
  await assertFails(
    updateDoc(doc(adminDb, 'family_pockets/family-1/members/member'), {
      status: 'removed',
      removedAt: serverTimestamp(),
    }),
  );
  await assertFails(updateDoc(
    doc(adminDb, 'family_pockets/family-1/members/admin'),
    { status: 'removed', removedAt: serverTimestamp() },
  ));
  await assertFails(deleteDoc(
    doc(adminDb, 'family_pockets/family-1/members/admin'),
  ));
  await assertFails(updateDoc(doc(adminDb, 'family_pockets/family-1'), {
    balanceKobo: 999999999,
    version: 999,
  }));
});

test('an invitee can discover and accept only their verified-email invite', async () => {
  await seedFamilyPocket();
  const adminDb = verifiedContext('admin').firestore();
  const memberDb = verifiedContext('member').firestore();
  const inviteeDb = verifiedContext('invitee', 'tola@example.com').firestore();
  const inviteId = 'invite_admin_00000000000000000000000000000001';
  const invitePath = `family_pockets/family-secure/invites/${inviteId}`;
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, invitePath), {
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
      createdAt: now,
      expiresAt: Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000),
    });
    await setDoc(doc(db, 'family_invite_keys/private-key'), {
      pocketId: 'family-secure',
      inviteId,
      emailHash: 'private',
      status: 'pending',
      updatedAt: now,
    });
    await setDoc(doc(db, 'family_invite_codes/private-code'), {
      pocketId: 'family-secure',
      inviteId,
      expiresAt: now,
      createdAt: now,
    });
  });
  await assertSucceeds(getDoc(doc(adminDb, invitePath)));
  await assertFails(getDoc(doc(memberDb, invitePath)));
  await assertSucceeds(getDoc(doc(inviteeDb, invitePath)));
  const unverifiedInviteeDb = environment.authenticatedContext(
    'unverified-invitee',
    { email: 'tola@example.com', email_verified: false },
  ).firestore();
  await assertFails(getDoc(doc(unverifiedInviteeDb, invitePath)));
  for (const internalPath of [
    'family_invite_keys/private-key',
    'family_invite_codes/private-code',
  ]) {
    await assertFails(getDoc(doc(inviteeDb, internalPath)));
    await assertFails(getDoc(doc(adminDb, internalPath)));
  }
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
  await assertFails(getDocs(collectionGroup(inviteeDb, 'invites')));
  await assertFails(
    getDocs(query(
      collectionGroup(memberDb, 'invites'),
      where('email', '==', 'tola@example.com'),
      where('status', '==', 'pending'),
      orderBy('createdAt', 'desc'),
    )),
  );

  await assertFails(updateDoc(doc(inviteeDb, invitePath), {
    status: 'accepted',
    respondedBy: 'invitee',
    respondedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(
    doc(inviteeDb, 'family_pockets/family-secure/members/invitee'),
    {
      pocketId: 'family-secure',
      userId: 'invitee',
      invitationId: inviteId,
      name: 'HealthPocket User',
      role: 'owner',
      canContribute: true,
      isBeneficiary: false,
      status: 'accepted',
      joinedAt: serverTimestamp(),
    },
  ));
  await assertFails(getDoc(doc(inviteeDb, 'family_pockets/family-secure')));

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

test('beneficiary slots are member-readable and backend-write-only', async () => {
  await seedFamilyPocket();
  const adminDb = verifiedContext('admin').firestore();
  const memberDb = verifiedContext('member').firestore();
  const strangerDb = verifiedContext('stranger').firestore();
  const slotPath = 'family_pockets/family-secure/beneficiary_slots/1';

  await assertSucceeds(getDoc(doc(memberDb, slotPath)));
  await assertFails(getDoc(doc(strangerDb, slotPath)));
  await assertFails(setDoc(
    doc(adminDb, 'family_pockets/family-secure/beneficiary_slots/2'),
    {
      pocketId: 'family-secure',
      slot: 2,
      state: 'reserved',
      invitationId: 'forged-invite',
      updatedAt: serverTimestamp(),
    },
  ));
  await assertFails(updateDoc(doc(memberDb, slotPath), {
    state: 'accepted',
    memberUserId: 'member',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(deleteDoc(doc(adminDb, slotPath)));
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

  await assertFails(
    updateDoc(doc(adminDb, 'family_pockets/family-secure/members/member'), {
      status: 'removed',
      removedAt: serverTimestamp(),
    }),
  );
  await environment.withSecurityRulesDisabled(async (context) => {
    await updateDoc(
      doc(context.firestore(), 'family_pockets/family-secure/members/member'),
      { status: 'removed', removedAt: now },
    );
  });
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

test('owner activity queries support type, date and cursor pagination', async () => {
  await seedActivityHistory();
  const ownerDb = verifiedContext('owner').firestore();
  const activities = collection(ownerDb, 'activities');

  await assertSucceeds(
    getDoc(doc(ownerDb, 'activities/personal-owner-healthcare')),
  );
  const page = await assertSucceeds(getDocs(query(
    activities,
    where('userId', '==', 'owner'),
    where('activityType', '==', 'healthcare_payment_completed'),
    where(
      'createdAt',
      '>=',
      Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
    ),
    where(
      'createdAt',
      '<=',
      Timestamp.fromDate(new Date('2026-01-31T23:59:59Z')),
    ),
    orderBy('createdAt', 'desc'),
    startAfter(Timestamp.fromDate(new Date('2026-01-06T00:00:00Z'))),
    limit(1),
  )));
  if (page.size !== 1) {
    throw new Error(`Expected one owner activity, got ${page.size}.`);
  }
});

test('active members can page only their Family Pocket activity', async () => {
  await seedActivityHistory();
  const memberDb = verifiedContext('modern-member').firestore();
  const activities = collection(memberDb, 'activities');

  await assertSucceeds(
    getDoc(doc(memberDb, 'activities/family-modern-contribution')),
  );
  const page = await assertSucceeds(getDocs(query(
    activities,
    where('familyPocketId', '==', 'family-modern'),
    where('activityType', '==', 'family_contribution_completed'),
    where(
      'createdAt',
      '>=',
      Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
    ),
    where(
      'createdAt',
      '<=',
      Timestamp.fromDate(new Date('2026-01-31T23:59:59Z')),
    ),
    orderBy('createdAt', 'desc'),
    startAfter(Timestamp.fromDate(new Date('2026-01-06T00:00:00Z'))),
    limit(1),
  )));
  if (page.size !== 1) {
    throw new Error(`Expected one Family activity, got ${page.size}.`);
  }
});

test('activity history denies query-scope attacks and every client write', async () => {
  await seedActivityHistory();
  const ownerDb = verifiedContext('owner').firestore();
  const memberDb = verifiedContext('modern-member').firestore();
  const strangerDb = verifiedContext('stranger').firestore();
  const anonymousDb = environment.unauthenticatedContext().firestore();

  await assertFails(
    getDoc(doc(ownerDb, 'activities/personal-stranger-healthcare')),
  );
  await assertFails(
    getDoc(doc(ownerDb, 'activities/family-modern-contribution')),
  );
  await assertFails(
    getDoc(doc(memberDb, 'activities/family-other-contribution')),
  );
  await assertFails(getDocs(collection(ownerDb, 'activities')));
  await assertFails(getDocs(query(
    collection(ownerDb, 'activities'),
    where('activityType', '==', 'healthcare_payment_completed'),
    orderBy('createdAt', 'desc'),
  )));
  await assertFails(getDocs(query(
    collection(ownerDb, 'activities'),
    where('userId', '==', 'stranger'),
    orderBy('createdAt', 'desc'),
  )));
  await assertFails(getDocs(query(
    collection(memberDb, 'activities'),
    where('familyPocketId', '==', 'family-other'),
    orderBy('createdAt', 'desc'),
  )));
  await assertFails(getDocs(query(
    collection(strangerDb, 'activities'),
    where('familyPocketId', '==', 'family-modern'),
    orderBy('createdAt', 'desc'),
  )));
  await assertFails(getDocs(query(
    collection(anonymousDb, 'activities'),
    where('userId', '==', 'owner'),
    orderBy('createdAt', 'desc'),
  )));

  await assertFails(setDoc(doc(ownerDb, 'activities/client-forged'), {
    userId: 'owner',
    activityType: 'healthcare_payment_completed',
    metadata: { amountKobo: 99999999, currency: 'NGN' },
    relatedEntityType: 'healthcare_payment',
    relatedEntityId: 'forged-payment',
    createdAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(
    doc(ownerDb, 'activities/personal-owner-healthcare'),
    { activityType: 'healthcare_payment_reversed' },
  ));
  await assertFails(deleteDoc(
    doc(ownerDb, 'activities/personal-owner-healthcare'),
  ));
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

test('verified Google users can read active healthcare providers', async () => {
  await seedHealthcareProviders();
  const userDb = verifiedContext('directory-user').firestore();

  await assertSucceeds(
    getDoc(doc(userDb, 'healthcare_providers/evercare-ikeja')),
  );
  await assertFails(
    getDoc(doc(userDb, 'healthcare_providers/retired-clinic')),
  );
  await assertFails(
    getDoc(doc(userDb, 'healthcare_providers/guessed-inactive-provider')),
  );
});

test('healthcare provider list queries must be constrained to active records', async () => {
  await seedHealthcareProviders();
  const userDb = verifiedContext('directory-user').firestore();
  const providers = collection(userDb, 'healthcare_providers');

  const allActive = await assertSucceeds(getDocs(query(
    providers,
    where('active', '==', true),
    orderBy('normalizedName'),
    limit(20),
  )));
  if (allActive.size !== 2) {
    throw new Error(`Expected two active providers, got ${allActive.size}.`);
  }

  const filtered = await assertSucceeds(getDocs(query(
    providers,
    where('active', '==', true),
    where('category', '==', 'hospital'),
    where('partnerStatus', '==', 'partner'),
    where('state', '==', 'Lagos'),
    where('city', '==', 'Ikeja'),
    orderBy('normalizedName'),
    limit(10),
  )));
  if (filtered.size !== 1) {
    throw new Error(`Expected one filtered provider, got ${filtered.size}.`);
  }

  await assertSucceeds(getDocs(query(
    providers,
    where('active', '==', true),
    where('searchPrefixes', 'array-contains', 'ever'),
    orderBy('normalizedName'),
    limit(10),
  )));
  await assertSucceeds(getDocs(query(
    providers,
    where('active', '==', true),
    where('locationCell', 'array-contains-any', ['lagos-ikeja', 'abuja']),
    orderBy('normalizedName'),
    limit(10),
  )));

  await assertFails(getDocs(providers));
  await assertFails(getDocs(query(
    providers,
    where('category', '==', 'hospital'),
  )));
  await assertFails(getDocs(query(
    providers,
    where('active', '==', false),
  )));
});

test('healthcare directory rejects weak identities and every client write', async () => {
  await seedHealthcareProviders();
  const activePath = 'healthcare_providers/evercare-ikeja';
  const anonymousDb = environment.unauthenticatedContext().firestore();
  const unverifiedDb = environment.authenticatedContext('unverified-user', {
    email: 'unverified@example.com',
    email_verified: false,
    firebase: { sign_in_provider: 'google.com' },
  }).firestore();
  const phoneDb = environment.authenticatedContext('phone-directory-user', {
    phone_number: '+2348012345678',
    firebase: { sign_in_provider: 'phone' },
  }).firestore();

  for (const db of [anonymousDb, unverifiedDb, phoneDb]) {
    await assertFails(getDoc(doc(db, activePath)));
    await assertFails(getDocs(query(
      collection(db, 'healthcare_providers'),
      where('active', '==', true),
    )));
  }

  const userDb = verifiedContext('directory-user').firestore();
  await assertFails(setDoc(
    doc(userDb, 'healthcare_providers/forged-provider'),
    healthcareProvider({
      name: 'Forged Hospital',
      category: 'hospital',
      partnerStatus: 'partner',
      state: 'Lagos',
      city: 'Ikeja',
      locationCell: ['lagos', 'lagos-ikeja'],
    }),
  ));
  await assertFails(updateDoc(doc(userDb, activePath), { active: false }));
  await assertFails(updateDoc(doc(userDb, activePath), {
    extraData: 'schema pollution',
  }));
  await assertFails(deleteDoc(doc(userDb, activePath)));
});

test('verified Google users can get and query only active coverage items', async () => {
  await seedCoverageItems();
  const userDb = verifiedContext('coverage-user').firestore();
  const items = collection(userDb, 'coverage_items');

  await assertSucceeds(
    getDoc(doc(userDb, 'coverage_items/basic-consultation')),
  );
  await assertFails(
    getDoc(doc(userDb, 'coverage_items/stale-pharmacy-estimate')),
  );
  await assertFails(
    getDoc(doc(userDb, 'coverage_items/guessed-inactive-item')),
  );

  const activeItems = await assertSucceeds(getDocs(query(
    items,
    where('active', '==', true),
    orderBy('indicativePriceKobo', 'asc'),
    limit(100),
  )));
  if (activeItems.size !== 2) {
    throw new Error(`Expected two active coverage items, got ${activeItems.size}.`);
  }
  await assertFails(getDocs(items));
  await assertFails(getDocs(query(
    items,
    orderBy('indicativePriceKobo', 'asc'),
    limit(100),
  )));
  await assertFails(getDocs(query(
    items,
    where('active', '==', false),
    orderBy('indicativePriceKobo', 'asc'),
  )));
});

test('coverage catalog rejects weak identities and every client mutation', async () => {
  await seedCoverageItems();
  const activePath = 'coverage_items/basic-consultation';
  const anonymousDb = environment.unauthenticatedContext().firestore();
  const unverifiedDb = environment.authenticatedContext('coverage-unverified', {
    email: 'coverage-unverified@example.com',
    email_verified: false,
    firebase: { sign_in_provider: 'google.com' },
  }).firestore();
  const phoneDb = environment.authenticatedContext('coverage-phone', {
    phone_number: '+2348012345678',
    firebase: { sign_in_provider: 'phone' },
  }).firestore();

  for (const db of [anonymousDb, unverifiedDb, phoneDb]) {
    await assertFails(getDoc(doc(db, activePath)));
    await assertFails(getDocs(query(
      collection(db, 'coverage_items'),
      where('active', '==', true),
      orderBy('indicativePriceKobo', 'asc'),
      limit(20),
    )));
  }

  const userDb = verifiedContext('coverage-user').firestore();
  await assertFails(setDoc(
    doc(userDb, 'coverage_items/forged-item'),
    coverageItem({
      name: 'Forged care price',
      category: 'other',
      indicativePriceKobo: 1,
      sourceName: 'Attacker source',
    }),
  ));
  const activeItem = doc(userDb, activePath);
  for (const mutation of [
    { active: false, deactivatedAt: now },
    { indicativePriceKobo: 1 },
    { indicativePriceKobo: '500000' },
    { sourceName: 'Attacker source' },
    { sourceReference: 'forged-reference' },
    { priceType: 'guaranteed_price' },
    { disclaimer: 'This price is guaranteed.' },
    { updatedAt: Timestamp.fromDate(new Date('2099-01-01T00:00:00Z')) },
    { extraData: 'x'.repeat(10000) },
  ]) {
    await assertFails(updateDoc(activeItem, mutation));
  }
  await assertFails(deleteDoc(activeItem));

  await assertFails(updateDoc(
    doc(userDb, 'coverage_items/stale-pharmacy-estimate'),
    { active: true, deactivatedAt: null },
  ));
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

test('healthcare payments are readable only by their verified owner', async () => {
  await seedHealthcarePayments();
  const ownerDb = verifiedContext('owner').firestore();
  const strangerDb = verifiedContext('stranger').firestore();
  const ownerPartnerPath = 'healthcare_payments/payment-owner-partner';
  const ownerNonPartnerPath =
    'healthcare_payments/payment-owner-non-partner';

  await assertSucceeds(getDoc(doc(ownerDb, ownerPartnerPath)));
  await assertSucceeds(getDoc(doc(ownerDb, ownerNonPartnerPath)));
  await assertFails(getDoc(doc(strangerDb, ownerPartnerPath)));
  await assertFails(
    getDoc(doc(ownerDb, 'healthcare_payments/payment-stranger-partner')),
  );
  await assertFails(
    getDoc(doc(ownerDb, 'healthcare_payments/guessed-payment-id')),
  );

  const owned = await assertSucceeds(getDocs(query(
    collection(ownerDb, 'healthcare_payments'),
    where('userId', '==', 'owner'),
    orderBy('createdAt', 'desc'),
    limit(20),
  )));
  if (owned.size !== 2) {
    throw new Error(`Expected two healthcare payments, got ${owned.size}.`);
  }
  await assertFails(getDocs(collection(ownerDb, 'healthcare_payments')));
  await assertFails(getDocs(query(
    collection(ownerDb, 'healthcare_payments'),
    where('userId', '==', 'stranger'),
    orderBy('createdAt', 'desc'),
  )));
});

test('healthcare payment history rejects anonymous and weak identities', async () => {
  await seedHealthcarePayments();
  const path = 'healthcare_payments/payment-owner-partner';
  const anonymousDb = environment.unauthenticatedContext().firestore();
  const unverifiedDb = environment.authenticatedContext('owner', {
    email: 'owner@example.com',
    email_verified: false,
    firebase: { sign_in_provider: 'google.com' },
  }).firestore();
  const phoneDb = environment.authenticatedContext('owner', {
    phone_number: '+2348012345678',
    firebase: { sign_in_provider: 'phone' },
  }).firestore();

  for (const db of [anonymousDb, unverifiedDb, phoneDb]) {
    await assertFails(getDoc(doc(db, path)));
    await assertFails(getDocs(query(
      collection(db, 'healthcare_payments'),
      where('userId', '==', 'owner'),
      orderBy('createdAt', 'desc'),
    )));
  }
});

test('clients cannot forge or mutate healthcare payment outcomes', async () => {
  await seedHealthcarePayments();
  const ownerDb = verifiedContext('owner').firestore();
  const payment = doc(
    ownerDb,
    'healthcare_payments/payment-owner-partner',
  );

  await assertFails(setDoc(
    doc(ownerDb, 'healthcare_payments/forged-success'),
    healthcarePayment('owner', 'non_partner', {
      status: 'completed',
      verificationStatus: 'verified',
      receiptNumber: 'FORGED-RECEIPT',
      beneficiary: {
        accountNumberLast4: '1234',
        bankCode: '999',
        bankName: 'Mock Bank',
        accountName: 'Attacker',
        beneficiaryReference: 'forged-beneficiary',
        accountNumber: '0000001234',
      },
    }),
  ));

  for (const mutation of [
    { status: 'completed' },
    { status: 'reversed' },
    { receiptNumber: 'FORGED-RECEIPT' },
    { verificationStatus: 'verified' },
    { verificationReference: 'forged-verification' },
    { amountKobo: -1 },
    { amountKobo: 100000000001 },
    { amountKobo: '250000' },
    { userId: 'stranger' },
    { ledgerEntryId: 'forged-ledger-entry' },
    { extraData: 'x'.repeat(10000) },
  ]) {
    await assertFails(updateDoc(payment, mutation));
  }
  await assertFails(deleteDoc(payment));
});

test('receipts are readable only by their verified owner', async () => {
  await seedReceipts();
  const ownerDb = verifiedContext('owner').firestore();
  const strangerDb = verifiedContext('stranger').firestore();
  const ownerReceiptPath = 'receipts/HPF-A1B2C3D4E5F6';

  await assertSucceeds(getDoc(doc(ownerDb, ownerReceiptPath)));
  await assertFails(getDoc(doc(strangerDb, ownerReceiptPath)));
  await assertFails(
    getDoc(doc(ownerDb, 'receipts/HPC-ABCDEF123456')),
  );
  await assertFails(
    getDoc(doc(ownerDb, 'receipts/HPC-000000000000')),
  );

  const owned = await assertSucceeds(getDocs(query(
    collection(ownerDb, 'receipts'),
    where('userId', '==', 'owner'),
    orderBy('issuedAt', 'desc'),
    limit(20),
  )));
  if (owned.size !== 2) {
    throw new Error(`Expected two owner receipts, got ${owned.size}.`);
  }
  await assertFails(getDocs(collection(ownerDb, 'receipts')));
  await assertFails(getDocs(query(
    collection(ownerDb, 'receipts'),
    where('userId', '==', 'stranger'),
    orderBy('issuedAt', 'desc'),
  )));
});

test('receipt reads reject anonymous and unverified identities', async () => {
  await seedReceipts();
  const path = 'receipts/HPF-A1B2C3D4E5F6';
  const anonymousDb = environment.unauthenticatedContext().firestore();
  const unverifiedDb = environment.authenticatedContext('owner', {
    email: 'owner@example.com',
    email_verified: false,
    firebase: { sign_in_provider: 'google.com' },
  }).firestore();

  for (const db of [anonymousDb, unverifiedDb]) {
    await assertFails(getDoc(doc(db, path)));
    await assertFails(getDocs(query(
      collection(db, 'receipts'),
      where('userId', '==', 'owner'),
      orderBy('issuedAt', 'desc'),
    )));
  }
});

test('clients cannot forge or tamper with receipt evidence', async () => {
  await seedReceipts();
  const ownerDb = verifiedContext('owner').firestore();
  const receipt = doc(ownerDb, 'receipts/HPF-A1B2C3D4E5F6');

  await assertFails(setDoc(
    doc(ownerDb, 'receipts/HPC-FFFFFFFFFFFF'),
    receiptRecord(
      'owner',
      'HPC-FFFFFFFFFFFF',
      'healthcare_payment',
      {
        amountKobo: 99999999,
        status: 'completed',
        provider: { id: 'attacker', name: 'Forged Provider' },
        transactionReference: 'forged-reference',
      },
    ),
  ));

  for (const mutation of [
    { amountKobo: 1 },
    { amountKobo: '250000' },
    { status: 'pending' },
    { status: 'failed' },
    { provider: { id: 'attacker', name: 'Forged Provider' } },
    { recipient: { id: 'attacker', name: 'Forged Recipient' } },
    { healthPocketReferenceId: 'HPF-FFFFFFFFFFFF' },
    { transactionReference: 'forged-reference' },
    { receiptNumber: 'HPF-FFFFFFFFFFFF' },
    { ledgerEntryId: 'forged-ledger-entry' },
    { sourceFingerprint: '0'.repeat(64) },
    { issuedAt: Timestamp.fromDate(new Date('2099-01-01T00:00:00Z')) },
    { extraData: 'x'.repeat(10000) },
  ]) {
    await assertFails(updateDoc(receipt, mutation));
  }
  await assertFails(deleteDoc(receipt));
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

test('notification events support verified-owner unread cursor queries only', async () => {
  const firstCreatedAt = Timestamp.fromDate(new Date('2026-01-03T12:00:00Z'));
  const secondCreatedAt = Timestamp.fromDate(new Date('2026-01-02T12:00:00Z'));
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const notification = (userId, readState, createdAt) => ({
      schemaVersion: 1,
      userId,
      type: 'funding_completed',
      category: 'funding',
      title: 'Money added',
      body: 'Your HealthPocket balance has been updated.',
      readState,
      readAt: readState === 'read' ? createdAt : null,
      deliveryStatus: 'queued',
      deliveryAttemptCount: 0,
      lastDeliveryErrorCode: null,
      deliveredAt: null,
      relatedEntityType: 'funding_transaction',
      relatedEntityId: `funding-${userId}`,
      familyPocketId: null,
      createdAt,
      updatedAt: createdAt,
    });
    await setDoc(
      doc(db, 'notification_events/notice-owner-new'),
      notification('owner', 'unread', firstCreatedAt),
    );
    await setDoc(
      doc(db, 'notification_events/notice-owner-old'),
      notification('owner', 'unread', secondCreatedAt),
    );
    await setDoc(
      doc(db, 'notification_events/notice-owner-read'),
      notification('owner', 'read', secondCreatedAt),
    );
    await setDoc(
      doc(db, 'notification_events/notice-stranger'),
      notification('stranger', 'unread', firstCreatedAt),
    );
  });

  const ownerDb = verifiedContext('owner').firestore();
  const notifications = collection(ownerDb, 'notification_events');
  await assertSucceeds(
    getDoc(doc(ownerDb, 'notification_events/notice-owner-new')),
  );
  const unreadPage = await assertSucceeds(getDocs(query(
    notifications,
    where('userId', '==', 'owner'),
    where('readState', '==', 'unread'),
    orderBy('createdAt', 'desc'),
    orderBy(documentId(), 'desc'),
    startAfter(firstCreatedAt, 'notice-owner-new'),
    limit(1),
  )));
  if (unreadPage.size !== 1) {
    throw new Error(`Expected one unread notification, got ${unreadPage.size}.`);
  }

  await assertFails(getDoc(
    doc(ownerDb, 'notification_events/notice-stranger'),
  ));
  await assertFails(getDocs(notifications));
  await assertFails(getDocs(query(
    notifications,
    where('readState', '==', 'unread'),
    orderBy('createdAt', 'desc'),
  )));
  await assertFails(getDocs(query(
    notifications,
    where('userId', '==', 'stranger'),
    where('readState', '==', 'unread'),
    orderBy('createdAt', 'desc'),
  )));
});

test('notification events reject unverified access and every client mutation', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'notification_events/notice-owner-secure'),
      {
        schemaVersion: 1,
        userId: 'owner',
        type: 'security_alert',
        category: 'security',
        title: 'Security notice',
        body: 'A security event needs your attention.',
        readState: 'unread',
        readAt: null,
        deliveryStatus: 'queued',
        deliveryAttemptCount: 0,
        lastDeliveryErrorCode: null,
        deliveredAt: null,
        relatedEntityType: null,
        relatedEntityId: null,
        familyPocketId: null,
        createdAt: now,
        updatedAt: now,
      },
    );
  });

  const ownerDb = verifiedContext('owner').firestore();
  const unverifiedDb = environment.authenticatedContext('owner', {
    email: 'owner@example.com',
    email_verified: false,
    firebase: { sign_in_provider: 'google.com' },
  }).firestore();
  const phoneDb = environment.authenticatedContext('owner', {
    phone_number: '+2348000000000',
    firebase: { sign_in_provider: 'phone' },
  }).firestore();
  const notification = doc(
    ownerDb,
    'notification_events/notice-owner-secure',
  );

  await assertFails(getDoc(doc(
    unverifiedDb,
    'notification_events/notice-owner-secure',
  )));
  await assertFails(getDoc(doc(
    phoneDb,
    'notification_events/notice-owner-secure',
  )));
  await assertFails(setDoc(
    doc(ownerDb, 'notification_events/notice-forged'),
    { userId: 'owner', readState: 'unread', title: 'Forged' },
  ));
  for (const mutation of [
    { readState: 'read', readAt: now, updatedAt: now },
    { title: 'Tampered notification' },
    { userId: 'stranger' },
    { deliveryStatus: 'delivered' },
    { extraData: 'x'.repeat(10000) },
  ]) {
    await assertFails(updateDoc(notification, mutation));
  }
  await assertFails(deleteDoc(notification));
});

test('notification devices are completely inaccessible to clients', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'notification_devices/device-seeded'), {
      schemaVersion: 1,
      userId: 'owner',
      token: 'private-fcm-device-token-that-must-not-leak',
      platform: 'android',
      status: 'active',
      createdAt: now,
      updatedAt: now,
      lastSeenAt: now,
      lastDeliveryAt: null,
      lastErrorCode: null,
    });
  });

  const ownerDb = verifiedContext('owner').firestore();
  const strangerDb = verifiedContext('stranger').firestore();
  const anonymousDb = environment.unauthenticatedContext().firestore();
  for (const db of [ownerDb, strangerDb, anonymousDb]) {
    await assertFails(getDoc(
      doc(db, 'notification_devices/device-seeded'),
    ));
    await assertFails(getDocs(collection(db, 'notification_devices')));
  }
  await assertFails(setDoc(
    doc(ownerDb, 'notification_devices/device-forged'),
    {
      schemaVersion: 1,
      userId: 'owner',
      token: 'attacker-controlled-fcm-token-value',
      platform: 'android',
      status: 'active',
    },
  ));
  await assertFails(updateDoc(
    doc(ownerDb, 'notification_devices/device-seeded'),
    { token: 'replacement-attacker-token-value' },
  ));
  await assertFails(deleteDoc(
    doc(ownerDb, 'notification_devices/device-seeded'),
  ));
});

test('email infrastructure collections are completely backend-only', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'email_outbox/message-seeded'), {
      schemaVersion: 1,
      recipientEmail: 'owner@example.com',
      eventType: 'family_invitation',
      classification: 'transactional',
      variables: {
        inviterName: 'HealthPocket User',
        pocketName: 'Family Care',
        inviteUrl: 'https://healthpocket.example/invites/example',
      },
      requestFingerprint: 'd'.repeat(64),
      status: 'queued',
      attemptCount: 0,
      maxAttempts: 5,
      nextAttemptAt: now,
      provider: null,
      providerMessageId: null,
      lastErrorCode: null,
      createdAt: now,
      updatedAt: now,
      sentAt: null,
    });
    await setDoc(doc(db, 'email_rate_limits/bucket-seeded'), {
      schemaVersion: 1,
      recipientHash: 'a'.repeat(64),
      classification: 'transactional',
      count: 1,
      windowStartedAt: now,
      windowEndsAt: Timestamp.fromDate(new Date('2026-01-01T01:00:00Z')),
      updatedAt: now,
    });
    await setDoc(doc(db, 'email_verification_challenges/challenge-seeded'), {
      schemaVersion: 1,
      userId: 'owner',
      emailHash: 'b'.repeat(64),
      challengeHash: 'c'.repeat(64),
      status: 'pending',
      attemptCount: 0,
      expiresAt: Timestamp.fromDate(new Date('2026-01-01T00:15:00Z')),
      consumedAt: null,
      createdAt: now,
      updatedAt: now,
    });
  });

  const contexts = [
    environment.unauthenticatedContext().firestore(),
    verifiedContext('owner').firestore(),
    verifiedContext('stranger').firestore(),
    environment.authenticatedContext('phone-user', {
      phone_number: '+2348012345678',
      firebase: { sign_in_provider: 'phone' },
    }).firestore(),
    environment.authenticatedContext('forged-admin', {
      email: 'forged-admin@example.com',
      email_verified: true,
      admin: true,
      firebase: { sign_in_provider: 'google.com' },
    }).firestore(),
  ];
  const resources = [
    ['email_outbox', 'message-seeded'],
    ['email_rate_limits', 'bucket-seeded'],
    ['email_verification_challenges', 'challenge-seeded'],
  ];

  for (const db of contexts) {
    for (const [collectionName, documentIdValue] of resources) {
      await assertFails(getDoc(
        doc(db, collectionName, documentIdValue),
      ));
      await assertFails(getDocs(collection(db, collectionName)));
    }
  }

  const ownerDb = verifiedContext('owner').firestore();
  const forgedAdminDb = contexts.at(-1);
  for (const db of [ownerDb, forgedAdminDb]) {
    await assertFails(setDoc(doc(db, 'email_outbox/message-forged'), {
      recipientEmail: 'victim@example.com',
      eventType: 'security_alert',
      variables: { malicious: 'x'.repeat(10000) },
      status: 'queued',
    }));
    await assertFails(updateDoc(
      doc(db, 'email_outbox/message-seeded'),
      { status: 'sent', providerMessageId: 'forged-provider-id' },
    ));
    await assertFails(deleteDoc(
      doc(db, 'email_outbox/message-seeded'),
    ));

    await assertFails(setDoc(doc(db, 'email_rate_limits/bucket-forged'), {
      recipientHash: 'f'.repeat(64),
      classification: 'transactional',
      count: 0,
    }));
    await assertFails(updateDoc(
      doc(db, 'email_rate_limits/bucket-seeded'),
      { count: 0, windowEndsAt: now },
    ));
    await assertFails(deleteDoc(
      doc(db, 'email_rate_limits/bucket-seeded'),
    ));

    await assertFails(setDoc(
      doc(db, 'email_verification_challenges/challenge-forged'),
      {
        userId: 'owner',
        emailHash: 'f'.repeat(64),
        challengeHash: '0'.repeat(64),
        status: 'verified',
      },
    ));
    await assertFails(updateDoc(
      doc(db, 'email_verification_challenges/challenge-seeded'),
      { status: 'verified', attemptCount: 0, consumedAt: now },
    ));
    await assertFails(deleteDoc(
      doc(db, 'email_verification_challenges/challenge-seeded'),
    ));
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
