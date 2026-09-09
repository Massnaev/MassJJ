import '../messaging/chat_message.dart';
import '../messaging/encrypted_packet.dart';
import '../messaging/message_repository.dart';
import 'delivery_transport.dart';

class LocalOutboxTransport implements DeliveryTransport {
  LocalOutboxTransport(this._repository);

  final MessageRepository _repository;

  @override
  TransportKind get kind => TransportKind.localOutbox;

  @override
  int get priority => 1000;

  @override
  TransportState get state => TransportState.ready;

  @override
  Future<bool> canReach(String recipientId) async => true;

  @override
  Future<DeliveryReceipt> send(EncryptedPacket packet) async {
    await _repository.enqueue(packet);
    return const DeliveryReceipt(
      transport: TransportKind.localOutbox,
      messageStatus: MessageStatus.queued,
    );
  }
}
