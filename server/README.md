# Opaque relay

The relay stores end-to-end encrypted message envelopes and cannot decrypt
their contents. It uses SQLite in WAL mode and binds to loopback by default so a
TLS reverse proxy can be its only public entry point.

Each mailbox has two independent bearer capabilities:

- `readToken`: private to the mailbox owner; lists and acknowledges messages;
- `writeToken`: present in the owner's invitation; deposits messages only.

Mailbox creation additionally requires an X25519 proof made with the private
identity key whose public-key hash is the mailbox ID. An observer who knows a
public user ID cannot claim its mailbox first.

## Local use

Node.js 22.13 or newer is required. No package installation is needed.

```powershell
cd server
npm test
npm start
```

The defaults are `127.0.0.1:8787` and `./data/relay.sqlite`. The SQLite database,
WAL, and SHM files contain capability hashes, routing metadata, and encrypted
packets and must never be committed.

This proof protocol is intentionally incompatible with the earlier unpublished
JSON relay. There has never been an official public relay or binary release, so
the first deployment must use the hardened client and server together. Keep any
old `relay.json` only as a development backup, start with a new `.sqlite` path,
and let clients re-register and retry their encrypted outboxes. The server
detects a JSON file at `RELAY_STORAGE` and fails clearly instead of overwriting
or misreading it.

## Endpoints

- `GET /health`
- `GET /v1/config`
- `POST /v1/mailboxes`
- `POST /v1/mailboxes/:mailboxId/messages`
- `GET /v1/mailboxes/:mailboxId/messages`
- `DELETE /v1/mailboxes/:mailboxId/messages/:messageId`

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `HOST` | `127.0.0.1` | Listen address. Keep loopback behind Caddy. |
| `PORT` | `8787` | Local listen port. |
| `RELAY_STORAGE` | `./data/relay.sqlite` | SQLite database path. |
| `RELAY_TRUST_PROXY` | `false` | Trust `X-Forwarded-For` only when the TCP peer is loopback. Set `true` behind the supplied Caddy configuration. |
| `RELAY_REGISTRATION_KEY` | generated in SQLite | Optional base64url 32-byte server X25519 seed. Normally preserve it by backing up the database. |
| `RELAY_MAX_MAILBOXES` | `10000` | Maximum registered mailboxes. |
| `RELAY_MAX_MESSAGES_PER_MAILBOX` | `500` | Maximum queued message count per mailbox. |
| `RELAY_MAX_MAILBOX_BYTES` | `16777216` | Maximum queued serialized bytes per mailbox. |
| `RELAY_MAX_WRITER_BYTES_PER_MAILBOX` | `8388608` | Maximum queued bytes attributed to one write capability. |
| `RELAY_MAX_TOTAL_MESSAGE_BYTES` | `1073741824` | Maximum queued bytes across the relay. |
| `RELAY_MAX_REQUESTS_PER_MINUTE` | `240` | Requests per source address per minute. |
| `RELAY_MAX_WRITES_PER_MINUTE` | `60` | Message writes per capability per minute. |

Packets are rejected explicitly when a quota is full. Existing queued messages
are never silently evicted to make room for a new write. Expired packets are
cleaned during ordinary relay traffic without requiring their owner to poll.

## Internet deployment

Use the reviewed examples in [`deploy/`](deploy/):

- Caddy terminates HTTPS and forwards only to loopback;
- systemd runs the relay as a restricted non-root user;
- the environment file sets conservative alpha limits;
- the SQLite database directory is the only writable service path.

Follow [`docs/RELAY_DEPLOYMENT.md`](../docs/RELAY_DEPLOYMENT.md). Do not expose
port 8787 publicly. A deployment is not production-secure merely because these
controls are present: the static-key message protocol still lacks forward
secrecy, independent audit, and per-contact relay write capabilities.
