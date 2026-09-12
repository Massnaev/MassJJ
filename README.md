# P2P Messenger MVP

Anonymous Flutter messenger foundation for Android, iOS, and Windows. Accounts
are local identities: no phone number, email address, or password-reset service.

## Included

- local X25519 identity and a portable recovery code;
- first-run flow for creating or restoring an identity, with an explicit backup
  confirmation;
- copy/paste invitation codes (`p2p1.…`);
- encrypted local storage backed by the platform secure store;
- authenticated encrypted message envelopes;
- persistent local outbox;
- transport routing boundary for relay, nearby, and DTN delivery;
- responsive phone/desktop interface in Russian.

With `RELAY_URL` configured, the client registers its anonymous mailbox, sends,
polls, decrypts, and acknowledges packets. Without connectivity it keeps packets
in the encrypted outbox and retries after the relay recovers. QR scanning and
Nearby/Bluetooth/Wi-Fi adapters are the next slices.

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

Android builds require the Android SDK. iOS builds must be signed and compiled
on macOS with Xcode, even though the shared Dart code can be developed here.

## Security status

This is an MVP, not a production-secure messenger. Read
[`docs/SECURITY_MODEL.md`](docs/SECURITY_MODEL.md) before extending or shipping it.
