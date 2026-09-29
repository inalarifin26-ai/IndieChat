import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../models/chat_models.dart';
import '../models/agent_models.dart';
import '../models/workflow_models.dart';
import '../models/consent_models.dart';
import '../models/orchestrator_models.dart';

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

  // Orchestrator chat thread (the only place agents are created).
  final List<OrchMessage> orchMessages = [];
  bool orchLoaded = false;
  bool orchWaiting = false; // an instruction is in flight; the reply arrives via polling

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
    orchMessages.clear();
    orchLoaded = false;
    orchWaiting = false;
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

  // ---------------- Messaging: shared helpers ----------------

  String _kindStr(MessageKind k) {
    switch (k) {
      case MessageKind.file:
        return 'file';
      case MessageKind.output:
        return 'output';
      default:
        return 'text';
    }
  }

  /// A cheap fingerprint so polling only rebuilds the UI when something changed
  /// (new message, delivery status, reaction, delete, saved).
  String _sig(List<ChatMessage> l) => l
      .map((m) => '${m.id}|${m.status}|${m.myReaction}|${m.reactions}|${m.deleted}|${m.saved}')
      .join(';');

  Map<String, dynamic> _messageBody({
    String? text,
    MessageKind kind = MessageKind.text,
    Map<String, dynamic>? payload,
    String? outputId,
    String? replyToId,
  }) =>
      {
        'kind': _kindStr(kind),
        if (text != null) 'text': text,
        if (payload != null) 'payload': payload,
        if (outputId != null) 'outputId': outputId,
        if (replyToId != null) 'replyToId': replyToId,
      };

  void _replaceMessage(List<ChatMessage> list, Map<String, dynamic> json) {
    final updated = ChatMessage.fromApi(json);
    final i = list.indexWhere((m) => m.id == updated.id);
    if (i != -1) list[i] = updated;
    notifyListeners();
  }

  // ---------------- Messaging: contacts (people only) ----------------

  Future<Contact> addContact({required String name, required String info, String group = ''}) async {
    final json = await _api.post('/contacts', {'name': name, 'info': info, 'group': group});
    final c = Contact.fromApi(json);
    contacts.add(c);
    notifyListeners();
    return c;
  }

  Future<void> updateContact(String id, {String? name, String? info, String? group, bool? muted, bool? pinned}) async {
    final json = await _api.patch('/contacts/$id', {
      if (name != null) 'name': name,
      if (info != null) 'info': info,
      if (group != null) 'group': group,
      if (muted != null) 'muted': muted,
      if (pinned != null) 'pinned': pinned,
    });
    final i = contacts.indexWhere((c) => c.id == id);
    if (i == -1) return;
    final old = contacts[i];
    final fresh = Contact.fromApi(json);
    fresh.messages
      ..clear()
      ..addAll(old.messages);
    fresh.historyLoaded = old.historyLoaded;
    contacts[i] = fresh;
    notifyListeners();
  }

  Future<void> deleteContact(String id) async {
    await _api.delete('/contacts/$id');
    contacts.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  Future<void> clearContactHistory(String id) async {
    await _api.delete('/contacts/$id/messages');
    final c = contacts.firstWhere((c) => c.id == id);
    c.messages.clear();
    c.historyLoaded = true;
    notifyListeners();
  }

  /// Loads the full history (the server also marks the room as read).
  Future<void> ensureContactMessagesLoaded(String contactId) async {
    final contact = contacts.firstWhere((c) => c.id == contactId);
    if (contact.historyLoaded) {
      if (contact.unread != 0) {
        contact.unread = 0;
        notifyListeners();
      }
      return;
    }
    await refreshContactMessages(contactId, force: true);
  }

  Future<void> refreshContactMessages(String contactId, {bool force = false}) async {
    final idx = contacts.indexWhere((c) => c.id == contactId);
    if (idx == -1) return;
    final contact = contacts[idx];
    final msgs = (await _api.get('/contacts/$contactId/messages') as List).map((j) => ChatMessage.fromApi(j)).toList();
    final changed = force || _sig(msgs) != _sig(contact.messages);
    contact.unread = 0;
    contact.historyLoaded = true;
    if (changed) {
      contact.messages
        ..clear()
        ..addAll(msgs);
      notifyListeners();
    }
  }

  Future<void> sendContactMessage(
    String contactId, {
    String? text,
    MessageKind kind = MessageKind.text,
    Map<String, dynamic>? payload,
    String? outputId,
    String? replyToId,
  }) async {
    final json = await _api.post(
      '/contacts/$contactId/messages',
      _messageBody(text: text, kind: kind, payload: payload, outputId: outputId, replyToId: replyToId),
    );
    final contact = contacts.firstWhere((c) => c.id == contactId);
    contact.messages.add(ChatMessage.fromApi(json));
    notifyListeners();
  }

  Future<void> reactContactMessage(String contactId, String messageId, String emoji) async {
    final json = await _api.patch('/contacts/$contactId/messages/$messageId/reaction', {'emoji': emoji});
    _replaceMessage(contacts.firstWhere((c) => c.id == contactId).messages, json);
  }

  Future<void> deleteContactMessage(String contactId, String messageId) async {
    final json = await _api.delete('/contacts/$contactId/messages/$messageId');
    _replaceMessage(contacts.firstWhere((c) => c.id == contactId).messages, json);
  }

  Future<void> saveContactMessage(String contactId, String messageId) async {
    final json = await _api.post('/contacts/$contactId/messages/$messageId/save');
    _replaceMessage(contacts.firstWhere((c) => c.id == contactId).messages, json);
  }

  // ---------------- Messaging: agents (scoped to the Orchestrator's workflow) ----------------

  Future<void> ensureAgentMessagesLoaded(String agentId, {bool force = false}) async {
    final agent = agents.firstWhere((a) => a.id == agentId);
    if (agent.detailLoaded && !force) return;
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

  Future<void> refreshAgentMessages(String agentId) async {
    final idx = agents.indexWhere((a) => a.id == agentId);
    if (idx == -1) return;
    final agent = agents[idx];
    final msgs = (await _api.get('/agents/$agentId/messages') as List).map((j) => ChatMessage.fromApi(j)).toList();
    if (_sig(msgs) != _sig(agent.messages)) {
      agent.messages
        ..clear()
        ..addAll(msgs);
      agent.detailLoaded = true;
      notifyListeners();
    }
  }

  /// Returns the server's scope verdict: in_scope | out_of_scope | status.
  Future<String> sendAgentMessage(
    String agentId, {
    String? text,
    MessageKind kind = MessageKind.text,
    Map<String, dynamic>? payload,
    String? outputId,
    String? replyToId,
  }) async {
    final json = await _api.post(
      '/agents/$agentId/messages',
      _messageBody(text: text, kind: kind, payload: payload, outputId: outputId, replyToId: replyToId),
    );
    final agent = agents.firstWhere((a) => a.id == agentId);
    agent.messages.add(ChatMessage.fromApi(json['message'] as Map<String, dynamic>));
    notifyListeners();
    return json['scope'] as String? ?? 'status';
  }

  Future<void> reactAgentMessage(String agentId, String messageId, String emoji) async {
    final json = await _api.patch('/agents/$agentId/messages/$messageId/reaction', {'emoji': emoji});
    _replaceMessage(agents.firstWhere((a) => a.id == agentId).messages, json);
  }

  Future<void> deleteAgentMessage(String agentId, String messageId) async {
    final json = await _api.delete('/agents/$agentId/messages/$messageId');
    _replaceMessage(agents.firstWhere((a) => a.id == agentId).messages, json);
  }

  Future<void> saveAgentMessage(String agentId, String messageId) async {
    final json = await _api.post('/agents/$agentId/messages/$messageId/save');
    _replaceMessage(agents.firstWhere((a) => a.id == agentId).messages, json);
  }

  // ---------------- Orchestrator (creates agents, defines their workflows) ----------------

  Future<void> loadOrchestrator() async {
    final list = await _api.get('/orchestrator/messages') as List;
    orchMessages
      ..clear()
      ..addAll(list.map((j) => OrchMessage.fromApi(j)));
    orchLoaded = true;
    notifyListeners();
  }

  /// Polls for new thread messages. When agents/workflows were created or
  /// changed, the local lists are refreshed too so they show up in the tabs.
  Future<void> refreshOrchestrator() async {
    if (!orchLoaded || orchMessages.isEmpty) {
      await loadOrchestrator();
      return;
    }
    final list = await _api.get('/orchestrator/messages?after=${orchMessages.last.id}') as List;
    if (list.isEmpty) return;
    final fresh = list.map((j) => OrchMessage.fromApi(j)).toList();
    orchMessages.addAll(fresh);
    var agentsChanged = false;
    var workflowsChanged = false;
    for (final m in fresh) {
      if (m.kind == OrchKind.agentCreated || m.kind == OrchKind.workflowUpdated || m.kind == OrchKind.agentResult) agentsChanged = true;
      if (m.kind == OrchKind.plan || m.kind == OrchKind.result) {
        agentsChanged = true;
        workflowsChanged = true;
      }
      final terminal = m.sender == 'orchestrator' &&
          (m.kind == OrchKind.agentCreated || m.kind == OrchKind.workflowUpdated || m.kind == OrchKind.result || m.kind == OrchKind.text);
      if (terminal) orchWaiting = false;
    }
    if (agentsChanged) await _refreshAgents();
    if (workflowsChanged) await _refreshWorkflows();
    notifyListeners();
  }

  /// Throws [ApiException] (409) if the Orchestrator is still busy.
  Future<void> sendOrchestrator(String text) async {
    if (!orchLoaded) await loadOrchestrator();
    final json = await _api.post('/orchestrator/messages', {'text': text});
    orchMessages.add(OrchMessage.fromApi(json['message'] as Map<String, dynamic>));
    orchWaiting = true;
    notifyListeners();
  }

  Future<void> saveOrchestratorResult(String messageId) async {
    await _api.post('/orchestrator/messages/$messageId/save');
    final m = orchMessages.firstWhere((x) => x.id == messageId);
    m.saved = true;
    final outs = await _api.get('/vault/outputs') as List;
    outputs
      ..clear()
      ..addAll(outs.map((j) => VaultOutput.fromApi(j)));
    _resolveNames();
    notifyListeners();
  }

  Future<void> _refreshAgents() async {
    final fresh = (await _api.get('/agents') as List).map((j) => Agent.fromApi(j)).toList();
    for (final a in fresh) {
      final i = agents.indexWhere((o) => o.id == a.id);
      if (i != -1) {
        final old = agents[i];
        a.messages.addAll(old.messages);
        a.activityLog.addAll(old.activityLog);
        a.memoryNotes.addAll(old.memoryNotes);
        a.detailLoaded = old.detailLoaded;
      }
    }
    agents
      ..clear()
      ..addAll(fresh);
    _resolveNames();
  }

  Future<void> _refreshWorkflows() async {
    final fresh = (await _api.get('/workflows') as List).map((j) => Workflow.fromApiSummary(j)).toList();
    final merged = fresh.map((f) {
      final i = workflows.indexWhere((o) => o.id == f.id);
      return (i != -1 && workflows[i].graphLoaded) ? workflows[i] : f;
    }).toList();
    workflows
      ..clear()
      ..addAll(merged);
    _resolveNames();
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
