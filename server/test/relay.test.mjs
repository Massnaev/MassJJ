import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { after, before, test } from 'node:test';

import { createRelayServer } from '../relay.mjs';

let baseUrl;
let server;
let tempDirectory;

const mailbox = {
  mailboxId: 'bob-mailbox-123456',
  readToken: 'read-token-abcdefghijklmnopqrstuvwxyz',
  writeToken: 'write-token-abcdefghijklmnopqrstuvwxyz',
};

before(async () => {
  tempDirectory = await mkdtemp(join(tmpdir(), 'p2p-relay-test-'));
  server = createRelayServer({
    storageFile: join(tempDirectory, 'relay.json'),
    now: () => new Date('2026-09-09T12:00:00.000Z'),
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  baseUrl = `http://127.0.0.1:${address.port}`;
});

after(async () => {
  await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  await rm(tempDirectory, { recursive: true, force: true });
});

test('registers mailbox, stores opaque packet, reads and acknowledges it', async () => {
  let response = await fetch(`${baseUrl}/v1/mailboxes`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(mailbox),
  });
  assert.equal(response.status, 201);

  const packet = {
    v: 1,
    messageId: '01990-message-0001',
    senderId: 'alice-device-1234',
    recipientId: mailbox.mailboxId,
    createdAt: '2026-09-09T12:00:00.000Z',
    expiresAt: '2026-09-16T12:00:00.000Z',
    hopLimit: 8,
    nonce: Buffer.alloc(12, 1).toString('base64'),
    cipherText: Buffer.from('opaque ciphertext').toString('base64'),
    mac: Buffer.alloc(16, 2).toString('base64'),
  };
  response = await fetch(`${baseUrl}/v1/mailboxes/${mailbox.mailboxId}/messages`, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${mailbox.writeToken}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(packet),
  });
  assert.equal(response.status, 202);

  response = await fetch(`${baseUrl}/v1/mailboxes/${mailbox.mailboxId}/messages`, {
    headers: { authorization: `Bearer ${mailbox.readToken}` },
  });
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).items, [packet]);

  response = await fetch(
    `${baseUrl}/v1/mailboxes/${mailbox.mailboxId}/messages/${packet.messageId}`,
    { method: 'DELETE', headers: { authorization: `Bearer ${mailbox.readToken}` } },
  );
  assert.equal(response.status, 204);
});

test('rejects mailbox reads with the write-only token', async () => {
  const response = await fetch(`${baseUrl}/v1/mailboxes/${mailbox.mailboxId}/messages`, {
    headers: { authorization: `Bearer ${mailbox.writeToken}` },
  });
  assert.equal(response.status, 401);
});

test('rejects a packet addressed to a different mailbox', async () => {
  const packet = {
    v: 1,
    messageId: '01990-message-0002',
    senderId: 'alice-device-1234',
    recipientId: 'different-mailbox',
    createdAt: '2026-09-09T12:00:00.000Z',
    expiresAt: '2026-09-16T12:00:00.000Z',
    hopLimit: 8,
    nonce: Buffer.alloc(12, 1).toString('base64'),
    cipherText: Buffer.from('opaque ciphertext').toString('base64'),
    mac: Buffer.alloc(16, 2).toString('base64'),
  };
  const response = await fetch(`${baseUrl}/v1/mailboxes/${mailbox.mailboxId}/messages`, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${mailbox.writeToken}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(packet),
  });
  assert.equal(response.status, 400);
});
