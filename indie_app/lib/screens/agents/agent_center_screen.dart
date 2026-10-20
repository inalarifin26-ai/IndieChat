import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../messages/messages_list_screen.dart' show agentStatusLine;
import 'agent_chat_screen.dart';
import 'orchestrator_screen.dart';

class _Template {
  final String name;
  final String desc; // completes "Create an agent to …"
  const _Template(this.name, this.desc);
}

const _templates = <_Template>[
  _Template('Marketing Agent', 'monitor campaigns and report performance weekly'),
  _Template('Research Agent', 'research competitors and summarize findings'),
  _Template('Finance Agent', 'track invoices and summarize cash flow'),
  _Template('Personal Assistant', 'read my calendar and prepare a daily brief'),
  _Template('Health Coach', 'plan workouts and remind me every morning'),
  _Template('Content Creator', 'draft social media posts for my brand'),
];

/// Agent Center — My Agents | Templates. Agents are never created here
/// directly: both tabs hand off to the Orchestrator, which defines the workflow.
class AgentCenterScreen extends StatefulWidget {
  const AgentCenterScreen({super.key});

  @override
  State<AgentCenterScreen> createState() => _AgentCenterScreenState();
}

class _AgentCenterScreenState extends State<AgentCenterScreen> {
  int _tab = 0;

  void _openOrchestrator([String? prefill]) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrchestratorScreen(prefill: prefill)));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          PageHeader(title: 'Agent Center', actions: [
            IconButton(tooltip: 'Orchestrator', onPressed: _openOrchestrator, icon: const Icon(Icons.auto_awesome_outlined)),
          ]),
          SegmentedTabs(labels: const ['My Agents', 'Templates'], selected: _tab, onChanged: (i) => setState(() => _tab = i)),
          Expanded(
            child: _tab == 0
                ? ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                    for (final a in state.agents)
                      ChatRow(
                        avatar: AgentAvatar(agent: a),
                        title: a.name,
                        subtitle: a.currentActivity,
                        statusLine: agentStatusLine(a, suffix: agentStyleFor(a.name, role: a.role).tag),
                        showChevron: true,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AgentChatScreen(agentId: a.id))),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                      child: OutlinedButton.icon(
                        onPressed: () => _openOrchestrator('Create an agent to '),
                        icon: const Icon(Icons.auto_awesome_outlined, size: 17),
                        label: const Text('Create an agent with the Orchestrator'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                      ),
                    ),
                  ])
                : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
                      child: Text('Templates start a conversation with the Orchestrator, which builds the agent and defines its workflow.', style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary)),
                    ),
                    for (final t in _templates) _templateRow(state, t),
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _templateRow(AppState state, _Template t) {
    final have = state.agents.any((a) => a.name == t.name);
    final st = agentStyleFor(t.name);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: st.color, shape: BoxShape.circle), child: Icon(st.icon, color: Colors.white, size: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text(st.tag, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ]),
        ),
        if (have)
          const StatusPill(label: 'Added', color: AppColors.textSecondary)
        else
          SizedBox(
            height: 34,
            child: ElevatedButton(
              onPressed: () => _openOrchestrator('Create an agent to ${t.desc}'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16), textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              child: const Text('Create'),
            ),
          ),
      ]),
    );
  }
}
