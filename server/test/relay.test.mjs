import assert from 'node:assert/strict';
import {
  createHash,
  createHmac,
  createPublicKey,
  diffieHellman,
  generateKeyPairSync,
  hkdfSync,
  randomBytes,
} from 'node:crypto';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { after, before, test } from 'node:test';

import { createRelayServer } from '../relay.mjs';

const X25519_PUBLIC_PREFIX = Buffer.from('302a300506032b656e032100', 'hex');
const REGISTRATION_CONTEXT = 'massjj-relay-registration-v1';
const fixedNow = () => new Date('2026-09-09T12:00:00.000Z');
const alice = createIdentity();
const bob = createIdentity();

let baseUrl;
let server;
let tempDirectory;

before(async () => {
  tempDirectory = await mkdtemp(join(tmpdir(), 'massjj-relay-test-'));
  ({ server, baseUrl } = await startRelay(
    join(tempDirectory, 'relay.sqlite'),
  ));
});

after(async () => {
  await closeServer(server);
  await rm(tempDirectory, { recursive: true, force: true });
});

test('proves mailbox ownership, stores an opaque packet, and acknowledges it', async () => {
  let response = await registerMailbox(baseUrl, bob);
  assert.equal(response.status, 201);

  const value = packetFor(bob.mailboxId, 'message_0001');
  response = await sendPacket(baseUrl, bob, value);
  assert.equal(response.status, 202);

  response = await readPackets(baseUrl, bob);
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).items, [value]);

  response = await fetch(
    `${baseUrl}/v1/mailboxes/${bob.mailboxId}/messages/${value.messageId}`,
    { method: 'DELETE', headers: authorization(bob.readToken) },
  );
  assert.equal(response.status, 204);
  assert.deepEqual((await (await readPackets(baseUrl, bob)).json()).items, []);
});

test('rejects a first-claim attempt without the mailbox private key', async () => {
  const victim = createIdentity();
  const attacker = createIdentity();
  const body = await registrationBody(baseUrl, attacker, {
    mailboxId: victim.mailboxId,
  });
  const response = await fetch(`${baseUrl}/v1/mailboxes`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  assert.equal(response.status, 401);
  assert.equal((await response.json()).error, 'invalid_registration_proof');
  assert.equal((await registerMailbox(baseUrl, victim)).status, 201);
});

test('keeps read and write capabilities separate', async () => {
  await registerMailbox(baseUrl, bob);
  const response = await fetch(
    `${baseUrl}/v1/mailboxes/${bob.mailboxId}/messages`,
    { headers: authorization(bob.writeToken) },
  );
  assert.equal(response.status, 401);
});

test('rejects malformed packets and far-future retention bypasses', async () => {
  await registerMailbox(baseUrl, bob);
  let response = await sendPacket(
    baseUrl,
    bob,
    packetFor(bob.mailboxId, 'message_0002', {
      recipientId: alice.mailboxId,
    }),
  );
  assert.equal(response.status, 400);

  response = await sendPacket(
    baseUrl,
    bob,
    packetFor(bob.mailboxId, 'message_0003', {
      createdAt: '2030-09-09T12:00:00.000Z',
      expiresAt: '2030-09-10T12:00:00.000Z',
    }),
  );
  assert.equal(response.status, 400);

  response = await sendPacket(baseUrl, bob, {
    ...packetFor(bob.mailboxId, 'message_0004'),
    cryptoHeader: 'not-an-object',
  });
  assert.equal(response.status, 400);
});

test('rejects a full mailbox without evicting its queued message', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'massjj-relay-quota-'));
  const instance = await startRelay(join(directory, 'relay.sqlite'), {
    maxMessagesPerMailbox: 1,
  });
  const identity = createIdentity();
  try {
    assert.equal((await registerMailbox(instance.baseUrl, identity)).status, 201);
    const first = packetFor(identity.mailboxId, 'message_quota_1');
    assert.equal((await sendPacket(instance.baseUrl, identity, first)).status, 202);
    const response = await sendPacket(
      instance.baseUrl,
      identity,
      packetFor(identity.mailboxId, 'message_quota_2'),
    );
    assert.equal(response.status, 429);
    assert.equal((await response.json()).error, 'mailbox_quota_exceeded');
    assert.deepEqual(
      (await (await readPackets(instance.baseUrl, identity)).json()).items,
      [first],
    );
  } finally {
    await closeServer(instance.server);
    await rm(directory, { recursive: true, force: true });
  }
});

test('rate-limits repeated writes for a mailbox capability', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'massjj-relay-rate-'));
  const instance = await startRelay(join(directory, 'relay.sqlite'), {
    maxWritesPerMinute: 1,
  });
  const identity = createIdentity();
  try {
    await registerMailbox(instance.baseUrl, identity);
    assert.equal(
      (
        await sendPacket(
          instance.baseUrl,
          identity,
          packetFor(identity.mailboxId, 'message_rate_1'),
        )
      ).status,
      202,
    );
    const response = await sendPacket(
      instance.baseUrl,
      identity,
      packetFor(identity.mailboxId, 'message_rate_2'),
    );
    assert.equal(response.status, 429);
    assert.equal((await response.json()).error, 'writer_rate_limited');
  } finally {
    await closeServer(instance.server);
    await rm(directory, { recursive: true, force: true });
  }
});

test('rate-limits the public health endpoint by source', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'massjj-relay-health-rate-'));
  const instance = await startRelay(join(directory, 'relay.sqlite'), {
    maxRequestsPerMinute: 2,
  });
  try {
    assert.equal((await fetch(`${instance.baseUrl}/health`)).status, 200);
    assert.equal((await fetch(`${instance.baseUrl}/health`)).status, 200);
    const response = await fetch(`${instance.baseUrl}/health`);
    assert.equal(response.status, 429);
    assert.equal((await response.json()).error, 'source_rate_limited');
  } finally {
    await closeServer(instance.server);
    await rm(directory, { recursive: true, force: true });
  }
});

test('committed mailbox and message survive a relay restart', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'massjj-relay-restart-'));
  const databaseFile = join(directory, 'relay.sqlite');
  const identity = createIdentity();
  let instance = await startRelay(databaseFile);
  try {
    await registerMailbox(instance.baseUrl, identity);
    const value = packetFor(identity.mailboxId, 'message_restart_1');
    assert.equal((await sendPacket(instance.baseUrl, identity, value)).status, 202);
    await closeServer(instance.server);

    instance = await startRelay(databaseFile);
    assert.equal((await registerMailbox(instance.baseUrl, identity)).status, 200);
    assert.deepEqual(
      (await (await readPackets(instance.baseUrl, identity)).json()).items,
      [value],
    );
  } finally {
    if (instance.server.listening) await closeServer(instance.server);
    await rm(directory, { recursive: true, force: true });
  }
});

test('fails clearly instead of interpreting legacy JSON as SQLite', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'massjj-relay-legacy-'));
  const legacyFile = join(directory, 'relay.json');
  try {
    await writeFile(legacyFile, '{"version":1,"mailboxes":{}}');
    assert.throws(
      () => createRelayServer({ storageFile: legacyFile }),
      /Legacy JSON relay state is not accepted/,
    );
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

async function startRelay(storageFile, limits = {}) {
  const nextServer = createRelayServer({ storageFile, now: fixedNow, limits });
  await new Promise((resolve) => nextServer.listen(0, '127.0.0.1', resolve));
  const address = nextServer.address();
  return {
    server: nextServer,
    baseUrl: `http://127.0.0.1:${address.port}`,
  };
}

function closeServer(value) {
  return new Promise((resolve, reject) => {
    value.close((error) => (error ? reject(error) : resolve()));
  });
}

function createIdentity() {
  const { privateKey, publicKey } = generateKeyPairSync('x25519');
  const publicKeyBytes = rawPublicKey(publicKey);
  return {
    privateKey,
    publicKey: publicKeyBytes.toString('base64url'),
    mailboxId: createHash('sha256')
      .update(publicKeyBytes)
      .digest()
      .subarray(0, 16)
      .toString('base64url'),
    readToken: randomBytes(32).toString('base64url'),
    writeToken: randomBytes(32).toString('base64url'),
  };
}

async function registrationBody(base, identity, overrides = {}) {
  const config = await (await fetch(`${base}/v1/config`)).json();
  const relayPublicKey = createPublicKey({
    key: Buffer.concat([
      X25519_PUBLIC_PREFIX,
      Buffer.from(config.registrationPublicKey, 'base64url'),
    ]),
    format: 'der',
    type: 'spki',
  });
  const body = {
    v: 1,
    mailboxId: identity.mailboxId,
    publicKey: identity.publicKey,
    readToken: identity.readToken,
    writeToken: identity.writeToken,
    ...overrides,
  };
  const sharedSecret = diffieHellman({
    privateKey: identity.privateKey,
    publicKey: relayPublicKey,
  });
  const proofKey = Buffer.from(
    hkdfSync(
      'sha256',
      sharedSecret,
      Buffer.alloc(0),
      Buffer.from(REGISTRATION_CONTEXT),
      32,
    ),
  );
  body.proof = createHmac('sha256', proofKey)
    .update(
      `${REGISTRATION_CONTEXT}\n${body.mailboxId}\n${body.publicKey}\n${body.readToken}\n${body.writeToken}`,
    )
    .digest('base64url');
  return body;
}

async function registerMailbox(base, identity) {
  return fetch(`${base}/v1/mailboxes`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(await registrationBody(base, identity)),
  });
}

function packetFor(recipientId, messageId, overrides = {}) {
  return {
    v: 1,
    cryptoSuite: 'mvp-x25519-aesgcm-v1',
    cryptoHeader: {},
    messageId,
    senderId: alice.mailboxId,
    recipientId,
    createdAt: '2026-09-09T12:00:00.000Z',
    expiresAt: '2026-09-16T12:00:00.000Z',
    hopLimit: 8,
    nonce: Buffer.alloc(12, 1).toString('base64'),
    cipherText: Buffer.from('opaque ciphertext').toString('base64'),
    mac: Buffer.alloc(16, 2).toString('base64'),
    ...overrides,
  };
}

function sendPacket(base, identity, packet) {
  return fetch(`${base}/v1/mailboxes/${identity.mailboxId}/messages`, {
    method: 'POST',
    headers: {
      ...authorization(identity.writeToken),
      'content-type': 'application/json',
    },
    body: JSON.stringify(packet),
  });
}

function readPackets(base, identity) {
  return fetch(`${base}/v1/mailboxes/${identity.mailboxId}/messages`, {
    headers: authorization(identity.readToken),
  });
}

function authorization(token) {
  return { authorization: `Bearer ${token}` };
}

function rawPublicKey(publicKey) {
  return publicKey.export({ format: 'der', type: 'spki' }).subarray(-32);
}
