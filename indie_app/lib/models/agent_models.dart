import 'chat_models.dart';

enum AgentActivityState { idle, ready, monitoring, working, waitingApproval, scheduled, error }

class AgentPermission {
  final String label; // e.g. "Read campaign analytics"
  final bool allowed;
  AgentPermission(this.label, {this.allowed = true});
}

class Agent {
  final String id;
  final String name;
  final String role; // "Marketing Agent", "Research Agent", ...
  final String glyph; // short symbol shown in avatar (not a generic robot icon)
  final String accentHex;
  AgentActivityState state;
  String currentActivity; // e.g. "Monitoring Campaign Alpha"
  final List<AgentPermission> permissions;
  final List<String> automationSummary; // e.g. "Daily at 09:00"
  /// Workflow steps defined by the Orchestrator. The agent's chat may only
  /// act inside these steps (enforced server-side too).
  final List<String> workflow;
  final List<ChatMessage> messages;
  final List<String> activityLog;
  final List<String> memoryNotes;
  bool apiNeedsAttention;
  bool detailLoaded; // messages/activity/memory fetched from the backend yet?

  Agent({
    required this.id,
    required this.name,
    required this.role,
    required this.glyph,
    required this.accentHex,
    this.state = AgentActivityState.idle,
    this.currentActivity = 'No active task',
    List<AgentPermission>? permissions,
    List<String>? automationSummary,
    List<String>? workflow,
    List<ChatMessage>? messages,
    List<String>? activityLog,
    List<String>? memoryNotes,
    this.apiNeedsAttention = false,
    this.detailLoaded = false,
  })  : permissions = permissions ?? [],
        automationSummary = automationSummary ?? [],
        workflow = workflow ?? [],
        messages = messages ?? [],
        activityLog = activityLog ?? [],
        memoryNotes = memoryNotes ?? [];

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  bool get needsAttention =>
      apiNeedsAttention || state == AgentActivityState.waitingApproval || state == AgentActivityState.error;

  static AgentActivityState _stateFromApi(String s) {
    return AgentActivityState.values.firstWhere((v) => v.name == s, orElse: () => AgentActivityState.idle);
  }

  factory Agent.fromApi(Map<String, dynamic> json) => Agent(
        id: json['id'].toString(),
        name: json['name'] as String,
        role: json['role'] as String? ?? '',
        glyph: json['glyph'] as String? ?? '?',
        accentHex: json['accentHex'] as String? ?? '2FE4DB',
        state: _stateFromApi(json['state'] as String? ?? 'idle'),
        currentActivity: json['currentActivity'] as String? ?? 'No active task',
        permissions: ((json['permissions'] as List?) ?? []).map((p) => AgentPermission(p.toString())).toList(),
        workflow: ((json['workflow'] as List?) ?? []).map((e) => e.toString()).toList(),
        apiNeedsAttention: json['needsAttention'] as bool? ?? false,
      );
}
