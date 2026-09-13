class NearbyPeer {
  const NearbyPeer({
    required this.contactId,
    required this.endpoint,
    required this.serviceName,
    required this.lastSeen,
  });

  final String contactId;
  final Uri endpoint;
  final String serviceName;
  final DateTime lastSeen;
}

class NearbyPeerRegistry {
  NearbyPeerRegistry({this.onChanged});

  final void Function()? onChanged;
  final Map<String, NearbyPeer> _peers = {};

  int get count => _peers.length;

  void update({
    required String contactId,
    required Uri endpoint,
    required String serviceName,
    DateTime? seenAt,
  }) {
    final previous = _peers[contactId];
    _peers[contactId] = NearbyPeer(
      contactId: contactId,
      endpoint: endpoint,
      serviceName: serviceName,
      lastSeen: seenAt ?? DateTime.now().toUtc(),
    );
    if (previous == null || previous.endpoint != endpoint) onChanged?.call();
  }

  Uri? endpointFor(String contactId) => _peers[contactId]?.endpoint;

  bool contains(String contactId) => _peers.containsKey(contactId);

  void removeContact(String contactId) {
    if (_peers.remove(contactId) != null) onChanged?.call();
  }

  void removeService(String serviceName) {
    final before = _peers.length;
    _peers.removeWhere((_, peer) => peer.serviceName == serviceName);
    if (_peers.length != before) onChanged?.call();
  }

  void clear() {
    if (_peers.isEmpty) return;
    _peers.clear();
    onChanged?.call();
  }
}
