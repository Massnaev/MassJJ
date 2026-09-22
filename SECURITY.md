# Security policy

## Current status

MassJJ `0.1.x` is an experimental MVP and is not supported for sensitive or
production communication. There is currently no production-secure release.

The MVP intentionally lacks an audited ratcheting protocol, forward secrecy,
post-compromise security, complete production relay abuse controls, and
production APK signing. The relay now has ownership proof, quotas, rate limits,
TTL cleanup, and transactional SQLite persistence, but must remain behind an
HTTPS proxy and out of broad public use until per-contact write capabilities,
revocation, monitoring, and backup recovery are completed and tested.

## Reporting a vulnerability

Do not disclose an unpatched vulnerability in a public Issue. Use a private
[GitHub Security Advisory](https://github.com/Massnaev/MassJJ/security/advisories/new)
and include:

- affected commit and component;
- realistic attacker prerequisites;
- source locations and impact;
- minimal reproduction or test when safe;
- suggested remediation if available.

Never include real identity seeds, recovery codes, mailbox capabilities, private
messages, signing keys, or third-party personal data in a report.

## Known alpha limitations

The current source documentation already treats these as shipping blockers:

- static-key MVP cryptography without Double Ratchet;
- shared non-revocable relay write capabilities and incomplete operational
  monitoring/backup validation;
- incomplete hostile-input/resource limits;
- debug Android signing configuration;
- recovery export through the system clipboard;
- no independent cryptographic audit.

Reports that demonstrate a new exploit path or materially stronger impact are
still welcome.
