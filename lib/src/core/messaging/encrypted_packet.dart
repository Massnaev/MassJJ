import 'dart:convert';

class EncryptedPacket {
  const EncryptedPacket({
    this.cryptoSuite = 'mvp-x25519-aesgcm-v1',
    this.cryptoHeader = const {},
    required this.messageId,
    required this.senderId,
    required this.recipientId,
    required this.createdAt,
    required this.expiresAt,
    required this.hopLimit,
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  static const protocolVersion = 1;
  final String cryptoSuite;
  final Map<String, Object?> cryptoHeader;
  final String messageId;
  final String senderId;
  final String recipientId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int hopLimit;
  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;

  Map<String, Object?> toJson() => {
    'v': protocolVersion,
    'cryptoSuite': cryptoSuite,
    'cryptoHeader': cryptoHeader,
    'messageId': messageId,
    'senderId': senderId,
    'recipientId': recipientId,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'hopLimit': hopLimit,
    'nonce': base64Encode(nonce),
    'cipherText': base64Encode(cipherText),
    'mac': base64Encode(mac),
  };

  factory EncryptedPacket.fromJson(Map<String, Object?> json) {
    if (json['v'] != protocolVersion) {
      throw const FormatException('Unsupported packet version.');
    }
    return EncryptedPacket(
      cryptoSuite: json['cryptoSuite'] as String? ?? 'mvp-x25519-aesgcm-v1',
      cryptoHeader: json['cryptoHeader'] == null
          ? const {}
          : Map<String, Object?>.from(json['cryptoHeader']! as Map),
      messageId: json['messageId']! as String,
      senderId: json['senderId']! as String,
      recipientId: json['recipientId']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      expiresAt: DateTime.parse(json['expiresAt']! as String),
      hopLimit: json['hopLimit']! as int,
      nonce: base64Decode(json['nonce']! as String),
      cipherText: base64Decode(json['cipherText']! as String),
      mac: base64Decode(json['mac']! as String),
    );
  }
}
