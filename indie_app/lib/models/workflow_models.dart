import 'package:flutter/material.dart';

enum NodeCategory { trigger, data, ai, logic, action, approval, storage, output }

enum NodeRuntimeState { idle, queued, running, waiting, success, error, skipped, cancelled }

extension NodeCategoryX on NodeCategory {
  String get label {
    switch (this) {
      case NodeCategory.trigger:
        return 'Trigger';
      case NodeCategory.data:
        return 'Data';
      case NodeCategory.ai:
        return 'AI Agent';
      case NodeCategory.logic:
        return 'Logic';
      case NodeCategory.action:
        return 'Action';
      case NodeCategory.approval:
        return 'Approval';
      case NodeCategory.storage:
        return 'Storage';
      case NodeCategory.output:
        return 'Output';
    }
  }

  IconData get icon {
    switch (this) {
      case NodeCategory.trigger:
        return Icons.bolt_rounded;
      case NodeCategory.data:
        return Icons.dns_rounded;
      case NodeCategory.ai:
        return Icons.auto_awesome_rounded;
      case NodeCategory.logic:
        return Icons.alt_route_rounded;
      case NodeCategory.action:
        return Icons.send_rounded;
      case NodeCategory.approval:
        return Icons.lock_person_rounded;
      case NodeCategory.storage:
        return Icons.inventory_2_rounded;
      case NodeCategory.output:
        return Icons.description_rounded;
    }
  }

  Color get color {
    switch (this) {
      case NodeCategory.trigger:
        return const Color(0xFFF5B95B);
      case NodeCategory.data:
        return const Color(0xFF5AA9FF);
      case NodeCategory.ai:
        return const Color(0xFF2FE4DB);
      case NodeCategory.logic:
        return const Color(0xFFB48CFF);
      case NodeCategory.action:
        return const Color(0xFF6C3CE0);
      case NodeCategory.approval:
        return const Color(0xFFEF6F6C);
      case NodeCategory.storage:
        return const Color(0xFF34D399);
      case NodeCategory.output:
        return const Color(0xFF9DA3B4);
    }
  }
}

class WorkflowNode {
  final String id;
  String title;
  NodeCategory category;
  String subtitle;
  Offset position; // canvas position (mutable — dragged in the builder)
  final List<String> permissionRequirements;
  NodeRuntimeState state;
  bool disabled;

  WorkflowNode({
    required this.id,
    required this.title,
    required this.category,
    required this.subtitle,
    required this.position,
    this.permissionRequirements = const [],
    this.state = NodeRuntimeState.idle,
    this.disabled = false,
  });

  static NodeCategory _categoryFromApi(String s) =>
      NodeCategory.values.firstWhere((v) => v.name == s, orElse: () => NodeCategory.action);

  static NodeRuntimeState _stateFromApi(String s) =>
      NodeRuntimeState.values.firstWhere((v) => v.name == s, orElse: () => NodeRuntimeState.idle);

  factory WorkflowNode.fromApi(Map<String, dynamic> json) => WorkflowNode(
        id: json['id'].toString(),
        title: json['title'] as String,
        category: _categoryFromApi(json['category'] as String),
        subtitle: json['subtitle'] as String? ?? '',
        position: Offset(
          (json['position']?['x'] as num?)?.toDouble() ?? 0,
          (json['position']?['y'] as num?)?.toDouble() ?? 0,
        ),
        permissionRequirements: ((json['permissionRequirements'] as List?) ?? []).map((e) => e.toString()).toList(),
        state: _stateFromApi(json['state'] as String? ?? 'idle'),
        disabled: json['disabled'] as bool? ?? false,
      );
}

class WorkflowConnection {
  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String? branchLabel; // e.g. "Success" / "Error" / "Approved"

  WorkflowConnection({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    this.branchLabel,
  });

  factory WorkflowConnection.fromApi(Map<String, dynamic> json) => WorkflowConnection(
        id: json['id'].toString(),
        fromNodeId: json['fromNodeId'].toString(),
        toNodeId: json['toNodeId'].toString(),
        branchLabel: json['branchLabel'] as String?,
      );
}

enum WorkflowLifecycle { draft, validating, ready, active, paused }

class Workflow {
  final String id;
  final String name;
  final String description;
  String version;
  WorkflowLifecycle lifecycle;
  final String triggerSummary; // human readable trigger description
  final List<WorkflowNode> nodes;
  final List<WorkflowConnection> connections;
  DateTime updatedAt;
  bool graphLoaded;

  Workflow({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.lifecycle,
    required this.triggerSummary,
    required this.nodes,
    required this.connections,
    DateTime? updatedAt,
    this.graphLoaded = false,
  }) : updatedAt = updatedAt ?? DateTime.now();

  static WorkflowLifecycle _lifecycleFromApi(String s) =>
      WorkflowLifecycle.values.firstWhere((v) => v.name == s, orElse: () => WorkflowLifecycle.draft);

  /// From the list endpoint (`GET /workflows`) — no graph included.
  factory Workflow.fromApiSummary(Map<String, dynamic> json) => Workflow(
        id: json['id'].toString(),
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        version: json['version'] as String? ?? 'v0.1',
        lifecycle: _lifecycleFromApi(json['lifecycle'] as String? ?? 'draft'),
        triggerSummary: json['triggerSummary'] as String? ?? 'Not configured',
        nodes: [],
        connections: [],
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
        graphLoaded: false,
      );

  /// From the detail endpoint (`GET /workflows/:id`) — includes the full graph.
  factory Workflow.fromApiDetail(Map<String, dynamic> json) => Workflow(
        id: json['id'].toString(),
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        version: json['version'] as String? ?? 'v0.1',
        lifecycle: _lifecycleFromApi(json['lifecycle'] as String? ?? 'draft'),
        triggerSummary: json['triggerSummary'] as String? ?? 'Not configured',
        nodes: ((json['nodes'] as List?) ?? []).map((n) => WorkflowNode.fromApi(n)).toList(),
        connections: ((json['connections'] as List?) ?? []).map((c) => WorkflowConnection.fromApi(c)).toList(),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
        graphLoaded: true,
      );
}

enum ExecutionState {
  queued,
  running,
  waitingApproval,
  completed,
  failed,
  paused,
  cancelled,
}

class ExecutionEvent {
  final DateTime time;
  final String label;
  ExecutionEvent(this.time, this.label);
}

class WorkflowExecution {
  final String id;
  final String workflowId;
  ExecutionState state;
  final List<ExecutionEvent> timeline;
  DateTime startedAt;

  WorkflowExecution({
    required this.id,
    required this.workflowId,
    required this.state,
    List<ExecutionEvent>? timeline,
    DateTime? startedAt,
  })  : timeline = timeline ?? [],
        startedAt = startedAt ?? DateTime.now();
}
