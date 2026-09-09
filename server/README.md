# Opaque relay MVP

The relay stores encrypted message envelopes. It has no identity private keys and
does not decrypt payloads. Each mailbox has two independent bearer capabilities:

- `readToken`: private to the mailbox owner; lists and acknowledges messages;
- `writeToken`: shared in contact invitations; deposits messages only.

Start locally (Node.js 22+; no package installation required):

```powershell
cd server
node relay.mjs
```

Environment variables:

- `PORT` defaults to `8787`;
- `HOST` defaults to `127.0.0.1`; use `0.0.0.0` only behind a firewall or TLS proxy;
- `RELAY_STORAGE` defaults to `./data/relay.json`.

Endpoints:

- `GET /health`
- `POST /v1/mailboxes`
- `POST /v1/mailboxes/:mailboxId/messages`
- `GET /v1/mailboxes/:mailboxId/messages`
- `DELETE /v1/mailboxes/:mailboxId/messages/:messageId`

The service binds to loopback by default. TLS termination, rate limits, storage
quotas per sender, capability rotation, metrics, and production persistence are
required before Internet deployment.
