enum SenderKind { user, contact, agent, system }

enum MessageKind {
  text,
  approvalRequest,
  consentRequest,
  taskUpdate,
  outputDelivery,
  notification,
}

class ChatMessage {
  final String id;
  final SenderKind sender;
  final MessageKind kind;
  final String text;
  final DateTime timestamp;
  final Map<String, dynamic>? payload; // approval/consent/output metadata
  bool read;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    this.kind = MessageKind.text,
    this.payload,
    DateTime? timestamp,
    this.read = true,
  }) : timestamp = timestamp ?? DateTime.now();

  static SenderKind _senderFromApi(String s) {
    switch (s) {
      case 'contact':
        return SenderKind.contact;
      case 'agent':
        return SenderKind.agent;
      case 'system':
        return SenderKind.system;
      default:
        return SenderKind.user;
    }
  }

  static MessageKind _kindFromApi(String? k) {
    switch (k) {
      case 'approvalRequest':
        return MessageKind.approvalRequest;
      case 'consentRequest':
        return MessageKind.consentRequest;
      case 'taskUpdate':
        return MessageKind.taskUpdate;
      case 'outputDelivery':
        return MessageKind.outputDelivery;
      case 'notification':
        return MessageKind.notification;
      default:
        return MessageKind.text;
    }
  }

  factory ChatMessage.fromApi(Map<String, dynamic> json) => ChatMessage(
        id: json['id'].toString(),
        sender: _senderFromApi(json['sender'] as String),
        kind: _kindFromApi(json['kind'] as String?),
        text: json['text'] as String,
        payload: json['payload'] as Map<String, dynamic>?,
        timestamp: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );
}

/// A human contact — strictly separate from Agents in the UI.
class Contact {
  final String id;
  final String name;
  final String initials;
  final String status; // "Online", "Last seen 2h ago", etc.
  final List<ChatMessage> messages;
  bool pinned;
  bool historyLoaded;

  Contact({
    required this.id,
    required this.name,
    required this.initials,
    required this.status,
    List<ChatMessage>? messages,
    this.pinned = false,
    this.historyLoaded = false,
  }) : messages = messages ?? [];

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  factory Contact.fromApi(Map<String, dynamic> json) {
    final last = json['lastMessage'] as Map<String, dynamic>?;
    return Contact(
      id: json['id'].toString(),
      name: json['name'] as String,
      initials: json['initials'] as String? ?? '?',
      status: json['status'] as String? ?? '',
      pinned: json['pinned'] as bool? ?? false,
      messages: last == null
          ? []
          : [
              ChatMessage(
                id: 'preview',
                sender: last['sender'] == 'user' ? SenderKind.user : SenderKind.contact,
                text: last['text'] as String,
                timestamp: DateTime.tryParse(last['createdAt']?.toString() ?? '') ?? DateTime.now(),
              ),
            ],
    );
  }
}
