import '../identity/anonymous_identity.dart';
import 'nearby_discovery_service.dart';
import 'nearby_inbox_server.dart';
import 'nearby_peer_registry.dart';
import 'nearby_transport.dart';

class NearbyRuntime {
  NearbyRuntime({
    required this.identity,
    required this.contacts,
    required this.onPacket,
    this.onPeersChanged,
  });

  final AnonymousIdentity identity;
  final NearbyContactsProvider contacts;
  final NearbyPacketHandler onPacket;
  final void Function()? onPeersChanged;

  late final NearbyPeerRegistry registry;
  late final NearbyTransport transport;
  NearbyInboxServer? _server;
  NearbyDiscoveryService? _discovery;

  int get peerCount => registry.count;

  bool isNearby(String contactId) => registry.contains(contactId);

  Future<void> start() async {
    registry = NearbyPeerRegistry(onChanged: onPeersChanged);
    transport = NearbyTransport(registry: registry);
    final server = NearbyInboxServer(identity: identity, onPacket: onPacket);
    _server = server;
    try {
      await server.start();
      final discovery = NearbyDiscoveryService(
        identity: identity,
        contacts: contacts,
        registry: registry,
      );
      _discovery = discovery;
      await discovery.start(port: server.port);
    } catch (_) {
      await close();
      rethrow;
    }
  }

  Future<void> refreshContacts() async {
    await _discovery?.refreshAdvertisement();
  }

  Future<void> close() async {
    await _discovery?.close();
    await _server?.close();
    transport.close(force: true);
    _discovery = null;
    _server = null;
  }
}
