import 'dart:convert';
import 'dart:io';

import '../messaging/chat_message.dart';
import '../messaging/encrypted_packet.dart';
import 'delivery_transport.dart';
import 'nearby_peer_registry.dart';

class NearbyTransport implements DeliveryTransport {
  NearbyTransport({required NearbyPeerRegistry registry, HttpClient? client})
    : _registry = registry,
      _client = client ?? HttpClient();

  final NearbyPeerRegistry _registry;
  final HttpClient _client;
  bool _closed = false;

  @override
  TransportKind get kind => TransportKind.nearby;

  @override
  int get priority => 10;

  @override
  TransportState get state =>
      _closed ? TransportState.unavailable : TransportState.ready;

  @override
  Future<bool> canReach(String recipientId) async {
    return !_closed && _registry.contains(recipientId);
  }

  @override
  Future<DeliveryReceipt> send(EncryptedPacket packet) async {
    if (_closed) throw StateError('Nearby transport is closed.');
    final endpoint = _registry.endpointFor(packet.recipientId);
    if (endpoint == null) {
      throw StateError('Nearby peer is not available.');
    }
    try {
      final request = await _client
          .postUrl(endpoint.resolve('/v1/nearby/messages'))
          .timeout(const Duration(seconds: 2));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(packet.toJson()));
      final response = await request.close().timeout(
        const Duration(seconds: 4),
      );
      await response.drain<void>();
      if (response.statusCode != HttpStatus.accepted) {
        throw HttpException('Nearby delivery failed: ${response.statusCode}');
      }
      return const DeliveryReceipt(
        transport: TransportKind.nearby,
        messageStatus: MessageStatus.delivered,
      );
    } catch (_) {
      _registry.removeContact(packet.recipientId);
      rethrow;
    }
  }

  void close({bool force = false}) {
    if (_closed) return;
    _closed = true;
    _client.close(force: force);
  }
}
