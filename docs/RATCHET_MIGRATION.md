# Double Ratchet migration plan

The current `MvpCryptoEngine` must remain visibly marked as development-only.
Do not implement a home-grown approximation of Signal. Production work should
integrate an audited, maintained protocol core and verify its published test
vectors.

## Compatibility boundary

`CryptoEngine` owns encryption and decryption. `EncryptedPacket` now exposes a
versioned `cryptoSuite` plus an opaque `cryptoHeader`; transports store and move
those values without interpreting them. `CryptoEngineInfo` tells the UI whether
the active engine actually provides forward secrecy.

## Staged replacement

1. Introduce an invitation v2 containing an identity key, signed prekey,
   signature, and one-time prekey references. Continue accepting v1 contacts
   only in an explicitly labelled legacy mode.
2. Add an encrypted per-contact session store. Ratchet state changes must be
   committed atomically after successful encrypt/decrypt operations and must
   survive process termination without nonce or message-key reuse.
3. Integrate an audited PQXDH/X3DH and Double Ratchet implementation. Encode
   the ratchet public key, previous-chain length, and message number inside
   `cryptoHeader`; identify the exact implementation and version in
   `cryptoSuite`.
4. Add skipped-message-key limits, replay rejection, session reset, identity
   change warnings, and safe prekey replenishment. Exercise concurrent sends,
   out-of-order delivery, duplication, delayed delivery, and device restore.
5. Remove the MVP suite from release builds after a compatibility window. Gate
   shipping on test-vector conformance, fuzzing, dependency review, and an
   independent security assessment.

## Non-goals of the current slice

The new envelope fields do not provide forward secrecy, post-compromise
security, deniability, or multi-device sessions. They only prevent the transport
format and UI from blocking a future audited implementation.
