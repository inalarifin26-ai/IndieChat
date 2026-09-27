import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/chat_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/consent_sheet.dart';
import 'agent_dashboard_screen.dart';

class AgentChatScreen extends StatefulWidget {
  final String agentId;
  const AgentChatScreen({super.key, required this.agentId});

  @override
  State<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends State<AgentChatScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<AppState>().ensureAgentMessagesLoaded(widget.agentId);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final agent = state.agents.firstWhere((a) => a.id == widget.agentId);

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
              reverse: true,
              padding: const EdgeInsets.all(14),
              itemCount: agent.messages.length,
              itemBuilder: (context, i) {
                final m = agent.messages.reversed.toList()[i];
                if (m.kind == MessageKind.approvalRequest) {
                  return _ApprovalCard(agentId: agent.id, message: m);
                }
                final mine = m.sender == SenderKind.user;
                final system = m.sender == SenderKind.system;
                if (system) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(12)),
                        child: Text(m.text, style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
                      ),
                    ),
                  );
                }
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    decoration: BoxDecoration(
                      color: mine ? AppColors.indigo : AppColors.surfaceCard,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(mine ? 16 : 4),
                        bottomRight: Radius.circular(mine ? 4 : 16),
                      ),
                    ),
                    child: Text(m.text, style: TextStyle(color: mine ? Colors.white : AppColors.textPrimary, fontSize: 14.5)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 8,
              children: [
                ActionChip(label: const Text('Status?'), onPressed: () => _send(context, 'What is your current status?')),
                ActionChip(label: const Text('Pause automation'), onPressed: () => _send(context, 'Pause your current automation.')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _Composer(controller: _controller, onSend: (t) => _send(context, t)),
        ],
      ),
    );
  }

  void _send(BuildContext context, String text) {
    if (text.trim().isEmpty) return;
    context.read<AppState>().sendAgentCommand(widget.agentId, text.trim());
    _controller.clear();
  }
}

class _ApprovalCard extends StatelessWidget {
  final String agentId;
  final ChatMessage message;
  const _ApprovalCard({required this.agentId, required this.message});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final approval = state.approvals.where((a) => a.agentId == agentId && !a.resolved).toList();
    final pending = approval.isNotEmpty ? approval.first : null;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.approval.withOpacity(0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lock_person_rounded, size: 15, color: AppColors.approval),
                SizedBox(width: 6),
                Text('Approval required', style: TextStyle(color: AppColors.approval, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Text(message.text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            if (pending == null)
              Text(
                'Resolved',
                style: TextStyle(color: AppColors.textFaint, fontSize: 12),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => showApprovalSheet(
                        context,
                        agentName: pending.agentName,
                        action: pending.action,
                        scope: pending.scope,
                        onDecision: (ok) => context.read<AppState>().resolveApproval(pending.id, ok),
                      ),
                      child: const Text('Review'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.read<AppState>().resolveApproval(pending.id, true),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  const _Composer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.stroke)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 14.5),
                decoration: const InputDecoration(hintText: 'Command your agent…', isDense: true),
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
