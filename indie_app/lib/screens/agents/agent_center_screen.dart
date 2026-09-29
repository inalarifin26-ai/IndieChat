import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/agent_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/indie_logo.dart';
import 'agent_chat_screen.dart';
import 'orchestrator_screen.dart';

class AgentCenterScreen extends StatelessWidget {
  const AgentCenterScreen({super.key});

  String _stateLabel(AgentActivityState s) {
    switch (s) {
      case AgentActivityState.idle:
        return 'Idle';
      case AgentActivityState.ready:
        return 'Ready';
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
      case AgentActivityState.ready:
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
          IconButton(
            tooltip: 'Ask Orchestrator',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrchestratorScreen())),
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const Text(
            'Agents are created by the Orchestrator, which also defines their workflow.',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrchestratorScreen())),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.transparent),
                  gradient: const LinearGradient(colors: [AppColors.violet, AppColors.indigo, AppColors.cyan], begin: Alignment.bottomLeft, end: Alignment.topRight),
                ),
                child: Container(
                  padding: const EdgeInsets.all(1.4),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        const IndieMark(size: 44),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Orchestrator', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                              Text('Your command center — coordinates multiple agents on one task', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const StatusPill(label: 'Active', color: AppColors.success),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
