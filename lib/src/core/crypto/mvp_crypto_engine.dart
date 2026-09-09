import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../identity/anonymous_identity.dart';
import '../messaging/chat_message.dart';
import '../messaging/encrypted_packet.dart';
import 'crypto_engine.dart';

/// Development-only authenticated encryption.
///
/// This intentionally lives behind [CryptoEngine] so it can be replaced by an
/// audited Signal/PQXDH + Double Ratchet implementation before production.
class MvpCryptoEngine implements CryptoEngine {
  final X25519 _keyAgreement = X25519();
  final Cipher _cipher = AesGcm.with256bits();
  final Hkdf _kdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  @override
  Future<EncryptedPacket> encrypt({
    required ChatMessage message,
    required AnonymousIdentity sender,
    required Contact recipient,
  }) async {
    final createdAt = message.createdAt.toUtc();
    final secretKey = await _deriveKey(
      privateSeed: sender.privateSeed,
      remotePublicKey: recipient.publicKey,
    );
    final aad = _associatedData(
      message.id,
      sender.userId,
      recipient.userId,
      createdAt,
    );
    final box = await _cipher.encrypt(
      utf8.encode(message.body),
      secretKey: secretKey,
      nonce: _cipher.newNonce(),
      aad: aad,
    );
    return EncryptedPacket(
      messageId: message.id,
      senderId: sender.userId,
      recipientId: recipient.userId,
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(days: 7)),
      hopLimit: 8,
      nonce: box.nonce,
      cipherText: box.cipherText,
      mac: box.mac.bytes,
    );
  }

  @override
  Future<String> decrypt({
    required EncryptedPacket packet,
    required AnonymousIdentity recipient,
    required Contact sender,
  }) async {
    final secretKey = await _deriveKey(
      privateSeed: recipient.privateSeed,
      remotePublicKey: sender.publicKey,
    );
    final clearText = await _cipher.decrypt(
      SecretBox(packet.cipherText, nonce: packet.nonce, mac: Mac(packet.mac)),
      secretKey: secretKey,
      aad: _associatedData(
        packet.messageId,
        packet.senderId,
        packet.recipientId,
        packet.createdAt,
      ),
    );
    return utf8.decode(clearText);
  }

  Future<SecretKey> _deriveKey({
    required List<int> privateSeed,
    required List<int> remotePublicKey,
  }) async {
    final localKeyPair = await _keyAgreement.newKeyPairFromSeed(privateSeed);
    final sharedSecret = await _keyAgreement.sharedSecretKey(
      keyPair: localKeyPair,
      remotePublicKey: SimplePublicKey(
        remotePublicKey,
        type: KeyPairType.x25519,
      ),
    );
    return _kdf.deriveKey(
      secretKey: sharedSecret,
      nonce: const [],
      info: utf8.encode('p2p-messenger/mvp-envelope/v1'),
    );
  }

  List<int> _associatedData(
    String messageId,
    String senderId,
    String recipientId,
    DateTime createdAt,
  ) {
    return utf8.encode(
      '$messageId|$senderId|$recipientId|${createdAt.toUtc().toIso8601String()}',
    );
  }
}
