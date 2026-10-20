/// A free-form note kept in the Personal Vault (Vault > Notes).
class VaultNote {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  const VaultNote({required this.id, required this.title, required this.body, required this.createdAt});

  factory VaultNote.fromApi(Map<String, dynamic> json) => VaultNote(
        id: json['id'].toString(),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      );
}

/// Something an agent has noted about the user's preferences (Vault > Memories).
class AgentMemory {
  final String id;
  final String note;
  final String agentId;
  final String agentName;
  const AgentMemory({required this.id, required this.note, required this.agentId, required this.agentName});

  factory AgentMemory.fromApi(Map<String, dynamic> json) => AgentMemory(
        id: json['id'].toString(),
        note: json['note'] as String? ?? '',
        agentId: json['agentId'].toString(),
        agentName: json['agentName'] as String? ?? '',
      );
}

/// One hit from GET /search (a message inside a person, group or agent chat).
class MessageHit {
  final String roomType; // contact | group | agent
  final String roomId;
  final String roomName;
  final String messageId;
  final String snippet;
  final String? from;
  final DateTime createdAt;
  const MessageHit({required this.roomType, required this.roomId, required this.roomName, required this.messageId, required this.snippet, required this.createdAt, this.from});

  factory MessageHit.fromApi(Map<String, dynamic> json) {
    final room = json['room'] as Map<String, dynamic>;
    final m = json['message'] as Map<String, dynamic>;
    return MessageHit(
      roomType: room['type'] as String,
      roomId: room['id'].toString(),
      roomName: room['name'] as String? ?? '',
      messageId: m['id'].toString(),
      snippet: m['snippet'] as String? ?? '',
      from: m['from'] as String?,
      createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

class SearchResults {
  final List<MessageHit> messages;
  final List<String> contactIds;
  final List<String> groupIds;
  final List<String> agentIds;
  const SearchResults({this.messages = const [], this.contactIds = const [], this.groupIds = const [], this.agentIds = const []});

  factory SearchResults.fromApi(Map<String, dynamic> json) => SearchResults(
        messages: ((json['messages'] as List?) ?? []).map((e) => MessageHit.fromApi(e as Map<String, dynamic>)).toList(),
        contactIds: ((json['contacts'] as List?) ?? []).map((e) => (e as Map)['id'].toString()).toList(),
        groupIds: ((json['groups'] as List?) ?? []).map((e) => (e as Map)['id'].toString()).toList(),
        agentIds: ((json['agents'] as List?) ?? []).map((e) => (e as Map)['id'].toString()).toList(),
      );
}
