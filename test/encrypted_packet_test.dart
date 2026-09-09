import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_messenger/src/core/messaging/encrypted_packet.dart';

void main() {
  test('encrypted packet survives JSON round-trip', () {
    final createdAt = DateTime.utc(2026, 9, 9, 12, 30);
    final original = EncryptedPacket(
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
}
