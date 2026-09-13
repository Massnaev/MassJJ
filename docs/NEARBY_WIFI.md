# Nearby Wi-Fi transport

## Current behavior

When two saved contacts run the app on the same IP network, each client:

1. starts a local HTTP inbox on a random port;
2. advertises `_p2pmsg._tcp` with Bonjour/mDNS;
3. resolves matching contact advertisements to local IPv4 endpoints;
4. sends the existing end-to-end encrypted packet directly;
5. falls back to the Internet relay and then the encrypted outbox if direct
   delivery is unavailable.

The route is automatic. The chat and home screens show when a known contact is
reachable through local Wi-Fi.

## Discovery privacy

No persistent user ID, contact name, public key, or relay capability is placed
in mDNS. For every saved contact, the advertiser derives a shared X25519 secret,
expands it with HKDF-SHA256, and publishes a 96-bit HMAC tag for the current
one-minute time bucket. The HMAC also binds the advertiser's public key. The
listener computes expected tags for its own contacts and accepts the previous,
current, and next bucket to tolerate clock skew.

The random service instance name lasts for the current app runtime. Tags rotate,
but IP addresses, ports, packet timing, ciphertext length, and the number of
advertised tags remain observable on the local network.

## Deliberate MVP limits

- Both devices must be on the same multicast-capable LAN; guest-network client
  isolation can prevent discovery or delivery.
- This is not Bluetooth, Wi-Fi Direct, or a mesh/DTN forwarder.
- iOS requires local-network permission; Windows may request a firewall rule.
- Only the first 64 contacts are advertised in this MVP.
- The local carrier is HTTP because the payload is already end-to-end encrypted.
  Authenticated decryption is the acceptance gate, but network-level traffic
  analysis and denial of service are still possible.

The next offline slice is a transport adapter for Bluetooth LE discovery plus a
high-throughput channel (Bluetooth Classic where supported, Nearby Connections,
Multipeer Connectivity, or Wi-Fi Direct). Store-and-forward between distant
offline devices should be added only after packet quotas, expiry, deduplication,
abuse controls, and explicit user consent are designed.
