import '../messaging/chat_message.dart';
import '../messaging/encrypted_packet.dart';

enum TransportKind { internetRelay, nearby, localOutbox }

enum TransportState { unavailable, ready, degraded }

class DeliveryReceipt {
  const DeliveryReceipt({
    required this.transport,
    required this.messageStatus,
  });

  final TransportKind transport;
  final MessageStatus messageStatus;
}

abstract interface class DeliveryTransport {
  TransportKind get kind;
  TransportState get state;
  int get priority;

  Future<bool> canReach(String recipientId);
  Future<DeliveryReceipt> send(EncryptedPacket packet);
}
