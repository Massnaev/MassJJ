import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../identity/anonymous_identity.dart';

class NearbyDiscoveryTagger {
  static const bucketDuration = Duration(minutes: 1);

  final X25519 _keyAgreement = X25519();
  final Hkdf _kdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final Hmac _hmac = Hmac.sha256();

  Future<String> tagFor({
    required AnonymousIdentity identity,
    required Contact contact,
    required DateTime at,
  }) {
    return _tagForBucket(
      identity: identity,
      contact: contact,
      advertisedPublicKey: identity.publicKey,
      bucket: bucketFor(at),
    );
  }

  Future<Map<String, String>> acceptedTags({
    required AnonymousIdentity identity,
    required List<Contact> contacts,
    required DateTime at,
  }) async {
    final current = bucketFor(at);
    final result = <String, String>{};
    for (final contact in contacts) {
      for (final offset in const [-1, 0, 1]) {
        result[await _tagForBucket(
              identity: identity,
              contact: contact,
              advertisedPublicKey: contact.publicKey,
              bucket: current + offset,
            )] =
            contact.userId;
      }
    }
    return result;
  }

  int bucketFor(DateTime at) {
    return at.toUtc().millisecondsSinceEpoch ~/ bucketDuration.inMilliseconds;
  }

  Future<String> _tagForBucket({
    required AnonymousIdentity identity,
    required Contact contact,
    required List<int> advertisedPublicKey,
    required int bucket,
  }) async {
    final keyPair = await _keyAgreement.newKeyPairFromSeed(
      identity.privateSeed,
    );
    final sharedSecret = await _keyAgreement.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: SimplePublicKey(
        contact.publicKey,
        type: KeyPairType.x25519,
      ),
    );
    final discoveryKey = await _kdf.deriveKey(
      secretKey: sharedSecret,
      nonce: const [],
      info: utf8.encode('p2p-messenger/nearby-discovery/v1'),
    );
    final mac = await _hmac.calculateMac([
      ...utf8.encode('advertisement:'),
      ...advertisedPublicKey,
      ...utf8.encode(':$bucket'),
    ], secretKey: discoveryKey);
    return base64UrlEncode(mac.bytes.take(12).toList()).replaceAll('=', '');
  }
}
