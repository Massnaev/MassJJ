import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../identity/anonymous_identity.dart';
import '../messaging/encrypted_packet.dart';

typedef NearbyPacketHandler = Future<bool> Function(EncryptedPacket packet);

class NearbyInboxServer {
  NearbyInboxServer({required this.identity, required this.onPacket});

  static const _maxBodyBytes = 300 * 1024;
  final AnonymousIdentity identity;
  final NearbyPacketHandler onPacket;
  HttpServer? _server;

  int get port => _server?.port ?? 0;

  Future<void> start() async {
    if (_server != null) return;
    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      0,
      shared: true,
    );
    _server = server;
    server.listen((request) => unawaited(_handle(request)));
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (request.method != 'POST' ||
          request.uri.path != '/v1/nearby/messages') {
        await _respond(request, HttpStatus.notFound);
        return;
      }
      if (request.headers.contentType?.mimeType != ContentType.json.mimeType) {
        await _respond(request, HttpStatus.unsupportedMediaType);
        return;
      }
      final body = await _readBody(request);
      final decoded = jsonDecode(utf8.decode(body));
      final packet = EncryptedPacket.fromJson(
        Map<String, Object?>.from(decoded as Map),
      );
      if (packet.recipientId != identity.userId ||
          packet.hopLimit < 0 ||
          packet.hopLimit > 16 ||
          packet.expiresAt.isBefore(DateTime.now().toUtc())) {
        await _respond(request, HttpStatus.badRequest);
        return;
      }
      final accepted = await onPacket(packet);
      await _respond(
        request,
        accepted ? HttpStatus.accepted : HttpStatus.forbidden,
      );
    } on FormatException {
      await _respond(request, HttpStatus.badRequest);
    } catch (_) {
      await _respond(request, HttpStatus.internalServerError);
    }
  }

  Future<List<int>> _readBody(HttpRequest request) async {
    final bytes = <int>[];
    await for (final chunk in request) {
      if (bytes.length + chunk.length > _maxBodyBytes) {
        throw const FormatException('Nearby packet is too large.');
      }
      bytes.addAll(chunk);
    }
    return bytes;
  }

  Future<void> _respond(HttpRequest request, int status) async {
    try {
      request.response.statusCode = status;
      request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      await request.response.close();
    } catch (_) {
      // The peer may disconnect while a response is being written.
    }
  }
}
