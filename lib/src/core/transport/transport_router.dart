import '../messaging/encrypted_packet.dart';
import 'delivery_transport.dart';

class TransportRouter {
  TransportRouter(List<DeliveryTransport> transports)
    : _transports = [...transports]
        ..sort((a, b) => a.priority.compareTo(b.priority));

  final List<DeliveryTransport> _transports;

  void addTransport(DeliveryTransport transport) {
    _transports.removeWhere((item) => item.kind == transport.kind);
    _transports.add(transport);
    _transports.sort((a, b) => a.priority.compareTo(b.priority));
  }

  void removeTransport(TransportKind kind) {
    _transports.removeWhere((item) => item.kind == kind);
  }

  Future<DeliveryReceipt> send(EncryptedPacket packet) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (final transport in _transports) {
      if (transport.state == TransportState.unavailable) continue;
      if (await transport.canReach(packet.recipientId)) {
        try {
          return await transport.send(packet);
        } catch (error, stackTrace) {
          lastError = error;
          lastStackTrace = stackTrace;
        }
      }
    }
    if (lastError != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace!);
    }
    throw StateError('No transport can queue or deliver this packet.');
  }
}
