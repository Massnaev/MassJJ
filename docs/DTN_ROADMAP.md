# Opportunistic offline delivery roadmap

MassJJ must eventually deliver an encrypted packet between distant devices
without Internet access when a chain of participating phones meets over time:

```text
Phone A -> passer-by B -> device C -> Phone D
```

This is a mandatory product direction, not a feature of the current alpha.
Delivery is opportunistic: it is possible only if a physical chain of contacts
forms before the packet expires. The application cannot promise a delivery time
or successful delivery when no such chain exists.

## Privacy boundary

- The author encrypts the message for the final recipient before any transport
  sees it.
- Intermediate devices store and forward only an opaque `EncryptedPacket` and
  cannot read or alter its authenticated contents.
- Relaying must not reveal recovery data or private identity keys.
- Transport implementations remain independent from the crypto engine, so the
  same packet can travel through LAN, Bluetooth, Wi-Fi Direct, DTN, or an
  Internet relay.

Encryption protects message contents, but routing metadata can still reveal
that devices met, when they met, packet size, and forwarding patterns. Metadata
minimization and padding therefore belong in the protocol design before public
testing.

## Delivery stages

1. Discover nearby MassJJ devices with Bluetooth Low Energy without publishing
   stable identity identifiers.
2. Negotiate a higher-bandwidth local link, preferably Wi-Fi Direct or another
   Android-supported peer-to-peer channel, with BLE as a small-packet fallback.
3. Exchange compact inventories of eligible encrypted packets.
4. Store accepted packets in a bounded encrypted relay vault on the carrier's
   phone.
5. Carry them until another useful peer is encountered, then forward them using
   an initial `spray-and-wait` policy rather than uncontrolled flooding.
6. Deliver to the destination, deduplicate, and optionally propagate a signed
   delivery receipt so expired copies can be removed.

## Required safeguards

- packet ID deduplication, expiration time, hop limit, copy budget, and maximum
  packet size;
- strict per-peer and total byte quotas with user-configurable storage and
  battery budgets;
- authenticated packet headers and resistance to replay, queue flooding, and
  malicious inventory advertisements;
- rotating discovery identifiers and no public stable identity over BLE;
- explicit user consent for acting as a carrier, with pause and purge controls;
- Android background-execution, permission, and battery-impact testing;
- protocol-version negotiation so old clients cannot corrupt routing state.

## Incremental milestones

1. Complete and physically test direct one-hop delivery on the same LAN.
2. Add BLE discovery and direct nearby transfer between two Android phones with
   no router and no Internet.
3. Add a persistent bounded carrier vault and one intermediate hop (`A -> B ->
   D`).
4. Add multi-hop `A -> B -> C -> D`, copy budgets, receipts, and simulation
   tests for delivery ratio, latency, storage, and battery use.
5. Run a consented closed field test before enabling public carriage.

## MVP acceptance criteria

- Four Android devices can complete `A -> B -> C -> D` while never sharing a
  LAN and with Internet disabled throughout the test.
- Only D can decrypt the message; B and C retain no readable message content.
- Duplicate encounters do not create duplicate chat messages.
- Expired, over-budget, and over-hop-limit packets are rejected and removed.
- Restarting any carrier device does not lose accepted packets unexpectedly.
- Users can see, pause, limit, and clear the storage used for other people's
  packets.
