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
