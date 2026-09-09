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

1. a directly reachable nearby peer (adapter planned);
2. the capability-authenticated Internet relay;
3. the persistent local outbox.

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
