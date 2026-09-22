# Internet relay deployment plan

The Android client and development relay already support encrypted message
delivery through a configured server. There is no official public MassJJ relay
yet, and `server/relay.mjs` must not be exposed directly until the blockers in
`SECURITY.md` and `docs/AI_HANDOFF.md` are resolved.

## Smallest useful alpha server

A closed alpha can start with one Linux VPS:

- 1 shared vCPU and 1 GB RAM minimum; 2 GB is more comfortable;
- 20 GB storage is sufficient for the first small test when queues have strict
  byte quotas and short expiration;
- Ubuntu LTS or another maintained Linux distribution;
- [Caddy](https://caddyserver.com/docs/automatic-https) on ports 80/443 for
  automatic HTTPS certificates and renewal;
- the MassJJ Node.js relay bound only to `127.0.0.1`;
- transactional persistent storage, initially SQLite with WAL and tested
  backups, replacing the development JSON file;
- a systemd service or container restart policy, firewall, log rotation,
  health checks, and disk/queue monitoring.

The server routes opaque end-to-end encrypted envelopes. It must never receive
message plaintext or identity recovery secrets. HTTPS is still required: it
authenticates the relay endpoint, protects routing metadata and capabilities in
transit, and prevents an access network from silently replacing or modifying
relay responses. It does not replace message end-to-end encryption.

Before deployment, add global and per-mailbox byte quotas, request rate limits,
authenticated mailbox creation, per-contact write capabilities, capability
rotation/revocation, bounded request bodies, durable transactions, TTL cleanup,
and abuse monitoring.

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
