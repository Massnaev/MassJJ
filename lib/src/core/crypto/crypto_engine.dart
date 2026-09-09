import '../identity/anonymous_identity.dart';
import '../messaging/chat_message.dart';
import '../messaging/encrypted_packet.dart';

abstract interface class CryptoEngine {
  Future<EncryptedPacket> encrypt({
    required ChatMessage message,
    required AnonymousIdentity sender,
    required Contact recipient,
  });

  Future<String> decrypt({
    required EncryptedPacket packet,
    required AnonymousIdentity recipient,
    required Contact sender,
  });
}
