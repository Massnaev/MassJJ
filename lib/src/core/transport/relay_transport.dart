import 'dart:convert';
import 'dart:io';

import '../identity/anonymous_identity.dart';
import '../messaging/chat_message.dart';
import '../messaging/encrypted_packet.dart';
import 'delivery_transport.dart';

typedef ContactLookup = Contact? Function(String userId);

class RelayTransport implements DeliveryTransport {
  RelayTransport({
    required Uri baseUri,
    required AnonymousIdentity identity,
    required ContactLookup findContact,
    HttpClient? client,
  }) : _baseUri = baseUri,
       _identity = identity,
       _findContact = findContact,
       _client = client ?? HttpClient();

  final Uri _baseUri;
  final AnonymousIdentity _identity;
  final ContactLookup _findContact;
  final HttpClient _client;
  TransportState _state = TransportState.degraded;

  @override
  TransportKind get kind => TransportKind.internetRelay;

  @override
  int get priority => 20;

  @override
  TransportState get state => _state;

  Future<void> registerMailbox() async {
    try {
      final response = await _jsonRequest(
        method: 'POST',
        path: '/v1/mailboxes',
        body: {
          'mailboxId': _identity.userId,
          'readToken': _identity.inboxReadToken,
          'writeToken': _identity.inboxWriteToken,
        },
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw HttpException(
          'Relay registration failed: ${response.statusCode}',
        );
      }
      _state = TransportState.ready;
    } catch (_) {
      _state = TransportState.degraded;
      rethrow;
    }
  }

  @override
  Future<bool> canReach(String recipientId) async {
    return _state == TransportState.ready && _findContact(recipientId) != null;
  }

  @override
  Future<DeliveryReceipt> send(EncryptedPacket packet) async {
    final contact = _findContact(packet.recipientId);
    if (contact == null) throw StateError('Unknown relay recipient.');
    try {
      final response = await _jsonRequest(
        method: 'POST',
        path:
            '/v1/mailboxes/${Uri.encodeComponent(packet.recipientId)}/messages',
        bearerToken: contact.inboxWriteToken,
        body: packet.toJson(),
      );
      if (response.statusCode != 202) {
        throw HttpException('Relay delivery failed: ${response.statusCode}');
      }
      _state = TransportState.ready;
      return const DeliveryReceipt(
        transport: TransportKind.internetRelay,
        messageStatus: MessageStatus.sent,
      );
    } catch (_) {
      _state = TransportState.degraded;
      rethrow;
    }
  }

  Future<List<EncryptedPacket>> receive() async {
    final response = await _jsonRequest(
      method: 'GET',
      path:
          '/v1/mailboxes/${Uri.encodeComponent(_identity.userId)}/messages?limit=100',
      bearerToken: _identity.inboxReadToken,
    );
    if (response.statusCode != 200) {
      _state = TransportState.degraded;
      throw HttpException('Relay receive failed: ${response.statusCode}');
    }
    _state = TransportState.ready;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['items']! as List<dynamic>)
        .map((item) => EncryptedPacket.fromJson(item as Map<String, Object?>))
        .toList();
  }

  Future<void> acknowledge(String messageId) async {
    final response = await _jsonRequest(
      method: 'DELETE',
      path:
          '/v1/mailboxes/${Uri.encodeComponent(_identity.userId)}/messages/${Uri.encodeComponent(messageId)}',
      bearerToken: _identity.inboxReadToken,
    );
    if (response.statusCode != 204) {
      throw HttpException(
        'Relay acknowledgement failed: ${response.statusCode}',
      );
    }
  }

  Future<_RelayResponse> _jsonRequest({
    required String method,
    required String path,
    String? bearerToken,
    Map<String, Object?>? body,
  }) async {
    final request = await _client.openUrl(method, _baseUri.resolve(path));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (bearerToken != null) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $bearerToken',
      );
    }
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(const Duration(seconds: 8));
    final responseBody = await utf8.decoder.bind(response).join();
    return _RelayResponse(response.statusCode, responseBody);
  }
}

class _RelayResponse {
  const _RelayResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}
