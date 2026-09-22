import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import '../identity/anonymous_identity.dart';
import '../messaging/chat_message.dart';
import '../messaging/encrypted_packet.dart';
import 'delivery_transport.dart';
import 'relay_endpoint_policy.dart';

typedef ContactLookup = Contact? Function(String userId);

class RelayTransport implements DeliveryTransport {
  RelayTransport({
    required Uri baseUri,
    required AnonymousIdentity identity,
    required ContactLookup findContact,
    HttpClient? client,
    bool allowInsecure = false,
  }) : _baseUri = RelayEndpointPolicy.parse(
         baseUri.toString(),
         allowInsecure: allowInsecure,
       ),
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
      final registration = await _registrationBody();
      final response = await _jsonRequest(
        method: 'POST',
        path: '/v1/mailboxes',
        body: registration,
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

  Future<Map<String, Object?>> _registrationBody() async {
    final configResponse = await _jsonRequest(
      method: 'GET',
      path: '/v1/config',
    );
    if (configResponse.statusCode != 200) {
      throw HttpException(
        'Relay configuration failed: ${configResponse.statusCode}',
      );
    }
    final config = jsonDecode(configResponse.body);
    if (config is! Map || config['v'] != 1) {
      throw const FormatException('Unsupported relay configuration.');
    }
    final encodedServerKey = config['registrationPublicKey'];
    if (encodedServerKey is! String) {
      throw const FormatException('Relay registration key is missing.');
    }
    final serverKeyBytes = _decodeBase64Url(encodedServerKey);
    if (serverKeyBytes.length != 32) {
      throw const FormatException('Relay registration key is invalid.');
    }

    final publicKey = base64UrlEncode(_identity.publicKey).replaceAll('=', '');
    final x25519 = X25519();
    final keyPair = await x25519.newKeyPairFromSeed(_identity.privateSeed);
    final sharedSecret = await x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: SimplePublicKey(
        serverKeyBytes,
        type: KeyPairType.x25519,
      ),
    );
    final proofKey = await Hkdf(hmac: Hmac.sha256(), outputLength: 32)
        .deriveKey(
          secretKey: sharedSecret,
          info: utf8.encode(_registrationContext),
        );
    final message = utf8.encode(
      '$_registrationContext\n${_identity.userId}\n$publicKey\n'
      '${_identity.inboxReadToken}\n${_identity.inboxWriteToken}',
    );
    final proof = await Hmac.sha256().calculateMac(
      message,
      secretKey: proofKey,
    );
    return {
      'v': 1,
      'mailboxId': _identity.userId,
      'publicKey': publicKey,
      'readToken': _identity.inboxReadToken,
      'writeToken': _identity.inboxWriteToken,
      'proof': base64UrlEncode(proof.bytes).replaceAll('=', ''),
    };
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

  void close({bool force = false}) {
    _client.close(force: force);
    _state = TransportState.unavailable;
  }

  Future<_RelayResponse> _jsonRequest({
    required String method,
    required String path,
    String? bearerToken,
    Map<String, Object?>? body,
  }) async {
    final request = await _client
        .openUrl(method, _baseUri.resolve(path))
        .timeout(const Duration(seconds: 8));
    request.followRedirects = false;
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
    if (response.isRedirect) {
      await response.drain<void>();
      throw const HttpException('Relay redirects are not allowed.');
    }
    final responseBytes = await _readBounded(
      response,
      maxBytes: method == 'GET' ? 4 * 1024 * 1024 : 256 * 1024,
    );
    final responseBody = utf8.decode(responseBytes);
    return _RelayResponse(response.statusCode, responseBody);
  }

  Future<List<int>> _readBounded(
    HttpClientResponse response, {
    required int maxBytes,
  }) async {
    if (response.contentLength > maxBytes) {
      await response.drain<void>();
      throw const FormatException('Relay response is too large.');
    }
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 8))) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const FormatException('Relay response is too large.');
      }
      bytes.addAll(chunk);
    }
    return bytes;
  }

  static const _registrationContext = 'massjj-relay-registration-v1';

  static List<int> _decodeBase64Url(String value) {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
      throw const FormatException('Invalid base64url value.');
    }
    final bytes = base64Url.decode(base64Url.normalize(value));
    if (base64UrlEncode(bytes).replaceAll('=', '') != value) {
      throw const FormatException('Non-canonical base64url value.');
    }
    return bytes;
  }
}

class _RelayResponse {
  const _RelayResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}
