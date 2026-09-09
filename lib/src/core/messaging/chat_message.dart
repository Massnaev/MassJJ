enum MessageDirection { incoming, outgoing }

enum MessageStatus { encrypting, queued, sent, delivered, failed }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.contactId,
    required this.body,
    required this.direction,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String contactId;
  final String body;
  final MessageDirection direction;
  final DateTime createdAt;
  final MessageStatus status;

  ChatMessage copyWith({MessageStatus? status}) => ChatMessage(
        id: id,
        contactId: contactId,
        body: body,
        direction: direction,
        createdAt: createdAt,
        status: status ?? this.status,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'contactId': contactId,
        'body': body,
        'direction': direction.name,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
      };

  factory ChatMessage.fromJson(Map<String, Object?> json) => ChatMessage(
        id: json['id']! as String,
        contactId: json['contactId']! as String,
        body: json['body']! as String,
        direction: MessageDirection.values.byName(json['direction']! as String),
        createdAt: DateTime.parse(json['createdAt']! as String),
        status: MessageStatus.values.byName(json['status']! as String),
      );
}
