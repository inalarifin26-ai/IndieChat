import 'chat_models.dart';

enum OrchKind { welcome, text, plan, agentResult, result, agentCreated, workflowUpdated }

OrchKind orchKindFromApi(String? k) {
  switch (k) {
    case 'welcome':
      return OrchKind.welcome;
    case 'plan':
      return OrchKind.plan;
    case 'agent_result':
      return OrchKind.agentResult;
    case 'result':
      return OrchKind.result;
    case 'agent_created':
      return OrchKind.agentCreated;
    case 'workflow_updated':
      return OrchKind.workflowUpdated;
    default:
      return OrchKind.text;
  }
}

/// One entry in the Orchestrator chat: the user's instruction, the
/// Orchestrator's reply, or an agent's result bubble inside a task.
class OrchMessage {
  final String id;
  final String sender; // user | orchestrator | agent
  final String? agentId;
  final OrchKind kind;
  final String text;
  final Map<String, dynamic>? payload;
  bool saved;
  final DateTime createdAt;

  OrchMessage({
    required this.id,
    required this.sender,
    this.agentId,
    required this.kind,
    required this.text,
    this.payload,
    this.saved = false,
    required this.createdAt,
  });

  bool get isUser => sender == 'user';
  SenderKind get senderKind => senderFromApi(sender);

  factory OrchMessage.fromApi(Map<String, dynamic> json) => OrchMessage(
        id: json['id'].toString(),
        sender: json['sender'] as String? ?? 'orchestrator',
        agentId: json['agentId'] as String?,
        kind: orchKindFromApi(json['kind'] as String?),
        text: json['text'] as String? ?? '',
        payload: json['payload'] as Map<String, dynamic>?,
        saved: json['saved'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      );
}
