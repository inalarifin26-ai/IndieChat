import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/agent_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'agent_chat_screen.dart';

class AgentCenterScreen extends StatelessWidget {
  const AgentCenterScreen({super.key});

  String _stateLabel(AgentActivityState s) {
    switch (s) {
      case AgentActivityState.idle:
        return 'Idle';
      case AgentActivityState.monitoring:
        return 'Monitoring';
      case AgentActivityState.working:
        return 'Working';
      case AgentActivityState.waitingApproval:
        return 'Approval required';
      case AgentActivityState.scheduled:
        return 'Scheduled';
      case AgentActivityState.error:
        return 'Error';
    }
  }

  Color _stateColor(AgentActivityState s) {
    switch (s) {
      case AgentActivityState.waitingApproval:
        return AppColors.approval;
      case AgentActivityState.error:
        return AppColors.danger;
      case AgentActivityState.working:
      case AgentActivityState.monitoring:
        return AppColors.success;
      case AgentActivityState.scheduled:
        return AppColors.warning;
      case AgentActivityState.idle:
        return AppColors.textFaint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final needsAttention = state.agents.where((a) => a.needsAttention).toList();
    final active = state.agents.where((a) => !a.needsAttention).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Center'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const Text(
            'Your autonomous digital workers — separate from human contacts.',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
          ),
          if (needsAttention.isNotEmpty) ...[
            const SectionHeader(title: 'Needs attention'),
            ...needsAttention.map((a) => _AgentTile(agent: a, stateColor: _stateColor(a.state), stateLabel: _stateLabel(a.state))),
          ],
          const SectionHeader(title: 'Active'),
          ...active.map((a) => _AgentTile(agent: a, stateColor: _stateColor(a.state), stateLabel: _stateLabel(a.state))),
        ],
      ),
    );
  }
}

class _AgentTile extends StatelessWidget {
  final Agent agent;
  final Color stateColor;
  final String stateLabel;
  const _AgentTile({required this.agent, required this.stateColor, required this.stateLabel});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AgentChatScreen(agentId: agent.id))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AgentAvatar(agent: agent, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(agent.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text(agent.currentActivity,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label: stateLabel, color: stateColor),
            ],
          ),
        ),
      ),
    );
  }
}
