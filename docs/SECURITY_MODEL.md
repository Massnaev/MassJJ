# MVP security model

## What the MVP protects

- private identity seed and app records are encrypted at rest with AES-256-GCM;
- the local vault master key is stored in Android Keystore, iOS Keychain, or the
  Windows secure-storage implementation;
- message bodies are authenticated and encrypted before entering the outbox;
- invitation and packet parsers validate protocol versions and key sizes.
- invitation QR codes contain the same public invitation bundle as `p2p1.…`:
  public key, display name, fingerprint, and write-only mailbox capability. They
  never contain the private seed, read capability, or recovery code.

Camera access is requested only after the user opens the scanner on Android or
iOS. Windows does not initialize a camera plugin and retains text-code entry.
The scanned payload is passed through the same strict invitation parser as a
manually pasted code.

## What is deliberately not production-ready

`MvpCryptoEngine` derives a conversation key from static X25519 identity keys.
AES-GCM uses a fresh random nonce, but the scheme has no Double Ratchet, forward
secrecy, post-compromise security, prekeys, multi-device session management, or
formal protocol audit. It must be replaced with an audited Signal-compatible
PQXDH/Double Ratchet core before any production deployment.

The packet envelope now reserves `cryptoSuite` and `cryptoHeader` fields for
that migration. This is only protocol plumbing; it does not add forward secrecy
to the MVP. The staged replacement plan is documented in
[`RATCHET_MIGRATION.md`](RATCHET_MIGRATION.md).

The recovery code is a URL-safe bundle containing identity seed and mailbox
capabilities. Word-list encoding, checksum, secure import, and key rotation still
need implementation.

Transport metadata is not hidden. A relay can observe IP addresses, timing,
recipient routing identifiers, and approximate packet sizes. Nearby peers can
observe physical proximity. Padding, opaque mailbox capabilities, relay rotation,
and optional relay-only mode belong to later threat-model work.

Relay mailbox registration proves possession of the X25519 private identity key
through a server-specific key agreement and HMAC. The server persists only the
identity public key, capability hashes, metadata, and encrypted packets. Global,
mailbox, writer, body-size, message-count, rate, and TTL limits bound storage;
new writes are rejected when full instead of evicting older messages. The
current invitation still shares one long-lived write capability with every
contact, so one holder can fill (but cannot silently evict) that mailbox's
quota. Per-contact revocable capabilities remain a public-deployment blocker.

LAN discovery uses directed, per-contact tags that rotate once per minute and
accept a one-bucket clock skew. Advertisements contain a random service name,
protocol version, port, and at most 64 tags, but no account ID or display name.
The HTTP carrier is not confidential: local observers can still see device IPs,
ports, timing, and ciphertext sizes. Message bodies remain AEAD-encrypted, and
the receiver accepts a delivery only after authenticated decryption. The
long-lived relay write capability is deliberately not exposed on the LAN.

This does not prevent traffic analysis, active port scanning, denial of service,
or tag prediction after compromise of a static identity key. It also provides no
Internet-scale anonymity and no protection from a compromised endpoint.

## Shipping gate

Do not describe this build as secure or anonymous in a public release. Required
before shipping: audited messaging protocol integration, abuse controls, backup
and revocation design, dependency review, platform permission review, fuzzing of
wire decoders, and an independent security assessment.
