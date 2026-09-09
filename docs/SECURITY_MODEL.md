# MVP security model

## What the MVP protects

- private identity seed and app records are encrypted at rest with AES-256-GCM;
- the local vault master key is stored in Android Keystore, iOS Keychain, or the
  Windows secure-storage implementation;
- message bodies are authenticated and encrypted before entering the outbox;
- invitation and packet parsers validate protocol versions and key sizes.

## What is deliberately not production-ready

`MvpCryptoEngine` derives a conversation key from static X25519 identity keys.
AES-GCM uses a fresh random nonce, but the scheme has no Double Ratchet, forward
secrecy, post-compromise security, prekeys, multi-device session management, or
formal protocol audit. It must be replaced with an audited Signal-compatible
PQXDH/Double Ratchet core before any production deployment.

The recovery code is a URL-safe bundle containing identity seed and mailbox
capabilities. Word-list encoding, checksum, secure import, and key rotation still
need implementation.

Transport metadata is not hidden. A relay can observe IP addresses, timing,
recipient routing identifiers, and approximate packet sizes. Nearby peers can
observe physical proximity. Padding, opaque mailbox capabilities, relay rotation,
and optional relay-only mode belong to later threat-model work.

## Shipping gate

Do not describe this build as secure or anonymous in a public release. Required
before shipping: audited messaging protocol integration, abuse controls, backup
and revocation design, dependency review, platform permission review, fuzzing of
wire decoders, and an independent security assessment.
