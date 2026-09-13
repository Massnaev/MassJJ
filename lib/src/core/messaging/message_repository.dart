import '../../data/local_vault.dart';
import '../identity/anonymous_identity.dart';
import 'chat_message.dart';
import 'encrypted_packet.dart';

class MessageRepository {
  MessageRepository(this._vault);

  final JsonVault _vault;

  Future<List<Contact>> loadContacts() async {
    final data = await _vault.readJson('contacts.v1');
    if (data == null) return const [];
    return (data['items']! as List<dynamic>)
        .map((item) => Contact.fromJson(item as Map<String, Object?>))
        .toList();
  }

  Future<void> saveContacts(List<Contact> contacts) {
    return _vault.writeJson('contacts.v1', {
      'items': contacts.map((contact) => contact.toJson()).toList(),
    });
  }

  Future<List<ChatMessage>> loadMessages() async {
    final data = await _vault.readJson('messages.v1');
    if (data == null) return const [];
    return (data['items']! as List<dynamic>)
        .map((item) => ChatMessage.fromJson(item as Map<String, Object?>))
        .toList();
  }

  Future<void> saveMessages(List<ChatMessage> messages) {
    return _vault.writeJson('messages.v1', {
      'items': messages.map((message) => message.toJson()).toList(),
    });
  }

  Future<void> enqueue(EncryptedPacket packet) async {
    final data = await _vault.readJson('outbox.v1');
    final items = data == null
        ? <Object?>[]
        : List<Object?>.from(data['items']! as List<dynamic>);
    items.removeWhere(
      (item) =>
          (item! as Map<String, dynamic>)['messageId'] == packet.messageId,
    );
    items.add(packet.toJson());
    await _vault.writeJson('outbox.v1', {'items': items});
  }

  Future<List<EncryptedPacket>> loadOutbox() async {
    final data = await _vault.readJson('outbox.v1');
    if (data == null) return const [];
    return (data['items']! as List<dynamic>)
        .map((item) => EncryptedPacket.fromJson(item as Map<String, Object?>))
        .toList();
  }

  Future<void> removeFromOutbox(String messageId) async {
    final packets = await loadOutbox();
    await _vault.writeJson('outbox.v1', {
      'items': packets
          .where((packet) => packet.messageId != messageId)
          .map((packet) => packet.toJson())
          .toList(),
    });
  }
}
