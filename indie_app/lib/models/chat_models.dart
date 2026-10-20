enum SenderKind { user, contact, agent, system }

enum MessageKind {
  text,
  file,
  output, // a Vault result shared into a chat (result only)
  card, // rich agent result card (metrics + insights)
  approvalRequest,
  consentRequest,
  taskUpdate,
  outputDelivery,
  notification,
}

/// The quoted message shown above a reply.
class ReplyRef {
  final String id;
  final SenderKind sender;
  final String snippet;
  const ReplyRef({required this.id, required this.sender, required this.snippet});
}

SenderKind senderFromApi(String? s) {
  switch (s) {
    case 'contact':
      return SenderKind.contact;
    case 'agent':
    case 'orchestrator':
      return SenderKind.agent;
    case 'system':
      return SenderKind.system;
    default:
      return SenderKind.user;
  }
}

class ChatMessage {
  final String id;
  final SenderKind sender;
  final MessageKind kind;
  String text;
  final DateTime timestamp;
  final Map<String, dynamic>? payload; // file / output / card / approval metadata
  final ReplyRef? replyTo;

  /// Which group member said it (group chats only).
  final String? from;

  /// Delivery status for messages you sent in contact chats: sent | delivered | read.
  String? status;
  Map<String, int> reactions;
  String? myReaction;
  bool deleted;
  bool saved;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    this.kind = MessageKind.text,
    this.payload,
    this.replyTo,
    this.from,
    this.status,
    Map<String, int>? reactions,
    this.myReaction,
    this.deleted = false,
    this.saved = false,
    DateTime? timestamp,
  })  : reactions = reactions ?? {},
        timestamp = timestamp ?? DateTime.now();

  bool get isMine => sender == SenderKind.user;

  /// One-line description used for reply quotes and list previews.
  String get snippet {
    if (deleted) return 'Message deleted';
    switch (kind) {
      case MessageKind.file:
        return '📎 ${payload?['file']?['name'] ?? 'File'}';
      case MessageKind.output:
        return '📄 ${payload?['output']?['title'] ?? 'Result'}';
      case MessageKind.card:
        return '📊 ${payload?['card']?['title'] ?? 'Result'}';
      default:
        return text;
    }
  }

  static MessageKind kindFromApi(String? k) {
    switch (k) {
      case 'file':
        return MessageKind.file;
      case 'output':
        return MessageKind.output;
      case 'card':
        return MessageKind.card;
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

  factory ChatMessage.fromApi(Map<String, dynamic> json) {
    final rx = <String, int>{};
    ((json['reactions'] as Map?) ?? {}).forEach((k, v) => rx[k.toString()] = (v as num).toInt());
    final reply = json['replyTo'] as Map<String, dynamic>?;
    return ChatMessage(
      id: json['id'].toString(),
      sender: senderFromApi(json['sender'] as String?),
      kind: kindFromApi(json['kind'] as String?),
      text: json['text'] as String? ?? '',
      payload: json['payload'] as Map<String, dynamic>?,
      replyTo: reply == null
          ? null
          : ReplyRef(id: reply['id'].toString(), sender: senderFromApi(reply['sender'] as String?), snippet: reply['snippet'] as String? ?? ''),
      from: json['from'] as String?,
      status: json['status'] as String?,
      reactions: rx,
      myReaction: json['myReaction'] as String?,
      deleted: json['deleted'] as bool? ?? false,
      saved: json['saved'] as bool? ?? false,
      timestamp: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

/// A member of a group chat (one of the user's own contacts).
class GroupMember {
  final String id;
  final String name;
  final String initials;
  const GroupMember({required this.id, required this.name, required this.initials});

  factory GroupMember.fromApi(Map<String, dynamic> json) => GroupMember(
        id: json['id'].toString(),
        name: json['name'] as String? ?? '',
        initials: json['initials'] as String? ?? '?',
      );
}

/// A human contact or a group chat — strictly separate from Agents in the UI.
class Contact {
  final String id;
  String name;
  String initials;
  final String status; // "Online", "Last seen 2h ago", etc.
  String info; // Indie ID / phone / email
  String group;
  final List<ChatMessage> messages;
  bool pinned;
  bool muted;
  int unread;
  bool historyLoaded;

  /// 'person' or 'group'. Groups are made of the user's own contacts.
  final String kind;
  String description;
  String visibility; // groups: public | private
  bool allowNewMembers;
  int memberCount;
  final List<GroupMember> members;

  bool get isGroup => kind == 'group';

  Contact({
    required this.id,
    required this.name,
    required this.initials,
    required this.status,
    this.info = '',
    this.group = '',
    List<ChatMessage>? messages,
    this.pinned = false,
    this.muted = false,
    this.unread = 0,
    this.historyLoaded = false,
    this.kind = 'person',
    this.description = '',
    this.visibility = 'private',
    this.allowNewMembers = true,
    this.memberCount = 0,
    List<GroupMember>? members,
  })  : messages = messages ?? [],
        members = members ?? [];

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  factory Contact.fromApi(Map<String, dynamic> json) {
    final last = json['lastMessage'] as Map<String, dynamic>?;
    return Contact(
      id: json['id'].toString(),
      name: json['name'] as String,
      initials: json['initials'] as String? ?? '?',
      status: json['status'] as String? ?? '',
      info: json['info'] as String? ?? '',
      group: json['group'] as String? ?? '',
      pinned: json['pinned'] as bool? ?? false,
      muted: json['muted'] as bool? ?? false,
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      kind: json['kind'] as String? ?? 'person',
      description: json['description'] as String? ?? '',
      visibility: json['visibility'] as String? ?? 'private',
      allowNewMembers: json['allowNewMembers'] as bool? ?? true,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      members: ((json['members'] as List?) ?? []).map((m) => GroupMember.fromApi(m as Map<String, dynamic>)).toList(),
      // A one-message preview; the full history is fetched when the chat opens.
      messages: last == null
          ? []
          : [
              ChatMessage(
                id: 'preview',
                sender: senderFromApi(last['sender'] as String?),
                from: last['from'] as String?,
                text: last['text'] as String? ?? '',
                status: last['status'] as String?,
                deleted: last['deleted'] as bool? ?? false,
                timestamp: DateTime.tryParse(last['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
              ),
            ],
    );
  }
}
