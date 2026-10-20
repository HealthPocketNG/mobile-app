import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

const projectId = 'demo-healthpocket';
const bucket = 'demo-healthpocket.appspot.com';
const photoName = '0123456789abcdef0123456789abcdef.jpg';
const ownerPath = `users/owner/profile/${photoName}`;
const pocketId = 'family_secure-pocket';
const familyPath = `family_pockets/${pocketId}/profile/${photoName}`;
let environment;

const emulatorPort = (variable, fallback) => {
  const host = process.env[variable];
  return host ? Number(host.split(':').at(-1)) : fallback;
};

const verifiedContext = (uid) =>
  environment.authenticatedContext(uid, {
    email: `${uid}@example.com`,
    email_verified: true,
    firebase: { sign_in_provider: 'google.com' },
  });

before(async () => {
  const rules = await readFile(
    new URL('../storage.rules', import.meta.url),
    'utf8',
  );
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: emulatorPort('FIRESTORE_EMULATOR_HOST', 8080),
    },
    storage: {
      host: '127.0.0.1',
      port: emulatorPort('FIREBASE_STORAGE_EMULATOR_HOST', 9199),
      rules,
    },
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
  await environment.clearStorage();
});
after(async () => environment.cleanup());

test('only the verified owner can upload and read a profile photo', async () => {
  const owner = verifiedContext('owner').storage(`gs://${bucket}`);
  const stranger = verifiedContext('stranger').storage(`gs://${bucket}`);
  const anonymous = environment
    .unauthenticatedContext()
    .storage(`gs://${bucket}`);

  await assertSucceeds(
    owner.ref(ownerPath).putString('profile image', 'raw', {
      contentType: 'image/jpeg',
    }),
  );
  await assertSucceeds(owner.ref(ownerPath).getMetadata());
  await assertFails(stranger.ref(ownerPath).getMetadata());
  await assertFails(anonymous.ref(ownerPath).getMetadata());
  await assertFails(
    stranger.ref('users/owner/profile/abcdefabcdefabcdefabcdefabcdefab.jpg')
      .putString('profile image', 'raw', { contentType: 'image/jpeg' }),
  );
});

test('profile photo rules reject bad names, types, and oversized files', async () => {
  const owner = verifiedContext('owner').storage(`gs://${bucket}`);
  await assertFails(
    owner.ref('users/owner/profile/avatar.jpg').putString(
      'profile image',
      'raw',
      { contentType: 'image/jpeg' },
    ),
  );
  await assertFails(
    owner.ref(ownerPath).putString('not an image', 'raw', {
      contentType: 'text/plain',
    }),
  );
  await assertFails(
    owner.ref(ownerPath).put(new Uint8Array(5 * 1024 * 1024 + 1), {
      contentType: 'image/jpeg',
    }),
  );
});

test('profile photo bytes cannot be overwritten in place', async () => {
  const owner = verifiedContext('owner').storage(`gs://${bucket}`);
  const immutablePath =
    'users/owner/profile/11111111111111111111111111111111.jpg';
  const ref = owner.ref(immutablePath);

  await assertSucceeds(
    ref.putString('profile image', 'raw', { contentType: 'image/jpeg' }),
  );
  await assert.rejects(
    async () => owner.ref(immutablePath).putString('replacement', 'raw', {
      contentType: 'image/jpeg',
    }),
    (error) => error.code === 'storage/unauthorized',
  );
});

test('only the profile photo owner can delete the object', async () => {
  const owner = verifiedContext('owner').storage(`gs://${bucket}`);
  const stranger = verifiedContext('stranger').storage(`gs://${bucket}`);
  const deletePath =
    'users/owner/profile/22222222222222222222222222222222.jpg';

  await assertSucceeds(
    owner.ref(deletePath).putString('profile image', 'raw', {
      contentType: 'image/jpeg',
    }),
  );
  await assertFails(stranger.ref(deletePath).delete());
  await assertSucceeds(owner.ref(deletePath).delete());
});

async function seedFamilyMemberships() {
  await environment.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    const members = firestore.collection('family_pockets')
      .doc(pocketId)
      .collection('members');
    await members.doc('owner').set({
      userId: 'owner', role: 'owner', status: 'active',
      removedAt: null, leftAt: null,
    });
    await members.doc('admin').set({
      userId: 'admin', role: 'admin', status: 'accepted',
      removedAt: null, leftAt: null,
    });
    await members.doc('member').set({
      userId: 'member', role: 'member', status: 'active',
      removedAt: null, leftAt: null,
    });
    await members.doc('removed').set({
      userId: 'removed', role: 'admin', status: 'removed',
      removedAt: new Date(), leftAt: null,
    });
  });
}

test('Family Pocket images are member-readable and admin-managed', async () => {
  await seedFamilyMemberships();
  const owner = verifiedContext('owner').storage(`gs://${bucket}`);
  const admin = verifiedContext('admin').storage(`gs://${bucket}`);
  const member = verifiedContext('member').storage(`gs://${bucket}`);

  await assertSucceeds(
    owner.ref(familyPath).putString('family image', 'raw', {
      contentType: 'image/jpeg',
    }),
  );
  await assertSucceeds(member.ref(familyPath).getMetadata());
  await assertFails(
    member.ref(`family_pockets/${pocketId}/profile/abcdefabcdefabcdefabcdefabcdefab.jpg`)
      .putString('family image', 'raw', { contentType: 'image/jpeg' }),
  );
  await assertSucceeds(admin.ref(familyPath).delete());
});

test('Family Pocket images reject guessed IDs, former members, and overwrites', async () => {
  await seedFamilyMemberships();
  const owner = verifiedContext('owner').storage(`gs://${bucket}`);
  const stranger = verifiedContext('stranger').storage(`gs://${bucket}`);
  const removed = verifiedContext('removed').storage(`gs://${bucket}`);

  await assertSucceeds(
    owner.ref(familyPath).putString('family image', 'raw', {
      contentType: 'image/jpeg',
    }),
  );
  await assertFails(stranger.ref(familyPath).getMetadata());
  await assertFails(removed.ref(familyPath).getMetadata());
  await assertFails(
    stranger.ref('family_pockets/family_guessed/profile/' + photoName)
      .getMetadata(),
  );
  await assertFails(
    owner.ref(familyPath).putString('replacement', 'raw', {
      contentType: 'image/jpeg',
    }),
  );
});
