# Rules for AI contributors

Read this file and `docs/AI_HANDOFF.md` before changing the repository.

## Mandatory continuity rule

After **every repository change**, update `docs/AI_HANDOFF.md` in the same commit.
This applies to code, dependencies, protocols, UI, build configuration,
documentation, tests, security behavior, and deployment instructions.

Each update must:

1. refresh the current implementation state if behavior changed;
2. record the files or subsystem changed;
3. record the verification commands and results;
4. update known limitations, risks, and next steps;
5. append one concise row to the handoff change log.

A change is incomplete until the handoff document is current. Do not remove this
rule or weaken it without explicit approval from the repository owner.

## Engineering rules

- Android is the only supported alpha target until the owner changes scope.
- Never claim that the MVP is production-secure, anonymous, forward-secret, or
  independently audited.
- Keep message encryption independent from transports.
- Never commit identities, recovery codes, relay state, `.env` files, signing
  keys, tokens, or generated APK files.
- Do not expose the MVP relay publicly without addressing the blockers listed in
  `SECURITY.md` and `docs/AI_HANDOFF.md`.
- Do not create GitHub Releases unless the owner explicitly requests one.
- Preserve the no-phone/no-email identity model.
- Run relevant Flutter and Node tests before committing.
- Prefer focused local commits with descriptive messages.

## Required verification

For normal client changes:

```powershell
flutter analyze
flutter test
```

For relay or protocol changes:

```powershell
node --test server/test/*.test.mjs
flutter test e2e/relay_e2e_test.dart
```

For Android packaging changes:

```powershell
flutter build apk --release
```

