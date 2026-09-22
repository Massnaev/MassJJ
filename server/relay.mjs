import {
  createHash,
  createHmac,
  createPrivateKey,
  createPublicKey,
  diffieHellman,
  hkdfSync,
  randomBytes,
  timingSafeEqual,
} from 'node:crypto';
import {
  chmodSync,
  closeSync,
  existsSync,
  mkdirSync,
  openSync,
  readSync,
} from 'node:fs';
import { createServer } from 'node:http';
import { dirname, resolve } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { fileURLToPath } from 'node:url';

const MAX_BODY_BYTES = 300 * 1024;
const X25519_PUBLIC_PREFIX = Buffer.from('302a300506032b656e032100', 'hex');
const X25519_PRIVATE_PREFIX = Buffer.from(
  '302e020100300506032b656e04220420',
  'hex',
);
const REGISTRATION_CONTEXT = 'massjj-relay-registration-v1';
const PACKET_FIELDS = new Set([
  'v',
  'cryptoSuite',
  'cryptoHeader',
  'messageId',
  'senderId',
  'recipientId',
  'createdAt',
  'expiresAt',
  'hopLimit',
  'nonce',
  'cipherText',
  'mac',
]);

const DEFAULT_LIMITS = Object.freeze({
  maxMailboxes: 10_000,
  maxMessagesPerMailbox: 500,
  maxMailboxBytes: 16 * 1024 * 1024,
  maxWriterBytesPerMailbox: 8 * 1024 * 1024,
  maxTotalMessageBytes: 1024 * 1024 * 1024,
  maxRequestsPerMinute: 240,
  maxWritesPerMinute: 60,
});

export function createRelayServer({
  storageFile,
  now = () => new Date(),
  limits: limitOverrides = {},
  trustProxy = false,
}) {
  const file = resolve(storageFile);
  const limits = validateLimits({ ...DEFAULT_LIMITS, ...limitOverrides });
  mkdirSync(dirname(file), { recursive: true });
  const database = openDatabase(file);
  const registrationPrivateKey = loadRegistrationPrivateKey(database);
  const registrationPublicKey = rawPublicKey(registrationPrivateKey);
  const sourceLimiter = new FixedWindowLimiter(
    limits.maxRequestsPerMinute,
    60_000,
    now,
  );
  const writerLimiter = new FixedWindowLimiter(
    limits.maxWritesPerMinute,
    60_000,
    now,
  );

  const server = createServer(async (request, response) => {
    try {
      const url = new URL(request.url ?? '/', 'http://relay.local');
      const path = decodePath(url.pathname);
      const source = requestSource(request, trustProxy);
      if (!sourceLimiter.consume(source)) {
        return sendRateLimit(response, 'source_rate_limited');
      }

      if (request.method === 'GET' && url.pathname === '/health') {
        database.prepare('SELECT 1').get();
        return sendJson(response, 200, { status: 'ok' });
      }

      if (request.method === 'GET' && url.pathname === '/v1/config') {
        return sendJson(response, 200, {
          v: 1,
          registrationPublicKey: registrationPublicKey.toString('base64url'),
        });
      }

      if (request.method === 'POST' && url.pathname === '/v1/mailboxes') {
        const body = await readJson(request);
        validateMailboxRegistration(body);
        verifyRegistrationProof(body, registrationPrivateKey);
        cleanupExpired(database, now());

        const existing = database
          .prepare(
            `SELECT read_token_hash, write_token_hash, public_key
             FROM mailboxes WHERE mailbox_id = ?`,
          )
          .get(body.mailboxId);
        const readTokenHash = hashToken(body.readToken);
        const writeTokenHash = hashToken(body.writeToken);
        if (existing) {
          if (
            !hashMatches(readTokenHash, existing.read_token_hash) ||
            !hashMatches(writeTokenHash, existing.write_token_hash) ||
            body.publicKey !== existing.public_key
          ) {
            return sendError(response, 409, 'mailbox_exists');
          }
          return sendJson(response, 200, { mailboxId: body.mailboxId });
        }

        const mailboxCount = Number(
          database.prepare('SELECT COUNT(*) AS count FROM mailboxes').get().count,
        );
        if (mailboxCount >= limits.maxMailboxes) {
          return sendError(response, 503, 'mailbox_capacity_reached');
        }
        database
          .prepare(
            `INSERT INTO mailboxes (
               mailbox_id, read_token_hash, write_token_hash, public_key, created_at
             ) VALUES (?, ?, ?, ?, ?)`,
          )
          .run(
            body.mailboxId,
            readTokenHash,
            writeTokenHash,
            body.publicKey,
            now().toISOString(),
          );
        return sendJson(response, 201, { mailboxId: body.mailboxId });
      }

      if (
        path.length === 4 &&
        path[0] === 'v1' &&
        path[1] === 'mailboxes' &&
        path[3] === 'messages'
      ) {
        const mailboxId = path[2];
        validateMailboxId(mailboxId);
        const mailbox = database
          .prepare(
            `SELECT read_token_hash, write_token_hash
             FROM mailboxes WHERE mailbox_id = ?`,
          )
          .get(mailboxId);
        if (!mailbox) return sendError(response, 404, 'mailbox_not_found');

        if (request.method === 'POST') {
          const token = bearerToken(request);
          if (!token || !tokenMatches(token, mailbox.write_token_hash)) {
            return sendError(response, 401, 'invalid_write_token');
          }
          const writerHash = hashToken(token);
          if (!writerLimiter.consume(`${mailboxId}:${writerHash}`)) {
            return sendRateLimit(response, 'writer_rate_limited');
          }
          const packet = await readJson(request);
          const packetJson = validatePacket(packet, mailboxId, now());
          const packetBytes = Buffer.byteLength(packetJson);
          cleanupExpired(database, now());

          const outcome = inImmediateTransaction(database, () => {
            const duplicate = database
              .prepare(
                `SELECT 1 FROM messages
                 WHERE mailbox_id = ? AND message_id = ?`,
              )
              .get(mailboxId, packet.messageId);
            if (duplicate) return 'duplicate';

            const mailboxUsage = database
              .prepare(
                `SELECT COUNT(*) AS count, COALESCE(SUM(packet_bytes), 0) AS bytes
                 FROM messages WHERE mailbox_id = ?`,
              )
              .get(mailboxId);
            const writerUsage = database
              .prepare(
                `SELECT COALESCE(SUM(packet_bytes), 0) AS bytes
                 FROM messages WHERE mailbox_id = ? AND writer_hash = ?`,
              )
              .get(mailboxId, writerHash);
            const totalUsage = database
              .prepare(
                'SELECT COALESCE(SUM(packet_bytes), 0) AS bytes FROM messages',
              )
              .get();
            if (
              Number(mailboxUsage.count) >= limits.maxMessagesPerMailbox ||
              Number(mailboxUsage.bytes) + packetBytes > limits.maxMailboxBytes ||
              Number(writerUsage.bytes) + packetBytes >
                limits.maxWriterBytesPerMailbox
            ) {
              return 'mailbox_full';
            }
            if (
              Number(totalUsage.bytes) + packetBytes > limits.maxTotalMessageBytes
            ) {
              return 'relay_full';
            }
            database
              .prepare(
                `INSERT INTO messages (
                   mailbox_id, message_id, sender_id, created_at, expires_at,
                   writer_hash, packet_json, packet_bytes
                 ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
              )
              .run(
                mailboxId,
                packet.messageId,
                packet.senderId,
                new Date(packet.createdAt).toISOString(),
                new Date(packet.expiresAt).toISOString(),
                writerHash,
                packetJson,
                packetBytes,
              );
            return 'inserted';
          });
          if (outcome === 'mailbox_full') {
            return sendError(response, 429, 'mailbox_quota_exceeded');
          }
          if (outcome === 'relay_full') {
            return sendError(response, 503, 'relay_storage_exhausted');
          }
          return sendJson(response, 202, { messageId: packet.messageId });
        }

        if (request.method === 'GET') {
          if (!authorized(request, mailbox.read_token_hash)) {
            return sendError(response, 401, 'invalid_read_token');
          }
          cleanupExpired(database, now());
          const requestedLimit = Number.parseInt(
            url.searchParams.get('limit') ?? '100',
            10,
          );
          const limit = Number.isFinite(requestedLimit)
            ? Math.max(1, Math.min(requestedLimit, 100))
            : 100;
          const rows = database
            .prepare(
              `SELECT packet_json FROM messages
               WHERE mailbox_id = ? ORDER BY sequence ASC LIMIT ?`,
            )
            .all(mailboxId, limit);
          return sendJson(response, 200, {
            items: rows.map((row) => JSON.parse(row.packet_json)),
          });
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
        validateMailboxId(mailboxId);
        validateIdentifier(messageId, 'messageId');
        const mailbox = database
          .prepare('SELECT read_token_hash FROM mailboxes WHERE mailbox_id = ?')
          .get(mailboxId);
        if (!mailbox) return sendError(response, 404, 'mailbox_not_found');
        if (!authorized(request, mailbox.read_token_hash)) {
          return sendError(response, 401, 'invalid_read_token');
        }
        database
          .prepare(
            'DELETE FROM messages WHERE mailbox_id = ? AND message_id = ?',
          )
          .run(mailboxId, messageId);
        response.writeHead(204, { 'cache-control': 'no-store' }).end();
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

  server.on('close', () => database.close());
  return server;
}

function openDatabase(file) {
  rejectLegacyJsonState(file);
  const database = new DatabaseSync(file);
  database.exec(`
    PRAGMA journal_mode = WAL;
    PRAGMA synchronous = FULL;
    PRAGMA foreign_keys = ON;
    PRAGMA busy_timeout = 5000;

    CREATE TABLE IF NOT EXISTS metadata (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    ) STRICT;

    CREATE TABLE IF NOT EXISTS mailboxes (
      mailbox_id TEXT PRIMARY KEY,
      read_token_hash TEXT NOT NULL,
      write_token_hash TEXT NOT NULL,
      public_key TEXT NOT NULL,
      created_at TEXT NOT NULL
    ) STRICT;

    CREATE TABLE IF NOT EXISTS messages (
      sequence INTEGER PRIMARY KEY AUTOINCREMENT,
      mailbox_id TEXT NOT NULL REFERENCES mailboxes(mailbox_id) ON DELETE CASCADE,
      message_id TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      created_at TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      writer_hash TEXT NOT NULL,
      packet_json TEXT NOT NULL,
      packet_bytes INTEGER NOT NULL CHECK(packet_bytes > 0),
      UNIQUE(mailbox_id, message_id)
    ) STRICT;

    CREATE INDEX IF NOT EXISTS messages_mailbox_sequence
      ON messages(mailbox_id, sequence);
    CREATE INDEX IF NOT EXISTS messages_expires
      ON messages(expires_at);
    CREATE INDEX IF NOT EXISTS messages_writer
      ON messages(mailbox_id, writer_hash);
  `);
  try {
    chmodSync(file, 0o600);
  } catch {
    // Windows and some mounted filesystems do not expose POSIX file modes.
  }
  return database;
}

function rejectLegacyJsonState(file) {
  if (!existsSync(file)) return;
  const descriptor = openSync(file, 'r');
  try {
    const prefix = Buffer.alloc(64);
    const length = readSync(descriptor, prefix, 0, prefix.length, 0);
    if (prefix.subarray(0, length).toString('utf8').trimStart().startsWith('{')) {
      throw new Error(
        'Legacy JSON relay state is not accepted. Keep it as a backup, use a new .sqlite path, and let closed-alpha clients re-register.',
      );
    }
  } finally {
    closeSync(descriptor);
  }
}

function loadRegistrationPrivateKey(database) {
  const configured = process.env.RELAY_REGISTRATION_KEY?.trim();
  if (configured) return importPrivateKey(decodeBase64Url(configured, 32));
  const existing = database
    .prepare("SELECT value FROM metadata WHERE key = 'registration_private_key'")
    .get();
  if (existing) return importPrivateKey(decodeBase64Url(existing.value, 32));
  const seed = randomBytes(32);
  database
    .prepare('INSERT INTO metadata (key, value) VALUES (?, ?)')
    .run('registration_private_key', seed.toString('base64url'));
  return importPrivateKey(seed);
}

function importPrivateKey(raw) {
  return createPrivateKey({
    key: Buffer.concat([X25519_PRIVATE_PREFIX, raw]),
    format: 'der',
    type: 'pkcs8',
  });
}

function importPublicKey(raw) {
  return createPublicKey({
    key: Buffer.concat([X25519_PUBLIC_PREFIX, raw]),
    format: 'der',
    type: 'spki',
  });
}

function rawPublicKey(privateKey) {
  return createPublicKey(privateKey)
    .export({ format: 'der', type: 'spki' })
    .subarray(-32);
}

function verifyRegistrationProof(body, registrationPrivateKey) {
  const publicKeyBytes = decodeBase64Url(body.publicKey, 32);
  const expectedMailboxId = createHash('sha256')
    .update(publicKeyBytes)
    .digest()
    .subarray(0, 16)
    .toString('base64url');
  if (body.mailboxId !== expectedMailboxId) {
    throw new HttpError(401, 'invalid_registration_proof');
  }
  let sharedSecret;
  try {
    sharedSecret = diffieHellman({
      privateKey: registrationPrivateKey,
      publicKey: importPublicKey(publicKeyBytes),
    });
  } catch {
    throw new HttpError(401, 'invalid_registration_proof');
  }
  const proofKey = Buffer.from(
    hkdfSync(
      'sha256',
      sharedSecret,
      Buffer.alloc(0),
      Buffer.from(REGISTRATION_CONTEXT),
      32,
    ),
  );
  const expected = createHmac('sha256', proofKey)
    .update(registrationMessage(body))
    .digest();
  const actual = decodeBase64Url(body.proof, 32);
  if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) {
    throw new HttpError(401, 'invalid_registration_proof');
  }
}

function registrationMessage(body) {
  return Buffer.from(
    `${REGISTRATION_CONTEXT}\n${body.mailboxId}\n${body.publicKey}\n${body.readToken}\n${body.writeToken}`,
    'utf8',
  );
}

function inImmediateTransaction(database, operation) {
  database.exec('BEGIN IMMEDIATE');
  try {
    const result = operation();
    database.exec('COMMIT');
    return result;
  } catch (error) {
    database.exec('ROLLBACK');
    throw error;
  }
}

function cleanupExpired(database, currentTime) {
  database
    .prepare('DELETE FROM messages WHERE expires_at <= ?')
    .run(currentTime.toISOString());
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
  if (!isPlainObject(body) || body.v !== 1) {
    throw new HttpError(400, 'invalid_mailbox');
  }
  const fields = new Set([
    'v',
    'mailboxId',
    'publicKey',
    'readToken',
    'writeToken',
    'proof',
  ]);
  if (Object.keys(body).some((key) => !fields.has(key))) {
    throw new HttpError(400, 'invalid_mailbox');
  }
  validateMailboxId(body.mailboxId);
  decodeBase64Url(body.publicKey, 32);
  requireToken(body.readToken, 'readToken');
  requireToken(body.writeToken, 'writeToken');
  if (body.readToken === body.writeToken) {
    throw new HttpError(400, 'capabilities_must_differ');
  }
  decodeBase64Url(body.proof, 32);
}

function validatePacket(packet, mailboxId, currentTime) {
  if (!isPlainObject(packet) || packet.v !== 1) {
    throw new HttpError(400, 'invalid_packet');
  }
  if (Object.keys(packet).some((key) => !PACKET_FIELDS.has(key))) {
    throw new HttpError(400, 'invalid_packet');
  }
  validateIdentifier(packet.messageId, 'messageId');
  validateMailboxId(packet.senderId, 'senderId');
  validateMailboxId(packet.recipientId, 'recipientId');
  if (packet.recipientId !== mailboxId) {
    throw new HttpError(400, 'recipient_mismatch');
  }
  requireString(packet.cryptoSuite, 'cryptoSuite', 1, 64);
  if (!isPlainObject(packet.cryptoHeader)) {
    throw new HttpError(400, 'invalid_cryptoHeader');
  }
  if (Buffer.byteLength(JSON.stringify(packet.cryptoHeader)) > 4096) {
    throw new HttpError(400, 'invalid_cryptoHeader');
  }
  if (!Number.isInteger(packet.hopLimit) || packet.hopLimit < 0 || packet.hopLimit > 16) {
    throw new HttpError(400, 'invalid_hop_limit');
  }
  const createdAt = parseCanonicalTimestamp(packet.createdAt);
  const expiresAt = parseCanonicalTimestamp(packet.expiresAt);
  const currentMillis = currentTime.getTime();
  const maxLifetime = 14 * 24 * 60 * 60 * 1000;
  if (
    createdAt > currentMillis + 5 * 60 * 1000 ||
    expiresAt <= currentMillis ||
    expiresAt - createdAt <= 0 ||
    expiresAt - createdAt > maxLifetime ||
    expiresAt - currentMillis > maxLifetime
  ) {
    throw new HttpError(400, 'invalid_expiration');
  }
  requireBase64(packet.nonce, 'nonce', 128);
  requireBase64(packet.cipherText, 'cipherText', 256 * 1024);
  requireBase64(packet.mac, 'mac', 128);
  return JSON.stringify(packet);
}

function parseCanonicalTimestamp(value) {
  if (
    typeof value !== 'string' ||
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$/.test(value)
  ) {
    throw new HttpError(400, 'invalid_timestamp');
  }
  const parsed = Date.parse(value);
  if (!Number.isFinite(parsed)) throw new HttpError(400, 'invalid_timestamp');
  return parsed;
}

function validateMailboxId(value, name = 'mailboxId') {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{22}$/.test(value)) {
    throw new HttpError(400, `invalid_${name}`);
  }
}

function validateIdentifier(value, name) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{8,128}$/.test(value)) {
    throw new HttpError(400, `invalid_${name}`);
  }
}

function requireString(value, name, minLength, maxLength) {
  if (typeof value !== 'string' || value.length < minLength || value.length > maxLength) {
    throw new HttpError(400, `invalid_${name}`);
  }
}

function requireToken(value, name) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{32,128}$/.test(value)) {
    throw new HttpError(400, `invalid_${name}`);
  }
}

function requireBase64(value, name, maxBytes) {
  if (typeof value !== 'string' || value.length === 0 || value.length > Math.ceil((maxBytes * 4) / 3) + 4) {
    throw new HttpError(400, `invalid_${name}`);
  }
  const decoded = Buffer.from(value, 'base64');
  if (decoded.length === 0 || decoded.toString('base64').replaceAll('=', '') !== value.replaceAll('=', '')) {
    throw new HttpError(400, `invalid_${name}`);
  }
}

function decodeBase64Url(value, expectedBytes) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]+$/.test(value)) {
    throw new HttpError(400, 'invalid_base64url');
  }
  const decoded = Buffer.from(value, 'base64url');
  if (
    decoded.length !== expectedBytes ||
    decoded.toString('base64url') !== value
  ) {
    throw new HttpError(400, 'invalid_base64url');
  }
  return decoded;
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function authorized(request, expectedHash) {
  const token = bearerToken(request);
  return token !== null && tokenMatches(token, expectedHash);
}

function bearerToken(request) {
  const authorization = request.headers.authorization ?? '';
  if (!authorization.startsWith('Bearer ')) return null;
  const token = authorization.slice(7);
  return /^[A-Za-z0-9_-]{32,128}$/.test(token) ? token : null;
}

function tokenMatches(token, expectedHash) {
  return hashMatches(hashToken(token), expectedHash);
}

function hashMatches(actualHash, expectedHash) {
  const actual = Buffer.from(actualHash, 'hex');
  const expected = Buffer.from(expectedHash, 'hex');
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

function hashToken(token) {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

function decodePath(pathname) {
  try {
    return pathname
      .split('/')
      .filter(Boolean)
      .map((part) => decodeURIComponent(part));
  } catch {
    throw new HttpError(400, 'invalid_path');
  }
}

function requestSource(request, trustProxy) {
  if (trustProxy && isLoopback(request.socket.remoteAddress)) {
    const forwarded = request.headers['x-forwarded-for'];
    if (typeof forwarded === 'string') {
      const first = forwarded.split(',')[0].trim();
      if (first.length > 0 && first.length <= 64) return first;
    }
  }
  return request.socket.remoteAddress ?? 'unknown';
}

function isLoopback(address) {
  return address === '127.0.0.1' || address === '::1' || address === '::ffff:127.0.0.1';
}

function validateLimits(limits) {
  for (const [name, value] of Object.entries(limits)) {
    if (!Number.isSafeInteger(value) || value <= 0) {
      throw new TypeError(`Invalid relay limit: ${name}`);
    }
  }
  return Object.freeze(limits);
}

class FixedWindowLimiter {
  constructor(limit, windowMilliseconds, now) {
    this.limit = limit;
    this.windowMilliseconds = windowMilliseconds;
    this.now = now;
    this.buckets = new Map();
  }

  consume(key) {
    const current = this.now().getTime();
    let bucket = this.buckets.get(key);
    if (!bucket || current - bucket.startedAt >= this.windowMilliseconds) {
      bucket = { startedAt: current, count: 0 };
      this.buckets.set(key, bucket);
    }
    bucket.count += 1;
    if (this.buckets.size > 10_000) {
      this.prune(current);
      while (this.buckets.size > 10_000) {
        this.buckets.delete(this.buckets.keys().next().value);
      }
    }
    return bucket.count <= this.limit;
  }

  prune(current) {
    for (const [key, bucket] of this.buckets) {
      if (current - bucket.startedAt >= this.windowMilliseconds) {
        this.buckets.delete(key);
      }
    }
  }
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

function sendRateLimit(response, code) {
  response.setHeader('retry-after', '60');
  sendError(response, 429, code);
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
  const storageFile = process.env.RELAY_STORAGE ?? './data/relay.sqlite';
  const trustProxy = process.env.RELAY_TRUST_PROXY === 'true';
  const limits = {
    maxMailboxes: envPositiveInteger(
      'RELAY_MAX_MAILBOXES',
      DEFAULT_LIMITS.maxMailboxes,
    ),
    maxMessagesPerMailbox: envPositiveInteger(
      'RELAY_MAX_MESSAGES_PER_MAILBOX',
      DEFAULT_LIMITS.maxMessagesPerMailbox,
    ),
    maxMailboxBytes: envPositiveInteger(
      'RELAY_MAX_MAILBOX_BYTES',
      DEFAULT_LIMITS.maxMailboxBytes,
    ),
    maxWriterBytesPerMailbox: envPositiveInteger(
      'RELAY_MAX_WRITER_BYTES_PER_MAILBOX',
      DEFAULT_LIMITS.maxWriterBytesPerMailbox,
    ),
    maxTotalMessageBytes: envPositiveInteger(
      'RELAY_MAX_TOTAL_MESSAGE_BYTES',
      DEFAULT_LIMITS.maxTotalMessageBytes,
    ),
    maxRequestsPerMinute: envPositiveInteger(
      'RELAY_MAX_REQUESTS_PER_MINUTE',
      DEFAULT_LIMITS.maxRequestsPerMinute,
    ),
    maxWritesPerMinute: envPositiveInteger(
      'RELAY_MAX_WRITES_PER_MINUTE',
      DEFAULT_LIMITS.maxWritesPerMinute,
    ),
  };
  const server = createRelayServer({
    storageFile,
    trustProxy,
    limits,
  });
  server.listen(port, host, () => {
    const address = server.address();
    const actualPort = typeof address === 'object' && address ? address.port : port;
    console.log(`Relay listening on http://${host}:${actualPort}`);
  });
}

function envPositiveInteger(name, fallback) {
  const raw = process.env[name];
  if (raw === undefined) return fallback;
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new TypeError(`${name} must be a positive integer`);
  }
  return value;
}
