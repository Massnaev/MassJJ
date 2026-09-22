# MassJJ AI handoff

This document is the continuity source for any AI or human continuing MassJJ.
`AGENTS.md` requires it to be updated in the same commit after every change.

## Current snapshot

- Last updated: 2026-09-22
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
- persistent in-app HTTPS relay configuration with immediate reconnect and
  encrypted-outbox retry;
- contact-scoped rotating mDNS discovery tags;
- bounded nearby HTTP inbox with authenticated decryption before persistence;
- Android network policy permits cleartext LAN HTTP for dynamic peer IPs while
  message envelopes remain encrypted and authenticated end to end;
- GitHub Releases update check, SHA-256 verified APK download, and Android
  system-installer handoff with an in-app update banner; checks run at startup,
  on app resume (15-minute minimum interval), and every three active hours;
- Node.js opaque relay with split read/write mailbox capabilities;
- light Android UI with chats, contacts, conversation, invite, profile, and
  update-banner states;
- 30 Flutter tests, golden screenshots, relay tests, and relay end-to-end coverage.

## Important paths

- `lib/src/app_controller.dart` — application orchestration and synchronization;
- `lib/src/core/crypto/` — swappable crypto boundary and current MVP engine;
- `lib/src/core/identity/` — identity, recovery, and invitation codecs;
- `lib/src/core/transport/` — relay, nearby, outbox, and routing;
- `lib/src/data/local_vault.dart` — encrypted local persistence;
- `lib/src/data/app_settings_repository.dart` — persisted relay origin;
- `server/relay.mjs` — development relay;
- `docs/DTN_ROADMAP.md` — mandatory store-carry-forward offline delivery plan;
- `docs/RELAY_DEPLOYMENT.md` — minimum Internet relay deployment and budget plan;
- `lib/src/core/update/` — GitHub release validation, download, and installer coordination;
- `docs/RELEASING.md` — signing and data-preserving release contract;
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

Latest verification after update support was added on 2026-09-22:

- Flutter analyze: no issues;
- Flutter tests: 27 passed;
- Android APK: built successfully, 65.9 MB;
- merged release manifest contains the update permission, private FileProvider,
  and LAN network-security configuration;
- physical Android update installation: not yet tested.

Latest verification after persistent relay configuration was added on
2026-09-22:

- Flutter analyze: no issues;
- Flutter tests: 30 passed, including the updated profile golden;
- relay server tests: 3 passed;
- relay end-to-end tests: 2 passed;
- Android APK: built successfully, 66.3 MB;
- physical two-device LAN and mobile-network delivery: not yet retested.

## Security posture

The current protocol and relay are not production-ready. A standard static audit
completed on 2026-09-21 with seven validated findings: one high, five medium,
and one low. Two client transport findings were addressed on 2026-09-22 by
enforcing HTTPS unless an explicit insecure development flag is compiled in,
disabling redirects, and bounding/timing relay response reads. The remaining
open areas are:

1. publicly exposed relay state can be exhausted without global quotas;
2. first mailbox registration is not bound to proof of identity ownership;
3. one shared write capability can flood and evict unrelated queued messages;
4. imported X25519 keys need low-order/all-zero validation;
5. copied recovery credentials are not cleared from the system clipboard.

Additional release blockers:

- static identity keys provide no forward secrecy or post-compromise security;
- Android release falls back to debug signing until a private
  `android/key.properties` and stable release keystore are supplied;
- no independent protocol audit has been performed;
- no official relay deployment exists.

The Android network security configuration currently permits cleartext at the
platform level because dynamic LAN IP ranges cannot be expressed as Android
domain rules. Keep all non-LAN endpoints HTTPS-only in application code and do
not send plaintext secrets through the nearby HTTP transport.

Do not hide these limitations in public messaging. See `SECURITY.md` and
`docs/SECURITY_MODEL.md`.

## Next recommended work

1. Reject low-order X25519 keys and all-zero shared secrets.
2. Redesign mailbox provisioning and per-contact write capabilities.
3. Add relay quotas/rate limits and transactional persistence.
4. Deploy a production HTTPS relay only after those server blockers are fixed.
5. Test the alpha on two physical Android devices over LAN and relay paths.
6. Create, back up, and test the stable production signing key before the first
   GitHub binary release.
7. Implement the mandatory opportunistic offline route described in
   `docs/DTN_ROADMAP.md`, progressing from BLE discovery to physically tested
   multi-hop `A -> B -> C -> D` delivery.

## Change log

| Date | Change | Verification |
| --- | --- | --- |
| 2026-09-21 | Prepared public repository metadata, AGPL licensing, contributor/security guidance, author support addresses, and mandatory AI continuity rules. | Secret screening and standard static security audit completed; existing Flutter/relay test results recorded above. |
| 2026-09-21 | Enabled Android cleartext access required by the encrypted LAN transport and surfaced nearby startup failure in the transport banner. | `flutter analyze` clean; 24 Flutter tests passed; release APK built successfully (65.9 MB). |
| 2026-09-22 | Added GitHub Releases update discovery, strict APK metadata/digest checks, Android installer handoff, update banner, release signing configuration, and release runbook. | `flutter analyze` clean; 27 Flutter tests passed; release APK built successfully (65.9 MB); merged manifest verified. |
| 2026-09-22 | Added persistent in-app HTTPS relay configuration, immediate reconnect/outbox retry, redirect rejection, bounded relay responses, and a profile settings row. | `flutter analyze` clean; 30 Flutter tests, 3 relay tests, and 2 relay E2E tests passed; release APK built successfully (66.3 MB). |
| 2026-09-22 | Added rate-limited GitHub update checks on app resume and a three-hour periodic check while active. | `flutter analyze` clean; 30 Flutter tests passed. |
| 2026-09-22 | Recorded mandatory multi-hop offline DTN delivery and the minimum hardened Internet relay deployment/budget plan. | Documentation-only change; `git diff --check` clean; runtime tests not repeated. |
