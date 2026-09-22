# Architecture

The encrypted packet is independent of transport. UI and messaging code never
talk directly to WebSockets, Bluetooth, or Wi-Fi APIs.

```text
UI -> AppController -> CryptoEngine -> EncryptedPacket -> TransportRouter
                                                        |-> Nearby transport
                                                        |-> Internet relay
                                                        `-> Local outbox
```

`TransportRouter` uses the lowest available priority value. The routing order is:

1. a directly reachable peer on the same local Wi-Fi/LAN;
2. the capability-authenticated Internet relay;
3. the persistent local outbox.

`EncryptedPacket` carries a versioned `cryptoSuite` identifier and an opaque
`cryptoHeader`. The current MVP suite leaves the header empty. A future Double
Ratchet engine can place its ratchet public key and message counters there
without changing relay, nearby, or delayed-delivery transports. Older v1
packets without those fields continue to decode as the MVP suite.

Future DTN forwarding reuses `EncryptedPacket`. Relays decrement `hopLimit`,
reject expired packets, deduplicate by `messageId`, and retain only a bounded
number of copies using a spray-and-wait policy.

## Package boundaries

- `core/identity`: local identity and contact invitation codec;
- `core/crypto`: swappable message crypto engine;
- `core/messaging`: transport-neutral records and persistence;
- `core/transport`: delivery adapters and routing policy;
- `core/update`: GitHub release validation and Android update coordination;
- `data`: encrypted local value store;
- `ui`: responsive Material client.

The UI reads cryptographic capabilities from `CryptoEngineInfo`. This prevents
the current static-key MVP from being presented as forward-secret while keeping
the screen independent of the eventual audited engine.

## Nearby LAN transport

Each client listens on a random TCP port and advertises `_p2pmsg._tcp` through
mDNS. It never publishes a user ID or display name. Instead it publishes
short-lived, contact-scoped tags derived from X25519 shared secrets. A tag also
binds the advertiser's public key, so two contacts do not announce the same
value and a passive observer cannot link them merely by comparing TXT records.

Discovery maps a matching tag to a contact and stores the resolved IPv4 endpoint
in an in-memory registry. `TransportRouter` then tries an HTTP POST containing
the already encrypted `EncryptedPacket`. The receiver only returns success if
the sender is a saved contact and authenticated decryption succeeds. Relay
mailbox capabilities are never sent over this plaintext LAN carrier.

## Internet relay configuration

The relay origin can come from a compile-time default or encrypted local app
settings. User-configured and normal release endpoints must use HTTPS and may
not contain credentials, a path, query, or fragment. Plain HTTP is accepted only
when the explicit `ALLOW_INSECURE_RELAY` development flag is compiled in.

Changing the relay closes the previous client, replaces the router adapter,
registers the local mailbox, and immediately retries the encrypted outbox. Relay
responses are bounded and time-limited before JSON decoding. Registration uses
an X25519 proof that binds the mailbox ID to the existing private identity key;
the private key never leaves the client. The Node relay persists committed
mailboxes and opaque packets in SQLite/WAL and enforces TTL, strict packet
schemas, rate limits, and byte/count quotas. No public relay is bundled with the
app, and remaining capability/operational blockers still prohibit a broad
public deployment.
