import '../identity/anonymous_identity.dart';
import '../messaging/chat_message.dart';
import '../messaging/encrypted_packet.dart';

class CryptoEngineInfo {
  const CryptoEngineInfo({
    required this.suite,
    required this.label,
    required this.supportsForwardSecrecy,
  });

  final String suite;
  final String label;
  final bool supportsForwardSecrecy;
}

abstract interface class CryptoEngine {
  CryptoEngineInfo get info;

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
