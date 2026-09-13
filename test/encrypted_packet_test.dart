import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_messenger/src/core/crypto/mvp_crypto_engine.dart';
import 'package:p2p_messenger/src/core/identity/anonymous_identity.dart';
import 'package:p2p_messenger/src/core/messaging/encrypted_packet.dart';

void main() {
  test('encrypted packet survives JSON round-trip', () {
    final createdAt = DateTime.utc(2026, 9, 9, 12, 30);
    final original = EncryptedPacket(
      cryptoSuite: 'test-ratchet-v1',
      cryptoHeader: const {'n': 7, 'pn': 3},
      messageId: 'message-1',
      senderId: 'alice',
      recipientId: 'bob',
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(days: 7)),
      hopLimit: 8,
      nonce: const [1, 2, 3],
      cipherText: const [4, 5, 6],
      mac: const [7, 8, 9],
    );

    final decoded = EncryptedPacket.fromJson(original.toJson());

    expect(decoded.messageId, original.messageId);
    expect(decoded.cryptoSuite, original.cryptoSuite);
    expect(decoded.cryptoHeader, original.cryptoHeader);
    expect(decoded.senderId, original.senderId);
    expect(decoded.recipientId, original.recipientId);
    expect(decoded.createdAt, original.createdAt);
    expect(decoded.expiresAt, original.expiresAt);
    expect(decoded.hopLimit, original.hopLimit);
    expect(decoded.nonce, original.nonce);
    expect(decoded.cipherText, original.cipherText);
    expect(decoded.mac, original.mac);
  });

  test('unsupported packet version is rejected', () {
    expect(
      () => EncryptedPacket.fromJson({'v': 99}),
      throwsA(isA<FormatException>()),
    );
  });

  test('MVP engine refuses a packet from another crypto suite', () async {
    final engine = MvpCryptoEngine();
    final packet = EncryptedPacket(
      cryptoSuite: 'future-ratchet-v1',
      messageId: 'message-suite-test',
      senderId: 'sender-id',
      recipientId: 'recipient-id',
      createdAt: DateTime.utc(2026, 9, 13),
      expiresAt: DateTime.utc(2026, 9, 14),
      hopLimit: 8,
      nonce: const [1],
      cipherText: const [2],
      mac: const [3],
    );
    const recipient = AnonymousIdentity(
      userId: 'recipient-id',
      displayName: 'Recipient',
      publicKey: [],
      privateSeed: [],
      fingerprint: '',
      inboxReadToken: '',
      inboxWriteToken: '',
    );
    const sender = Contact(
      userId: 'sender-id',
      displayName: 'Sender',
      publicKey: [],
      fingerprint: '',
      inboxWriteToken: '',
    );

    await expectLater(
      engine.decrypt(packet: packet, recipient: recipient, sender: sender),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
