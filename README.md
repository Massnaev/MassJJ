# MassJJ MVP

Anonymous Flutter messenger foundation for Android, iOS, and Windows. Accounts
are local identities: no phone number, email address, or password-reset service.

## Included

- local X25519 identity and a portable recovery code;
- first-run flow for creating or restoring an identity, with an explicit backup
  confirmation;
- copy/paste invitation codes (`p2p1.…`);
- locally rendered QR invitations;
- camera scanning on Android and iOS, with text-code entry on Windows;
- encrypted local storage backed by the platform secure store;
- authenticated encrypted message envelopes;
- persistent local outbox;
- private contact discovery and direct encrypted delivery inside the same local
  Wi-Fi network;
- transport routing boundary for relay, nearby, and DTN delivery;
- responsive phone/desktop interface in Russian;
- explicit in-chat disclosure of the active crypto suite and contact
  fingerprint.

The client first tries a discovered contact directly over the local network,
then a configured relay, and finally the encrypted outbox. With `RELAY_URL`
configured, it registers its anonymous mailbox, sends, polls, decrypts, and
acknowledges packets. Without Internet, two devices connected to the same LAN
can exchange encrypted packets directly. Otherwise packets stay queued and are
retried when a route appears.

This slice uses Bonjour/mDNS and ordinary LAN TCP. It is not Wi-Fi Direct and
does not yet bridge distant offline devices or use Bluetooth. Protocol details
and limitations are in [`docs/NEARBY_WIFI.md`](docs/NEARBY_WIFI.md).

An independently runnable opaque relay with capability-separated mailbox access
lives in [`server/`](server/). It uses only Node.js built-ins and has integration
tests, so no `npm install` is needed.

## Development setup

Android, iOS, and Windows platform projects are committed. With Flutter 3.47 or
newer on PATH:

```powershell
flutter pub get
flutter analyze
flutter test
```

Run on Windows:

```powershell
flutter run -d windows
```

Run the client against a relay (use an HTTPS URL outside local development):

```powershell
flutter run -d windows --dart-define=RELAY_URL=http://127.0.0.1:8787
```

Android emulators normally reach the host at `http://10.0.2.2:8787`. Local
clear-text HTTP also needs a development-only platform exception; release builds
should require HTTPS.

Test the relay:

```powershell
node --test server/test/*.test.mjs
```

Run the cross-runtime encrypted exchange tests. They start the real Node relay
on a random local port and verify both the low-level encrypted packet contract
and the complete two-`AppController` send, receive, persist, and acknowledge
path:

```powershell
flutter test e2e/relay_e2e_test.dart
```

Android builds require the Android SDK. iOS builds must be signed and compiled
on macOS with Xcode, even though the shared Dart code can be developed here.
Windows Firewall and the iOS local-network permission prompt must allow local
discovery and inbound delivery.

## Security status

This is an MVP, not a production-secure messenger. Read
[`docs/SECURITY_MODEL.md`](docs/SECURITY_MODEL.md) before extending or shipping it.
