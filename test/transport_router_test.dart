import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_messenger/src/core/messaging/chat_message.dart';
import 'package:p2p_messenger/src/core/messaging/encrypted_packet.dart';
import 'package:p2p_messenger/src/core/transport/delivery_transport.dart';
import 'package:p2p_messenger/src/core/transport/transport_router.dart';

void main() {
  final packet = EncryptedPacket(
    messageId: 'message-1',
    senderId: 'alice',
    recipientId: 'bob',
    createdAt: DateTime.utc(2026, 9, 9),
    expiresAt: DateTime.utc(2026, 9, 16),
    hopLimit: 8,
    nonce: const [],
    cipherText: const [],
    mac: const [],
  );

  test('router uses the first reachable transport by priority', () async {
    final nearby = _FakeTransport(
      kind: TransportKind.nearby,
      priority: 10,
      reachable: false,
    );
    final relay = _FakeTransport(
      kind: TransportKind.internetRelay,
      priority: 20,
      reachable: true,
    );
    final outbox = _FakeTransport(
      kind: TransportKind.localOutbox,
      priority: 1000,
      reachable: true,
    );

    final receipt = await TransportRouter([outbox, relay, nearby]).send(packet);

    expect(receipt.transport, TransportKind.internetRelay);
    expect(nearby.sendCount, 0);
    expect(relay.sendCount, 1);
    expect(outbox.sendCount, 0);
  });

  test(
    'router falls back when a preferred transport fails during send',
    () async {
      final relay = _FakeTransport(
        kind: TransportKind.internetRelay,
        priority: 20,
        reachable: true,
        failOnSend: true,
      );
      final outbox = _FakeTransport(
        kind: TransportKind.localOutbox,
        priority: 1000,
        reachable: true,
      );

      final receipt = await TransportRouter([outbox, relay]).send(packet);

      expect(receipt.transport, TransportKind.localOutbox);
      expect(relay.sendCount, 1);
      expect(outbox.sendCount, 1);
    },
  );
}

class _FakeTransport implements DeliveryTransport {
  _FakeTransport({
    required this.kind,
    required this.priority,
    required this.reachable,
    this.failOnSend = false,
  });

  @override
  final TransportKind kind;

  @override
  final int priority;

  final bool reachable;
  final bool failOnSend;
  int sendCount = 0;

  @override
  TransportState get state => TransportState.ready;

  @override
  Future<bool> canReach(String recipientId) async => reachable;

  @override
  Future<DeliveryReceipt> send(EncryptedPacket packet) async {
    sendCount++;
    if (failOnSend) throw StateError('transport failed');
    return DeliveryReceipt(transport: kind, messageStatus: MessageStatus.sent);
  }
}
