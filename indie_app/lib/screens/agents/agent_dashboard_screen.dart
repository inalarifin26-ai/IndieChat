import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class AgentDashboardScreen extends StatelessWidget {
  final String agentId;
  const AgentDashboardScreen({super.key, required this.agentId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final agent = state.agents.firstWhere((a) => a.id == agentId);
    final mandate = state.mandates.where((m) => m.agentId == agentId).toList();
    if (!agent.detailLoaded) {
      // Idempotent (guarded by detailLoaded) — safe to fire from build().
      state.ensureAgentMessagesLoaded(agentId);
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(agent.name),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: AppColors.cyan,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textFaint,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Activity'),
              Tab(text: 'Permissions'),
              Tab(text: 'Automation'),
              Tab(text: 'Memory'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(agentId: agentId),
            ListView(
              padding: const EdgeInsets.all(16),
              children: agent.activityLog
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 5),
                              child: Icon(Icons.circle, size: 6, color: AppColors.cyan),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(e, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary))),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Granted', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 12.5)),
                const SizedBox(height: 8),
                ...agent.permissions.map((p) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 20),
                        title: Text(p.label, style: const TextStyle(fontSize: 13.5)),
                      ),
                    )),
                if (mandate.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Denied by mandate', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  ...mandate.first.deniedActions.map((p) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.block_rounded, color: AppColors.danger, size: 20),
                          title: Text(p, style: const TextStyle(fontSize: 13.5)),
                        ),
                      )),
                ],
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: agent.automationSummary
                  .map((e) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.schedule_rounded, color: AppColors.warning),
                          title: Text(e, style: const TextStyle(fontSize: 13.5)),
                        ),
                      ))
                  .toList(),
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: agent.memoryNotes.isEmpty
                  ? [const Text('No memory references yet.', style: TextStyle(color: AppColors.textFaint))]
                  : agent.memoryNotes
                      .map((e) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.psychology_alt_outlined, color: AppColors.agentAccent),
                              title: Text(e, style: const TextStyle(fontSize: 13.5)),
                            ),
                          ))
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final String agentId;
  const _OverviewTab({required this.agentId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final agent = state.agents.firstWhere((a) => a.id == agentId);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: AgentAvatar(agent: agent, size: 72)),
        const SizedBox(height: 12),
        Center(child: Text(agent.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
        Center(child: Text(agent.role, style: const TextStyle(color: AppColors.textFaint, fontSize: 12.5))),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: AppColors.cyan, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(agent.currentActivity, style: const TextStyle(fontSize: 13.5))),
              ],
            ),
          ),
        ),
        const SectionHeader(title: 'Quick actions'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.pause_rounded, size: 18),
                label: const Text('Pause'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Adjust'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
