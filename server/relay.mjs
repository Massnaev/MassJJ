import { createHash, timingSafeEqual } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const MAX_BODY_BYTES = 300 * 1024;
const MAX_MESSAGES_PER_MAILBOX = 500;

export function createRelayServer({ storageFile, now = () => new Date() }) {
  const file = resolve(storageFile);
  let statePromise = loadState(file);
  let writeQueue = Promise.resolve();

  const server = createServer(async (request, response) => {
    try {
      const url = new URL(request.url ?? '/', 'http://relay.local');
      const path = url.pathname.split('/').filter(Boolean);

      if (request.method === 'GET' && url.pathname === '/health') {
        return sendJson(response, 200, { status: 'ok' });
      }

      if (request.method === 'POST' && url.pathname === '/v1/mailboxes') {
        const body = await readJson(request);
        validateMailboxRegistration(body);
        const state = await statePromise;
        const existing = state.mailboxes[body.mailboxId];
        if (existing) {
          if (!tokenMatches(body.readToken, existing.readTokenHash)) {
            return sendError(response, 409, 'mailbox_exists');
          }
          return sendJson(response, 200, { mailboxId: body.mailboxId });
        }
        state.mailboxes[body.mailboxId] = {
          readTokenHash: hashToken(body.readToken),
          writeTokenHash: hashToken(body.writeToken),
          messages: [],
        };
        await persist();
        return sendJson(response, 201, { mailboxId: body.mailboxId });
      }

      if (path.length === 4 && path[0] === 'v1' && path[1] === 'mailboxes' && path[3] === 'messages') {
        const mailboxId = path[2];
        const state = await statePromise;
        const mailbox = state.mailboxes[mailboxId];
        if (!mailbox) return sendError(response, 404, 'mailbox_not_found');

        if (request.method === 'POST') {
          if (!authorized(request, mailbox.writeTokenHash)) {
            return sendError(response, 401, 'invalid_write_token');
          }
          const packet = await readJson(request);
          validatePacket(packet, mailboxId, now());
          if (!mailbox.messages.some((item) => item.messageId === packet.messageId)) {
            mailbox.messages.push(packet);
            if (mailbox.messages.length > MAX_MESSAGES_PER_MAILBOX) {
              mailbox.messages.splice(0, mailbox.messages.length - MAX_MESSAGES_PER_MAILBOX);
            }
            await persist();
          }
          return sendJson(response, 202, { messageId: packet.messageId });
        }

        if (request.method === 'GET') {
          if (!authorized(request, mailbox.readTokenHash)) {
            return sendError(response, 401, 'invalid_read_token');
          }
          const currentTime = now().getTime();
          const before = mailbox.messages.length;
          mailbox.messages = mailbox.messages.filter(
            (packet) => Date.parse(packet.expiresAt) > currentTime,
          );
          if (mailbox.messages.length !== before) await persist();
          const requestedLimit = Number.parseInt(url.searchParams.get('limit') ?? '100', 10);
          const limit = Number.isFinite(requestedLimit)
            ? Math.max(1, Math.min(requestedLimit, 100))
            : 100;
          return sendJson(response, 200, { items: mailbox.messages.slice(0, limit) });
        }
      }

      if (
        path.length === 5 &&
        path[0] === 'v1' &&
        path[1] === 'mailboxes' &&
        path[3] === 'messages' &&
        request.method === 'DELETE'
      ) {
        const mailboxId = path[2];
        const messageId = path[4];
        const state = await statePromise;
        const mailbox = state.mailboxes[mailboxId];
        if (!mailbox) return sendError(response, 404, 'mailbox_not_found');
        if (!authorized(request, mailbox.readTokenHash)) {
          return sendError(response, 401, 'invalid_read_token');
        }
        mailbox.messages = mailbox.messages.filter((item) => item.messageId !== messageId);
        await persist();
        response.writeHead(204).end();
        return;
      }

      return sendError(response, 404, 'not_found');
    } catch (error) {
      if (error instanceof HttpError) {
        return sendError(response, error.status, error.code);
      }
      console.error(error);
      return sendError(response, 500, 'internal_error');
    }
  });

  async function persist() {
    const state = await statePromise;
    writeQueue = writeQueue.then(async () => {
      await mkdir(dirname(file), { recursive: true });
      await writeFile(file, JSON.stringify(state), { encoding: 'utf8', mode: 0o600 });
    });
    await writeQueue;
  }

  return server;
}

async function loadState(file) {
  try {
    const parsed = JSON.parse(await readFile(file, 'utf8'));
    if (parsed.version !== 1 || typeof parsed.mailboxes !== 'object') throw new Error('invalid state');
    return parsed;
  } catch (error) {
    if (error.code === 'ENOENT') return { version: 1, mailboxes: {} };
    throw error;
  }
}

async function readJson(request) {
  const contentType = request.headers['content-type'] ?? '';
  if (!contentType.toLowerCase().startsWith('application/json')) {
    throw new HttpError(415, 'json_required');
  }
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > MAX_BODY_BYTES) throw new HttpError(413, 'body_too_large');
    chunks.push(chunk);
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    throw new HttpError(400, 'invalid_json');
  }
}

function validateMailboxRegistration(body) {
  if (!body || typeof body !== 'object') throw new HttpError(400, 'invalid_mailbox');
  requireString(body.mailboxId, 'mailboxId', 16, 128);
  requireToken(body.readToken, 'readToken');
  requireToken(body.writeToken, 'writeToken');
}

function validatePacket(packet, mailboxId, currentTime) {
  if (!packet || typeof packet !== 'object' || packet.v !== 1) {
    throw new HttpError(400, 'invalid_packet');
  }
  requireString(packet.messageId, 'messageId', 8, 128);
  requireString(packet.senderId, 'senderId', 8, 128);
  requireString(packet.recipientId, 'recipientId', 8, 128);
  if (packet.recipientId !== mailboxId) throw new HttpError(400, 'recipient_mismatch');
  if (!Number.isInteger(packet.hopLimit) || packet.hopLimit < 0 || packet.hopLimit > 16) {
    throw new HttpError(400, 'invalid_hop_limit');
  }
  const createdAt = Date.parse(packet.createdAt);
  const expiresAt = Date.parse(packet.expiresAt);
  if (!Number.isFinite(createdAt) || !Number.isFinite(expiresAt)) {
    throw new HttpError(400, 'invalid_timestamp');
  }
  if (expiresAt <= currentTime.getTime() || expiresAt - createdAt > 14 * 24 * 60 * 60 * 1000) {
    throw new HttpError(400, 'invalid_expiration');
  }
  requireBase64(packet.nonce, 'nonce', 128);
  requireBase64(packet.cipherText, 'cipherText', 256 * 1024);
  requireBase64(packet.mac, 'mac', 128);
}

function requireString(value, name, minLength, maxLength) {
  if (typeof value !== 'string' || value.length < minLength || value.length > maxLength) {
    throw new HttpError(400, `invalid_${name}`);
  }
}

function requireToken(value, name) {
  requireString(value, name, 32, 256);
}

function requireBase64(value, name, maxBytes) {
  if (typeof value !== 'string' || value.length === 0 || value.length > Math.ceil(maxBytes * 4 / 3) + 4) {
    throw new HttpError(400, `invalid_${name}`);
  }
  const decoded = Buffer.from(value, 'base64');
  if (decoded.length === 0 || decoded.toString('base64').replaceAll('=', '') !== value.replaceAll('=', '')) {
    throw new HttpError(400, `invalid_${name}`);
  }
}

function authorized(request, expectedHash) {
  const authorization = request.headers.authorization ?? '';
  if (!authorization.startsWith('Bearer ')) return false;
  return tokenMatches(authorization.slice(7), expectedHash);
}

function tokenMatches(token, expectedHash) {
  const actual = Buffer.from(hashToken(token), 'hex');
  const expected = Buffer.from(expectedHash, 'hex');
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

function hashToken(token) {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

function sendJson(response, status, body) {
  const encoded = Buffer.from(JSON.stringify(body));
  response.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': encoded.length,
    'cache-control': 'no-store',
  });
  response.end(encoded);
}

function sendError(response, status, code) {
  sendJson(response, status, { error: code });
}

class HttpError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

const isMain = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  const port = Number.parseInt(process.env.PORT ?? '8787', 10);
  const host = process.env.HOST ?? '127.0.0.1';
  const storageFile = process.env.RELAY_STORAGE ?? './data/relay.json';
  const server = createRelayServer({ storageFile });
  server.listen(port, host, () => {
    console.log(`Relay listening on http://${host}:${port}`);
  });
}
