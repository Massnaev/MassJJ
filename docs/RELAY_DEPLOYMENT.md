# Internet relay deployment plan

The Android client and development relay already support encrypted message
delivery through a configured server. There is no official public MassJJ relay
yet, and `server/relay.mjs` must not be exposed directly until the blockers in
`SECURITY.md` and `docs/AI_HANDOFF.md` are resolved.

## Smallest useful alpha server

A closed alpha should start with one Linux VPS:

- 2 shared x86-64 vCPU;
- 4 GB RAM;
- 40 GB NVMe storage;
- Ubuntu 24.04 LTS;
- one public IPv4 address plus IPv6;
- [Caddy](https://caddyserver.com/docs/automatic-https) on ports 80/443 for
  automatic HTTPS certificates and renewal;
- the MassJJ Node.js relay bound only to `127.0.0.1`;
- transactional SQLite storage in WAL mode with tested backups;
- a systemd service or container restart policy, firewall, log rotation,
  health checks, and disk/queue monitoring.

The server routes opaque end-to-end encrypted envelopes. It must never receive
message plaintext or identity recovery secrets. HTTPS is still required: it
authenticates the relay endpoint, protects routing metadata and capabilities in
transit, and prevents an access network from silently replacing or modifying
relay responses. It does not replace message end-to-end encryption.

The relay now implements bounded request bodies, X25519 proof of mailbox
ownership, source and writer rate limits, mailbox/global byte quotas, durable
transactions, and TTL cleanup. It rejects a full queue instead of silently
evicting another message. Per-contact write capabilities, capability revocation,
external monitoring, and a backup-restore drill remain required before a broad
public launch.

## Preparation before purchasing the VPS

1. Pass the Node relay tests and Flutter relay end-to-end test locally.
2. Complete per-contact write capability and revocation design.
3. Run a load test at the configured byte and request ceilings.
4. Test SQLite backup and restore while preserving the relay registration key.
5. Create the stable Android signing key and install a signed baseline APK.
6. Obtain a dedicated relay hostname and confirm the selected provider accepts
   the owner's registration, payment method, and intended lawful use.

The repository contains reviewed starting templates in `server/deploy/`. Do not
paste real hostnames, credentials, keys, or provider account data into Git.

The ownership-proof protocol requires the hardened client and server to be
introduced together. No official earlier client or public relay exists, so the
first alpha deployment has no supported rolling-upgrade requirement. Legacy
development `relay.json` files are not imported: retain them only as backups,
start a fresh SQLite database, and allow encrypted client outboxes to retry.

## First deployment runbook

1. Create the VPS with SSH-key authentication; do not enable password login.
2. Apply all Ubuntu security updates and install Node.js 22.13+ and Caddy.
3. Create a locked non-login `massjj` service user and `/var/lib/massjj` owned
   by that user with mode `0700`.
4. Place the repository at `/opt/massjj`, copy the example environment file to
   `/etc/massjj/relay.env`, and restrict it to root.
5. Install `server/deploy/massjj-relay.service`, start it, and verify that port
   8787 listens only on `127.0.0.1`.
6. Replace the example hostname in the Caddyfile, point DNS A/AAAA records to
   the VPS, and let Caddy obtain the TLS certificate.
7. Expose only TCP 80/443 publicly. Keep SSH key-only and separately restricted;
   never expose 8787.
8. Verify `/health`, mailbox proof, encrypted send/receive/acknowledge, quota
   rejection, service restart, and a database backup/restore.
9. Configure the HTTPS relay URL in the Android app and repeat the test over two
   independent mobile networks before inviting alpha users.

## Budget snapshot (2026-09-22)

Prices change and taxes vary by country. Current practical options are:

| Option | Approximate infrastructure cost | Use |
| --- | ---: | --- |
| [Oracle Cloud Always Free](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm) | $0/month when capacity is available | Cheapest closed alpha; instances can be reclaimed when considered idle and account creation may require payment verification. |
| [DigitalOcean Basic 512 MB](https://www.digitalocean.com/pricing/droplets) | $4/month | Can run a very small relay, but memory is tight. |
| [DigitalOcean Basic 1 GB](https://www.digitalocean.com/pricing/droplets) | $6/month | Simple predictable starting point. |
| [Hetzner EU CX23](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/) plus [IPv4](https://docs.hetzner.com/cloud/servers/primary-ips/overview/) | about EUR 5.99/month before VAT | Better CPU/RAM value (2 vCPU, 4 GB), with latency from distant regions. |
| Existing home computer plus a [Cloudflare Tunnel](https://developers.cloudflare.com/tunnel/) | VPS cost $0; electricity and home Internet remain | Suitable only for temporary tests because delivery stops with the computer, router, or home connection. |

TLS certificates can be free through [Let's Encrypt](https://letsencrypt.org/).
A custom domain is optional for the first private test if a stable provider
hostname is available; otherwise budget roughly USD 10-20 per year depending on
the registrar and TLD.

For the cheapest realistic start, try Oracle Always Free first. If capacity or
reliability is a problem, use a USD 6/month 1 GB VPS. Do not add a managed
database, Kubernetes, or a second server for the initial closed alpha.

## Growth path

- Add a signaling service and STUN when attempting direct Internet peer-to-peer
  connections. NAT and carrier-grade NAT mean direct mobile-to-mobile links
  cannot be relied on.
- Add TURN only as a fallback when direct connectivity fails; TURN forwards
  every byte and therefore changes bandwidth cost materially.
- Separate relay instances and move to PostgreSQL/object storage only after
  observed queue size, traffic, or availability justifies it.
- Background delivery and notifications require a separate Android strategy;
  continuous polling is not reliable under Android power restrictions.
