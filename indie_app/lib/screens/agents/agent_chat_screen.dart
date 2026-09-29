import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/chat_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/consent_sheet.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/message_action_sheet.dart';
import 'agent_dashboard_screen.dart';
import 'orchestrator_screen.dart';

class AgentChatScreen extends StatefulWidget {
  final String agentId;
  const AgentChatScreen({super.key, required this.agentId});

  @override
  State<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends State<AgentChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};
  ChatMessage? _replyTo;
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().ensureAgentMessagesLoaded(widget.agentId);
  }

  Future<void> _send({String? text, MessageKind kind = MessageKind.text, Map<String, dynamic>? payload, String? outputId}) async {
    final replyId = _replyTo?.id;
    setState(() => _replyTo = null);
    try {
      await context.read<AppState>().sendAgentMessage(
            widget.agentId,
            text: text,
            kind: kind,
            payload: payload,
            outputId: outputId,
            replyToId: replyId,
          );
      _jumpToEndSoon();
      setState(() => _typing = true);
      // The backend replies ~0.8s later, and may add a follow-up result card
      // ~1.5s after that — poll twice to pick both up.
      Future.delayed(const Duration(milliseconds: 1000), () async {
        if (!mounted) return;
        await context.read<AppState>().refreshAgentMessages(widget.agentId);
        if (mounted) {
          setState(() => _typing = false);
          _jumpToEndSoon();
        }
      });
      Future.delayed(const Duration(milliseconds: 2600), () {
        if (mounted) {
          context.read<AppState>().refreshAgentMessages(widget.agentId);
          _jumpToEndSoon();
        }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send: $e')));
    }
  }

  void _jumpToEndSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  void _openMessage(ChatMessage m) {
    showMessageActions(
      context,
      message: m,
      onReact: (e) => context.read<AppState>().reactAgentMessage(widget.agentId, m.id, e),
      onReply: () => setState(() => _replyTo = m),
      onCopy: m.kind == MessageKind.text
          ? () {
              Clipboard.setData(ClipboardData(text: m.text));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
            }
          : null,
      onSave: (m.kind == MessageKind.card || m.kind == MessageKind.file || m.kind == MessageKind.output)
          ? () => context.read<AppState>().saveAgentMessage(widget.agentId, m.id)
          : null,
      onDelete: m.isMine ? () => context.read<AppState>().deleteAgentMessage(widget.agentId, m.id) : null,
    );
  }

  void _jumpTo(String id) {
    final key = _keys[id];
    if (key?.currentContext != null) Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 300));
  }

  void _askOrchestrator(String agentName) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrchestratorScreen(prefill: 'Update workflow of $agentName: ')));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final agent = state.agents.firstWhere((a) => a.id == widget.agentId);
    final pendingApproval = state.approvals.where((a) => a.agentId == agent.id && !a.resolved).toList();
    final itemCount = agent.messages.length + 1 + (pendingApproval.isNotEmpty ? 1 : 0) + (_typing ? 1 : 0);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AgentDashboardScreen(agentId: agent.id))),
          child: Row(
            children: [
              AgentAvatar(agent: agent, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(agent.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    Text(agent.role, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AgentDashboardScreen(agentId: agent.id))),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(14),
              itemCount: itemCount,
              itemBuilder: (context, i) {
                if (i == 0) return _ScopeBanner(workflow: agent.workflow, onChange: () => _askOrchestrator(agent.name));
                final mi = i - 1;
                if (mi < agent.messages.length) {
                  final m = agent.messages[mi];
                  final showDate = mi == 0 || !_sameDay(agent.messages[mi - 1].timestamp, m.timestamp);
                  _keys.putIfAbsent(m.id, () => GlobalKey());
                  return Column(
                    key: _keys[m.id],
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showDate) DateSeparator(label: _dayLabel(m.timestamp)),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: MessageBubble(
                          message: m,
                          onOpen: () => _openMessage(m),
                          onJumpTo: _jumpTo,
                          onReact: (e) => context.read<AppState>().reactAgentMessage(widget.agentId, m.id, e),
                          onOutputTap: () => _askOrchestrator(agent.name),
                        ),
                      ),
                    ],
                  );
                }
                var idx = mi - agent.messages.length;
                if (_typing) {
                  if (idx == 0) return const Padding(padding: EdgeInsets.only(bottom: 8), child: TypingBubble());
                  idx -= 1;
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _ApprovalCard(agentId: agent.id, approval: pendingApproval.first),
                );
              },
            ),
          ),
          if (_replyTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.stroke))),
              child: Row(
                children: [
                  Container(width: 3, height: 30, color: AppColors.cyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Replying', style: TextStyle(color: AppColors.cyan, fontSize: 11, fontWeight: FontWeight.w700)),
                        Text(_replyTo!.snippet, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setState(() => _replyTo = null)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 8,
              children: [
                ActionChip(label: const Text('Status?'), onPressed: () => _send(text: 'What is your current status?')),
                ActionChip(label: const Text('Pause automation'), onPressed: () => _send(text: 'Pause your current automation.')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _Composer(
            controller: _controller,
            onAttach: () => showAttachSheet(
              context,
              onFile: () => _send(kind: MessageKind.file, payload: {
                'file': {'name': 'Campaign-Report.pdf', 'size': '2.4 MB'}
              }),
              onPhoto: () => _send(kind: MessageKind.file, payload: {
                'file': {'name': 'IMG_2041.jpg', 'size': '1.1 MB'}
              }),
              vaultOutputs: state.outputs,
              onPickOutput: (o) => _send(kind: MessageKind.output, outputId: o.id as String),
            ),
            onSend: (t) {
              if (t.trim().isEmpty) return;
              _controller.clear();
              _send(text: t.trim());
            },
          ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String _dayLabel(DateTime t) {
  final n = DateTime.now();
  if (_sameDay(t, n)) return 'Today';
  if (_sameDay(t, n.subtract(const Duration(days: 1)))) return 'Yesterday';
  return '${t.day}/${t.month}';
}

class _ScopeBanner extends StatelessWidget {
  final List<String> workflow;
  final VoidCallback onChange;
  const _ScopeBanner({required this.workflow, required this.onChange});

  @override
  Widget build(BuildContext context) {
    if (workflow.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: AppColors.cyan.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cyan.withOpacity(0.35))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.lock_rounded, size: 14, color: AppColors.cyan),
            SizedBox(width: 6),
            Text('Workflow defined by Orchestrator', style: TextStyle(color: AppColors.cyan, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          ...workflow.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('•  $s', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              )),
          const SizedBox(height: 6),
          InkWell(onTap: onChange, child: const Text('Change workflow → ask Orchestrator', style: TextStyle(color: AppColors.cyan, fontSize: 11.5, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final String agentId;
  final dynamic approval;
  const _ApprovalCard({required this.agentId, required this.approval});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.approval.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.lock_person_rounded, size: 15, color: AppColors.approval),
            SizedBox(width: 6),
            Text('Approval required', style: TextStyle(color: AppColors.approval, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text(approval.action as String, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showApprovalSheet(
                    context,
                    agentName: approval.agentName as String,
                    action: approval.action as String,
                    scope: approval.scope as String,
                    onDecision: (ok) => context.read<AppState>().resolveApproval(approval.id as String, ok),
                  ),
                  child: const Text('Review'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.read<AppState>().resolveApproval(approval.id as String, true),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final VoidCallback onAttach;
  const _Composer({required this.controller, required this.onSend, required this.onAttach});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 8, 10, 8),
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.stroke))),
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.attach_file_rounded, color: AppColors.textSecondary), onPressed: onAttach),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 14.5),
                decoration: const InputDecoration(hintText: 'Message your agent…', isDense: true),
                onSubmitted: onSend,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => onSend(controller.text),
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(color: AppColors.cyan, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_upward_rounded, color: AppColors.ink, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
