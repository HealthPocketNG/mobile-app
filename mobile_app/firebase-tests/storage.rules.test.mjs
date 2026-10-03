import { after, before, beforeEach, test } from 'node:test';
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
let environment;

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
    storage: { host: '127.0.0.1', port: 9199, rules },
  });
});

beforeEach(async () => environment.clearStorage());
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
