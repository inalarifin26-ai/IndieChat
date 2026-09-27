import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../models/chat_models.dart';
import '../models/agent_models.dart';
import '../models/workflow_models.dart';
import '../models/consent_models.dart';

const _tokenPrefsKey = 'indie_token';

class AppState extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  bool isBootstrapping = true;
  bool isAuthenticated = false;
  String? personalId;
  String? lastError;

  final List<Contact> contacts = [];
  final List<Agent> agents = [];
  final List<Workflow> workflows = [];
  final List<ConsentMandate> mandates = [];
  final List<ApprovalRequest> approvals = [];
  final List<VaultOutput> outputs = [];

  final Map<String, WorkflowExecution> _liveExecutions = {};
  final Map<String, StreamSubscription> _execSubs = {};

  WorkflowExecution? liveExecutionFor(String workflowId) => _liveExecutions[workflowId];

  int get pendingApprovalCount => approvals.where((a) => !a.resolved).length;
  int get agentsNeedingAttention => agents.where((a) => a.needsAttention).length;

  // ---------------- Bootstrap / Auth ----------------

  Future<void> bootstrap() async {
    isBootstrapping = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenPrefsKey);
    if (token != null) {
      _api.token = token;
      try {
        final me = await _api.get('/auth/me');
        personalId = me['personalId'] as String;
        isAuthenticated = true;
        await _loadAll();
      } catch (_) {
        // token invalid/expired/revoked — fall back to onboarding
        await prefs.remove(_tokenPrefsKey);
        _api.token = null;
        isAuthenticated = false;
      }
    }
    isBootstrapping = false;
    notifyListeners();
  }

  Future<String> register(String credential, {bool seedDemo = true}) async {
    final res = await _api.post('/auth/register', {'credential': credential, 'seedDemo': seedDemo});
    await _persistToken(res['token'] as String);
    personalId = res['personalId'] as String;
    isAuthenticated = true;
    await _loadAll();
    notifyListeners();
    return res['recoveryPhrase'] as String; // caller must show this exactly once
  }

  Future<void> login(String enteredPersonalId, String credential) async {
    final res = await _api.post('/auth/login', {'personalId': enteredPersonalId, 'credential': credential});
    await _persistToken(res['token'] as String);
    personalId = res['personalId'] as String;
    isAuthenticated = true;
    await _loadAll();
    notifyListeners();
  }

  Future<void> recover(String enteredPersonalId, String recoveryPhrase, String newCredential) async {
    final res = await _api.post('/auth/recover', {
      'personalId': enteredPersonalId,
      'recoveryPhrase': recoveryPhrase,
      'newCredential': newCredential,
    });
    await _persistToken(res['token'] as String);
    personalId = res['personalId'] as String;
    isAuthenticated = true;
    await _loadAll();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenPrefsKey);
    _api.token = null;
    isAuthenticated = false;
    personalId = null;
    contacts.clear();
    agents.clear();
    workflows.clear();
    mandates.clear();
    approvals.clear();
    outputs.clear();
    for (final sub in _execSubs.values) {
      sub.cancel();
    }
    _execSubs.clear();
    _liveExecutions.clear();
    notifyListeners();
  }

  Future<void> _persistToken(String token) async {
    _api.token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenPrefsKey, token);
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      _api.get('/contacts'),
      _api.get('/agents'),
      _api.get('/workflows'),
      _api.get('/consent/mandates'),
      _api.get('/consent/approvals'),
      _api.get('/vault/outputs'),
    ]);

    contacts
      ..clear()
      ..addAll((results[0] as List).map((j) => Contact.fromApi(j)));
    agents
      ..clear()
      ..addAll((results[1] as List).map((j) => Agent.fromApi(j)));
    workflows
      ..clear()
      ..addAll((results[2] as List).map((j) => Workflow.fromApiSummary(j)));
    mandates
      ..clear()
      ..addAll((results[3] as List).map((j) => ConsentMandate.fromApi(j)));
    approvals
      ..clear()
      ..addAll((results[4] as List).map((j) => ApprovalRequest.fromApi(j)));
    outputs
      ..clear()
      ..addAll((results[5] as List).map((j) => VaultOutput.fromApi(j)));

    _resolveNames();
  }

  void _resolveNames() {
    String agentName(String id) => agents
        .firstWhere((a) => a.id == id, orElse: () => Agent(id: id, name: 'Unknown agent', role: '', glyph: '?', accentHex: '9DA3B4'))
        .name;
    String workflowName(String id) => workflows
        .firstWhere(
          (w) => w.id == id,
          orElse: () => Workflow(
            id: id,
            name: 'Unknown workflow',
            description: '',
            version: '',
            lifecycle: WorkflowLifecycle.draft,
            triggerSummary: '',
            nodes: [],
            connections: [],
          ),
        )
        .name;
    for (final m in mandates) {
      m.agentName = agentName(m.agentId);
    }
    for (final a in approvals) {
      a.agentName = agentName(a.agentId);
      a.workflowName = workflowName(a.workflowId);
    }
    for (final o in outputs) {
      o.workflowName = workflowName(o.workflowId);
    }
  }

  // ---------------- Messaging ----------------

  Future<void> sendContactMessage(String contactId, String text) async {
    await _api.post('/contacts/$contactId/messages', {'text': text});
    final contact = contacts.firstWhere((c) => c.id == contactId);
    contact.messages.add(ChatMessage(id: DateTime.now().microsecondsSinceEpoch.toString(), sender: SenderKind.user, text: text));
    notifyListeners();
  }

  Future<void> ensureContactMessagesLoaded(String contactId) async {
    final contact = contacts.firstWhere((c) => c.id == contactId);
    if (contact.historyLoaded) return;
    final msgs = await _api.get('/contacts/$contactId/messages') as List;
    contact.messages
      ..clear()
      ..addAll(msgs.map((j) => ChatMessage(
            id: j['id'].toString(),
            sender: j['sender'] == 'user' ? SenderKind.user : SenderKind.contact,
            text: j['text'] as String,
            timestamp: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
          )));
    contact.historyLoaded = true;
    notifyListeners();
  }

  Future<void> ensureAgentMessagesLoaded(String agentId) async {
    final agent = agents.firstWhere((a) => a.id == agentId);
    if (agent.detailLoaded) return;
    final results = await Future.wait([
      _api.get('/agents/$agentId/messages'),
      _api.get('/agents/$agentId/activity'),
      _api.get('/agents/$agentId/memory'),
    ]);
    agent.messages
      ..clear()
      ..addAll((results[0] as List).map((j) => ChatMessage.fromApi(j)));
    agent.activityLog
      ..clear()
      ..addAll((results[1] as List).map((j) => j['label'].toString()));
    agent.memoryNotes
      ..clear()
      ..addAll((results[2] as List).map((j) => j['note'].toString()));
    agent.detailLoaded = true;
    notifyListeners();
  }

  Future<void> sendAgentCommand(String agentId, String text) async {
    final agent = agents.firstWhere((a) => a.id == agentId);
    await _api.post('/agents/$agentId/messages', {'text': text});
    agent.messages.add(ChatMessage(id: DateTime.now().microsecondsSinceEpoch.toString(), sender: SenderKind.user, text: text));
    notifyListeners();
    // The backend inserts a scripted reply ~700ms later — poll once for it.
    Future.delayed(const Duration(milliseconds: 900), () async {
      try {
        final msgs = await _api.get('/agents/$agentId/messages') as List;
        agent.messages
          ..clear()
          ..addAll(msgs.map((j) => ChatMessage.fromApi(j)));
        notifyListeners();
      } catch (_) {}
    });
  }

  // ---------------- Consent / Approval ----------------

  Future<void> resolveApproval(String approvalId, bool approve) async {
    await _api.post('/consent/approvals/$approvalId/resolve', {'approve': approve});
    final req = approvals.firstWhere((a) => a.id == approvalId);
    req.resolved = true;
    req.approved = approve;
    try {
      final refreshed = await _api.get('/agents') as List;
      agents
        ..clear()
        ..addAll(refreshed.map((j) => Agent.fromApi(j)));
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setMandateStatus(String mandateId, MandateStatus status) async {
    final res = await _api.patch('/consent/mandates/$mandateId', {'status': status.name});
    final updated = ConsentMandate.fromApi(res);
    final idx = mandates.indexWhere((m) => m.id == mandateId);
    if (idx != -1) {
      updated.agentName = mandates[idx].agentName;
      mandates[idx] = updated;
    }
    notifyListeners();
  }

  // ---------------- Workflow lifecycle & detail ----------------

  Future<void> setWorkflowLifecycle(String workflowId, WorkflowLifecycle lifecycle) async {
    await _api.patch('/workflows/$workflowId', {'lifecycle': lifecycle.name});
    final wf = workflows.firstWhere((w) => w.id == workflowId);
    wf.lifecycle = lifecycle;
    notifyListeners();
  }

  /// The list endpoint doesn't include nodes/connections — fetch the graph
  /// once and merge it into the cached Workflow object.
  Future<Workflow> ensureWorkflowDetailLoaded(String workflowId) async {
    final idx = workflows.indexWhere((w) => w.id == workflowId);
    if (idx != -1 && workflows[idx].graphLoaded) return workflows[idx];
    final json = await _api.get('/workflows/$workflowId');
    final detail = Workflow.fromApiDetail(json);
    if (idx != -1) {
      workflows[idx] = detail;
    } else {
      workflows.add(detail);
    }
    notifyListeners();
    return detail;
  }

  Future<Workflow> createDraftWorkflow() async {
    final json = await _api.post('/workflows', {'name': 'Untitled workflow'});
    final wf = Workflow.fromApiDetail(json);
    workflows.insert(0, wf);
    notifyListeners();
    return wf;
  }

  // ---------------- Workflow Builder ----------------

  Future<void> addNode(String workflowId, NodeCategory category, Offset position) async {
    final json = await _api.post('/workflows/$workflowId/nodes', {
      'category': category.name,
      'position': {'x': position.dx, 'y': position.dy},
    });
    final node = WorkflowNode.fromApi(json);
    workflows.firstWhere((w) => w.id == workflowId).nodes.add(node);
    notifyListeners();
  }

  /// Local-only drag update — no network call per frame. Call
  /// [commitNodeMove] on drag end to persist the final position.
  void moveNode(String workflowId, String nodeId, Offset position) {
    final wf = workflows.firstWhere((w) => w.id == workflowId);
    wf.nodes.firstWhere((n) => n.id == nodeId).position = position;
  }

  Future<void> commitNodeMove(String workflowId, String nodeId) async {
    final wf = workflows.firstWhere((w) => w.id == workflowId);
    final node = wf.nodes.firstWhere((n) => n.id == nodeId);
    try {
      await _api.patch('/workflows/$workflowId/nodes/$nodeId', {
        'position': {'x': node.position.dx, 'y': node.position.dy},
      });
    } catch (_) {}
    notifyListeners();
  }

  Future<void> updateNodeConfig(String workflowId, String nodeId, {required String title, required String subtitle}) async {
    await _api.patch('/workflows/$workflowId/nodes/$nodeId', {'title': title, 'subtitle': subtitle});
    final node = workflows.firstWhere((w) => w.id == workflowId).nodes.firstWhere((n) => n.id == nodeId);
    node.title = title;
    node.subtitle = subtitle;
    notifyListeners();
  }

  Future<void> toggleNodeDisabled(String workflowId, String nodeId) async {
    final node = workflows.firstWhere((w) => w.id == workflowId).nodes.firstWhere((n) => n.id == nodeId);
    final next = !node.disabled;
    await _api.patch('/workflows/$workflowId/nodes/$nodeId', {'disabled': next});
    node.disabled = next;
    notifyListeners();
  }

  Future<void> deleteNode(String workflowId, String nodeId) async {
    await _api.delete('/workflows/$workflowId/nodes/$nodeId');
    final wf = workflows.firstWhere((w) => w.id == workflowId);
    wf.nodes.removeWhere((n) => n.id == nodeId);
    wf.connections.removeWhere((c) => c.fromNodeId == nodeId || c.toNodeId == nodeId);
    notifyListeners();
  }

  Future<void> duplicateNode(String workflowId, String nodeId) async {
    final json = await _api.post('/workflows/$workflowId/nodes/$nodeId/duplicate');
    workflows.firstWhere((w) => w.id == workflowId).nodes.add(WorkflowNode.fromApi(json));
    notifyListeners();
  }

  Future<bool> addConnection(String workflowId, String fromNodeId, String toNodeId) async {
    try {
      final json = await _api.post('/workflows/$workflowId/connections', {'fromNodeId': fromNodeId, 'toNodeId': toNodeId});
      workflows.firstWhere((w) => w.id == workflowId).connections.add(WorkflowConnection.fromApi(json));
      notifyListeners();
      return true;
    } on ApiException {
      return false;
    }
  }

  Future<void> deleteConnection(String workflowId, String connectionId) async {
    await _api.delete('/workflows/$workflowId/connections/$connectionId');
    workflows.firstWhere((w) => w.id == workflowId).connections.removeWhere((c) => c.id == connectionId);
    notifyListeners();
  }

  Future<List<String>> validateWorkflow(String workflowId) async {
    final json = await _api.post('/workflows/$workflowId/validate');
    return ((json['issues'] as List?) ?? []).map((e) => e.toString()).toList();
  }

  // ---------------- Execution (live, via SSE) ----------------

  Future<void> runWorkflow(String workflowId) async {
    final wf = await ensureWorkflowDetailLoaded(workflowId);
    for (final n in wf.nodes) {
      n.state = NodeRuntimeState.idle;
    }
    final res = await _api.post('/workflows/$workflowId/run');
    final executionId = res['executionId'] as String;
    final exec = WorkflowExecution(id: executionId, workflowId: workflowId, state: ExecutionState.running);
    _liveExecutions[workflowId] = exec;
    notifyListeners();

    await _execSubs[workflowId]?.cancel();
    _execSubs[workflowId] = _api.sse('/workflows/executions/$executionId/stream').listen((frame) {
      final data = frame['data'] as Map<String, dynamic>?;
      if (data == null) return;
      switch (data['type']) {
        case 'node':
          final node = wf.nodes.where((n) => n.id == data['nodeId']);
          if (node.isNotEmpty) {
            node.first.state = NodeRuntimeState.values.firstWhere(
              (v) => v.name == data['state'],
              orElse: () => NodeRuntimeState.idle,
            );
          }
          break;
        case 'log':
          exec.timeline.add(ExecutionEvent(DateTime.tryParse(data['at']?.toString() ?? '') ?? DateTime.now(), data['label'].toString()));
          break;
        case 'state':
          exec.state = ExecutionState.values.firstWhere((v) => v.name == data['state'], orElse: () => exec.state);
          if (exec.state == ExecutionState.waitingApproval) {
            _api.get('/consent/approvals').then((json) {
              approvals
                ..clear()
                ..addAll((json as List).map((j) => ApprovalRequest.fromApi(j)));
              _resolveNames();
              notifyListeners();
            }).catchError((_) {});
          }
          break;
      }
      notifyListeners();
    }, onError: (_) {});
  }

  // ---------------- Vault / Sharing ----------------

  Future<Map<String, dynamic>> shareOutput(
    String outputId, {
    String? recipient,
    required bool report,
    required bool aiSummary,
    required bool rawData,
    required bool agentActivity,
  }) async {
    final res = await _api.post('/vault/outputs/$outputId/share', {
      'recipient': recipient,
      'include': {'report': report, 'aiSummary': aiSummary, 'rawData': rawData, 'agentActivity': agentActivity},
    });
    outputs.firstWhere((o) => o.id == outputId).shared = true;
    notifyListeners();
    return res as Map<String, dynamic>;
  }

  @override
  void dispose() {
    for (final sub in _execSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
