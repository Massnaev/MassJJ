import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bonsoir/bonsoir.dart';

import '../identity/anonymous_identity.dart';
import 'nearby_discovery_tagger.dart';
import 'nearby_peer_registry.dart';

typedef NearbyContactsProvider = List<Contact> Function();

class NearbyDiscoveryService {
  NearbyDiscoveryService({
    required this.identity,
    required this.contacts,
    required this.registry,
    NearbyDiscoveryTagger? tagger,
  }) : _tagger = tagger ?? NearbyDiscoveryTagger(),
       _instanceName = _randomInstanceName();

  static const serviceType = '_p2pmsg._tcp';
  static const _maxAdvertisedContacts = 64;
  final AnonymousIdentity identity;
  final NearbyContactsProvider contacts;
  final NearbyPeerRegistry registry;
  final NearbyDiscoveryTagger _tagger;
  final String _instanceName;

  BonsoirDiscovery? _discovery;
  BonsoirBroadcast? _broadcast;
  StreamSubscription<BonsoirDiscoveryEvent>? _events;
  Timer? _refreshTimer;
  int _port = 0;
  bool _closed = false;
  bool _refreshing = false;
  bool _refreshQueued = false;

  Future<void> start({required int port}) async {
    if (_discovery != null) return;
    _port = port;
    final discovery = BonsoirDiscovery(type: serviceType, printLogs: false);
    await discovery.initialize();
    _discovery = discovery;
    _events = discovery.eventStream?.listen(
      (event) => unawaited(_handleEvent(event)),
    );
    await discovery.start();
    await refreshAdvertisement();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(refreshAdvertisement()),
    );
  }

  Future<void> refreshAdvertisement() async {
    if (_closed || _port == 0) return;
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshQueued = false;
        final previous = _broadcast;
        _broadcast = null;
        if (previous != null && !previous.isStopped) {
          await previous.stop();
        }
        final attributes = await _advertisementAttributes();
        if (_closed) return;
        final broadcast = BonsoirBroadcast(
          printLogs: false,
          service: BonsoirService(
            name: _instanceName,
            type: serviceType,
            port: _port,
            attributes: attributes,
          ),
        );
        _broadcast = broadcast;
        await broadcast.initialize();
        await broadcast.start();
      } while (_refreshQueued && !_closed);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _refreshTimer?.cancel();
    await _events?.cancel();
    final broadcast = _broadcast;
    final discovery = _discovery;
    _broadcast = null;
    _discovery = null;
    if (broadcast != null && !broadcast.isStopped) await broadcast.stop();
    if (discovery != null && !discovery.isStopped) await discovery.stop();
    registry.clear();
  }

  Future<Map<String, String>> _advertisementAttributes() async {
    final tags = <String>[];
    final now = DateTime.now().toUtc();
    for (final contact in contacts().take(_maxAdvertisedContacts)) {
      tags.add(
        await _tagger.tagFor(identity: identity, contact: contact, at: now),
      );
    }
    final attributes = <String, String>{'v': '1'};
    const tagsPerRecord = 10;
    for (var offset = 0; offset < tags.length; offset += tagsPerRecord) {
      final end = min(offset + tagsPerRecord, tags.length);
      attributes['t${offset ~/ tagsPerRecord}'] = tags
          .sublist(offset, end)
          .join(',');
    }
    return attributes;
  }

  Future<void> _handleEvent(BonsoirDiscoveryEvent event) async {
    if (_closed) return;
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent():
        if (event.service.name != _instanceName) {
          await event.service.resolve(_discovery!.serviceResolver);
        }
      case BonsoirDiscoveryServiceResolvedEvent():
        await _considerService(event.service);
      case BonsoirDiscoveryServiceUpdatedEvent():
        await _considerService(event.service);
      case BonsoirDiscoveryServiceLostEvent():
        registry.removeService(event.service.name);
      default:
        break;
    }
  }

  Future<void> _considerService(BonsoirService service) async {
    if (_closed ||
        service.name == _instanceName ||
        service.attributes['v'] != '1') {
      return;
    }
    final advertisedTags = service.attributes.entries
        .where((entry) => entry.key.startsWith('t'))
        .expand((entry) => entry.value.split(','))
        .where((tag) => tag.isNotEmpty)
        .toSet();
    if (advertisedTags.isEmpty) return;
    final accepted = await _tagger.acceptedTags(
      identity: identity,
      contacts: contacts(),
      at: DateTime.now().toUtc(),
    );
    String? contactId;
    for (final tag in advertisedTags) {
      contactId = accepted[tag];
      if (contactId != null) break;
    }
    if (contactId == null) return;
    final address = _selectIpv4(service.hostAddresses);
    if (address == null) return;
    registry.update(
      contactId: contactId,
      endpoint: Uri(scheme: 'http', host: address.address, port: service.port),
      serviceName: service.name,
    );
  }

  InternetAddress? _selectIpv4(List<String> addresses) {
    final parsed = addresses
        .map(InternetAddress.tryParse)
        .whereType<InternetAddress>()
        .where((address) => address.type == InternetAddressType.IPv4)
        .toList();
    for (final address in parsed) {
      if (!address.isLoopback) return address;
    }
    return parsed.firstOrNull;
  }

  static String _randomInstanceName() {
    final random = Random.secure();
    final bytes = List<int>.generate(9, (_) => random.nextInt(256));
    return 'p2p-${base64UrlEncode(bytes).replaceAll('=', '')}';
  }
}
