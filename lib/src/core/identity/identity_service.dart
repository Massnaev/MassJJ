import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../../data/local_vault.dart';
import 'anonymous_identity.dart';

class IdentityService {
  IdentityService(this._vault);

  static const _identityKey = 'identity.v1';
  final LocalVault _vault;
  final X25519 _x25519 = X25519();
  final Sha256 _sha256 = Sha256();

  Future<AnonymousIdentity> loadOrCreate() async {
    final stored = await _vault.readJson(_identityKey);
    if (stored != null) {
      return _identityFromJson(stored);
    }

    final random = Random.secure();
    final seed = List<int>.generate(32, (_) => random.nextInt(256));
    final keyPair = await _x25519.newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    final digest = await _sha256.hash(publicKey.bytes);
    final id = base64UrlEncode(
      digest.bytes.take(16).toList(),
    ).replaceAll('=', '');
    final identity = AnonymousIdentity(
      userId: id,
      displayName: 'Аноним ${id.substring(0, 5)}',
      publicKey: publicKey.bytes,
      privateSeed: seed,
      fingerprint: _formatFingerprint(digest.bytes),
      inboxReadToken: _randomToken(),
      inboxWriteToken: _randomToken(),
    );
    await _vault.writeJson(_identityKey, _identityToJson(identity));
    return identity;
  }

  String createInviteCode(AnonymousIdentity identity) {
    final payload = jsonEncode({
      'v': 1,
      'id': identity.userId,
      'name': identity.displayName,
      'key': base64UrlEncode(identity.publicKey),
      'fingerprint': identity.fingerprint,
      'write': identity.inboxWriteToken,
    });
    return 'p2p1.${base64UrlEncode(utf8.encode(payload)).replaceAll('=', '')}';
  }

  Future<Contact> parseInviteCode(String rawCode) async {
    final code = rawCode.trim();
    if (!code.startsWith('p2p1.')) {
      throw const FormatException('Код должен начинаться с p2p1.');
    }

    try {
      final data =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(code.substring(5))),
                ),
              )
              as Map<String, dynamic>;
      final publicKey = base64Url.decode(data['key'] as String);
      final writeToken = data['write'] as String;
      final displayName = data['name'] as String;
      if (data['v'] != 1 ||
          publicKey.length != 32 ||
          writeToken.length < 32 ||
          displayName.isEmpty ||
          displayName.length > 80) {
        throw const FormatException('Неподдерживаемый код контакта.');
      }
      final digest = await _sha256.hash(publicKey);
      final expectedId = base64UrlEncode(
        digest.bytes.take(16).toList(),
      ).replaceAll('=', '');
      if (data['id'] != expectedId) {
        throw const FormatException(
          'ID контакта не соответствует публичному ключу.',
        );
      }
      return Contact(
        userId: expectedId,
        displayName: displayName,
        publicKey: publicKey,
        fingerprint: _formatFingerprint(digest.bytes),
        inboxWriteToken: writeToken,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Код контакта повреждён.');
    }
  }

  AnonymousIdentity _identityFromJson(Map<String, dynamic> json) {
    return AnonymousIdentity(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      publicKey: base64Url.decode(json['publicKey'] as String),
      privateSeed: base64Url.decode(json['privateSeed'] as String),
      fingerprint: json['fingerprint'] as String,
      inboxReadToken: json['inboxReadToken'] as String,
      inboxWriteToken: json['inboxWriteToken'] as String,
    );
  }

  Map<String, Object?> _identityToJson(AnonymousIdentity identity) => {
    'userId': identity.userId,
    'displayName': identity.displayName,
    'publicKey': base64UrlEncode(identity.publicKey),
    'privateSeed': base64UrlEncode(identity.privateSeed),
    'fingerprint': identity.fingerprint,
    'inboxReadToken': identity.inboxReadToken,
    'inboxWriteToken': identity.inboxWriteToken,
  };

  String _randomToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _formatFingerprint(List<int> bytes) {
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return [for (var i = 0; i < 32; i += 4) hex.substring(i, i + 4)].join(' ');
  }
}
