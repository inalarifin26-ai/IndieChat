enum MandateStatus { active, paused, revoked, expired }

/// A first-class consent/mandate record — every permission is attributable
/// to user, agent, purpose, resource, action, scope, autonomy and status.
class ConsentMandate {
  final String id;
  final String agentId;
  String agentName;
  final String purpose;
  final String dataScope;
  final List<String> allowedActions;
  final List<String> deniedActions;
  final String autonomy; // "Continuous", "Daily at 09:00", "Manual only"
  final String? externalTarget;
  MandateStatus status;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? revokedAt;

  ConsentMandate({
    required this.id,
    required this.agentId,
    this.agentName = '',
    required this.purpose,
    required this.dataScope,
    required this.allowedActions,
    required this.deniedActions,
    required this.autonomy,
    this.externalTarget,
    this.status = MandateStatus.active,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.revokedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static MandateStatus _statusFromApi(String s) =>
      MandateStatus.values.firstWhere((v) => v.name == s, orElse: () => MandateStatus.active);

  factory ConsentMandate.fromApi(Map<String, dynamic> json) => ConsentMandate(
        id: json['id'].toString(),
        agentId: json['agentId'].toString(),
        purpose: json['purpose'] as String,
        dataScope: json['dataScope'] as String,
        allowedActions: ((json['allowedActions'] as List?) ?? []).map((e) => e.toString()).toList(),
        deniedActions: ((json['deniedActions'] as List?) ?? []).map((e) => e.toString()).toList(),
        autonomy: json['autonomy'] as String,
        externalTarget: json['externalTarget'] as String?,
        status: _statusFromApi(json['status'] as String? ?? 'active'),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
        revokedAt: json['revokedAt'] == null ? null : DateTime.tryParse(json['revokedAt'].toString()),
      );
}

/// A pending decision that pauses a workflow until the user responds.
class ApprovalRequest {
  final String id;
  final String agentId;
  String agentName;
  final String workflowId;
  String workflowName;
  final String action; // "Publish Campaign Alpha post"
  final String scope; // "External platform: Instagram"
  final DateTime requestedAt;
  bool resolved;
  bool? approved;

  ApprovalRequest({
    required this.id,
    required this.agentId,
    this.agentName = '',
    required this.workflowId,
    this.workflowName = '',
    required this.action,
    required this.scope,
    DateTime? requestedAt,
    this.resolved = false,
    this.approved,
  }) : requestedAt = requestedAt ?? DateTime.now();

  factory ApprovalRequest.fromApi(Map<String, dynamic> json) => ApprovalRequest(
        id: json['id'].toString(),
        agentId: json['agentId'].toString(),
        workflowId: json['workflowId'].toString(),
        action: json['action'] as String,
        scope: json['scope'] as String,
        requestedAt: DateTime.tryParse(json['requestedAt']?.toString() ?? ''),
        resolved: json['resolved'] as bool? ?? false,
        approved: json['approved'] as bool?,
      );
}

enum OutputKind { report, message, document, spreadsheet, image, data, dashboard }

/// A workflow-generated output stored in the Personal Vault.
/// Never carries the workflow definition, credentials or private memory.
class VaultOutput {
  final String id;
  final String workflowId;
  String workflowName;
  final String title;
  final OutputKind kind;
  final DateTime createdAt;
  final String summary;
  final String aiSummary;
  final String rawDataPreview;
  final List<String> agentActivity;
  bool shared;

  VaultOutput({
    required this.id,
    required this.workflowId,
    this.workflowName = '',
    required this.title,
    required this.kind,
    required this.summary,
    required this.aiSummary,
    required this.rawDataPreview,
    required this.agentActivity,
    DateTime? createdAt,
    this.shared = false,
  }) : createdAt = createdAt ?? DateTime.now();

  static OutputKind _kindFromApi(String s) =>
      OutputKind.values.firstWhere((v) => v.name == s, orElse: () => OutputKind.report);

  factory VaultOutput.fromApi(Map<String, dynamic> json) => VaultOutput(
        id: json['id'].toString(),
        workflowId: json['workflowId'].toString(),
        title: json['title'] as String,
        kind: _kindFromApi(json['kind'] as String? ?? 'report'),
        summary: json['summary'] as String? ?? '',
        aiSummary: json['aiSummary'] as String? ?? '',
        rawDataPreview: json['rawDataPreview'] as String? ?? '',
        agentActivity: ((json['agentActivity'] as List?) ?? []).map((e) => e.toString()).toList(),
        shared: json['shared'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}
