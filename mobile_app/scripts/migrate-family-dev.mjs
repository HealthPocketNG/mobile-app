import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { homedir } from 'node:os';
import { resolve } from 'node:path';

// Deliberately no project argument: this tool cannot target production.
const project = 'healthpocket-dev-a82f3';
const root = `projects/${project}/databases/(default)/documents`;
const base = `https://firestore.googleapis.com/v1/${root}`;
const folder = resolve('.dart_tool/family-migration');
const mode = process.argv[2] ?? 'preview';
// No migration was needed for this rollout. Keep cloud writes disabled until
// a future non-empty preview has a reviewed and tested migration plan.
if (mode !== 'preview') throw Error('Only read-only preview is supported.');
const config = JSON.parse(await readFile(resolve(homedir(), '.config/configstore/firebase-tools.json'), 'utf8'));
let token = config.tokens?.access_token;
if (!token) throw Error('Run firebase login first.');
async function api(url, method = 'GET', body) {
  const response = await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!response.ok) throw Error(`Firestore ${method} failed (${response.status}); refresh firebase login if expired.`);
  return response.json();
}
async function list(path) {
  const docs = [];
  let next;
  do {
    const result = await api(`${base}/${path}?pageSize=100${next ? `&pageToken=${encodeURIComponent(next)}` : ''}`);
    docs.push(...(result.documents ?? []));
    next = result.nextPageToken;
  } while (next);
  return docs;
}
const pockets = await list('family_pockets');
const database = await api(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)`);
if (database.locationId !== 'africa-south1') throw Error('Unexpected DEV database region.');
const indexes = await api(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/collectionGroups/-/indexes`);
console.log(JSON.stringify({ location: database.locationId, indexes: (indexes.indexes ?? []).map(index => ({ collection: index.name.split('/')[5], state: index.state, fields: index.fields.map(field => field.fieldPath) })) }));
const documents = [...pockets];
for (const pocket of pockets) {
  const id = pocket.name.split('/').at(-1);
  for (const collection of ['members', 'invites', 'beneficiary_slots']) {
    documents.push(...await list(`family_pockets/${id}/${collection}`));
  }
}
await mkdir(folder, { recursive: true });
const backup = resolve(folder, `backup-${Date.now()}.json`);
await writeFile(backup, JSON.stringify({ project, documents }, null, 2), { flag: 'wx' });
console.log(JSON.stringify({ project, pockets: pockets.length, documents: documents.length, backup }));
const writes = [];
const blockers = [];
for (const document of documents) {
  const fields = structuredClone(document.fields);
  const collection = document.name.split('/').at(-2);
  if (collection === 'family_pockets' && fields.beneficiary) {
    delete fields.beneficiary;
    fields.beneficiaryLimit = { integerValue: '2' };
  } else if (collection === 'members' && fields.invitationStatus) {
    const role = fields.role?.stringValue;
    const status = fields.invitationStatus.stringValue;
    if (!['admin', 'contributor'].includes(role) || !['accepted', 'removed'].includes(status)) {
      blockers.push('Legacy beneficiary or pending membership requires explicit slot reconciliation.');
      continue;
    }
    fields.role = { stringValue: role === 'admin' ? 'admin' : 'member' };
    fields.status = { stringValue: status };
    fields.canContribute = { booleanValue: true };
    fields.isBeneficiary = { booleanValue: false };
    delete fields.invitationStatus;
    delete fields.email;
  } else if (collection === 'invites' && !fields.expiresAt) {
    blockers.push('Legacy invitation requires review before assigning expiry and permissions.');
    continue;
  }
  if (JSON.stringify(fields) !== JSON.stringify(document.fields)) {
    writes.push({ update: { name: document.name, fields }, currentDocument: { updateTime: document.updateTime } });
  }
}
console.log(JSON.stringify({ proposedWrites: writes.length, blockers }));
if (blockers.length) throw Error('Migration stopped; backup preserved, no writes performed.');
