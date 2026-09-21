# MassJJ AI handoff

This document is the continuity source for any AI or human continuing MassJJ.
`AGENTS.md` requires it to be updated in the same commit after every change.

## Current snapshot

- Last updated: 2026-09-21
- Product: MassJJ
- Stage: experimental Android MVP / pre-alpha public source
- Version: `0.1.0+1`
- Primary branch: `master`
- License: AGPL-3.0
- Distribution: source repository only; no official APK and no GitHub Releases
- Supported alpha target: Android 7.0+ (`minSdk 24`, `targetSdk 36`)

## Implemented

- local X25519 identity without phone or email;
- create/restore onboarding with a portable recovery bundle;
- contact invitations through text and QR;
- AES-256-GCM local vault with its master key in platform secure storage;
- development-only X25519 + HKDF-SHA256 + AES-GCM message envelopes;
- persistent messages, contacts, and encrypted outbox;
- transport router: nearby LAN, optional relay, local outbox;
- contact-scoped rotating mDNS discovery tags;
- bounded nearby HTTP inbox with authenticated decryption before persistence;
- Node.js opaque relay with split read/write mailbox capabilities;
- light Android UI with chats, contacts, conversation, invite, and profile screens;
- 24 Flutter tests, golden screenshots, relay tests, and relay end-to-end coverage.

## Important paths

- `lib/src/app_controller.dart` — application orchestration and synchronization;
- `lib/src/core/crypto/` — swappable crypto boundary and current MVP engine;
- `lib/src/core/identity/` — identity, recovery, and invitation codecs;
- `lib/src/core/transport/` — relay, nearby, outbox, and routing;
- `lib/src/data/local_vault.dart` — encrypted local persistence;
- `server/relay.mjs` — development relay;
- `docs/SECURITY_MODEL.md` — explicit security guarantees and non-guarantees;
- `test/goldens/` — approved Android UI snapshots.

## Local toolchain used

- Flutter: `C:\tools\flutter` (3.47.3)
- Android SDK: `C:\tools\android-sdk`
- Android platforms installed: 35, 36, and 37 preview-compatible package
- Java: system Java 25; Gradle currently emits a future native-access warning

Typical verification:

```powershell
C:\tools\flutter\bin\flutter.bat analyze
C:\tools\flutter\bin\flutter.bat test
node --test server/test/*.test.mjs
C:\tools\flutter\bin\flutter.bat build apk --release
```

Latest verified results before repository publication:

- Flutter analyze: no issues;
- Flutter tests: 24 passed;
- relay tests: 3 passed;
- Android APK: built successfully, 65.8 MB;
- connected physical Android devices: none.

## Security posture

The current protocol and relay are not production-ready. A standard static audit
completed on 2026-09-21 with seven validated findings: one high, five medium,
and one low. The main open areas are:

1. publicly exposed relay state can be exhausted without global quotas;
2. first mailbox registration is not bound to proof of identity ownership;
3. one shared write capability can flood and evict unrelated queued messages;
4. the client does not yet enforce HTTPS for non-loopback relays;
5. relay responses lack a body-size and body-read deadline;
6. imported X25519 keys need low-order/all-zero validation;
7. copied recovery credentials are not cleared from the system clipboard.

Additional release blockers:

- static identity keys provide no forward secrecy or post-compromise security;
- Android release currently uses the debug signing configuration;
- no independent protocol audit has been performed;
- no official relay deployment exists.

Do not hide these limitations in public messaging. See `SECURITY.md` and
`docs/SECURITY_MODEL.md`.

## Next recommended work

1. Enforce HTTPS except for explicit debug loopback relay URLs.
2. Add bounded streaming relay responses and tests.
3. Reject low-order X25519 keys and all-zero shared secrets.
4. Redesign mailbox provisioning and per-contact write capabilities.
5. Add relay quotas/rate limits and transactional persistence.
6. Test the alpha on two physical Android devices over LAN and relay paths.
7. Create a production signing-key process only when binary distribution begins.

## Change log

| Date | Change | Verification |
| --- | --- | --- |
| 2026-09-21 | Prepared public repository metadata, AGPL licensing, contributor/security guidance, author support addresses, and mandatory AI continuity rules. | Secret screening and standard static security audit completed; existing Flutter/relay test results recorded above. |

