import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../agents/agent_chat_screen.dart';
import '../agents/orchestrator_screen.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';

/// Create New Chat: a new group, the Orchestrator, INDIE agents, or a contact.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _replaceWith(Widget page) => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final q = _query.text.trim().toLowerCase();
    bool match(String n) => q.isEmpty || n.toLowerCase().contains(q);
    final agents = state.agents.where((a) => match(a.name)).toList();
    final people = state.people.where((c) => match(c.name)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Create New Chat')),
      body: Column(children: [
        SoftSearchField(hint: 'Search contacts or agents', controller: _query, onChanged: (_) => setState(() {})),
        Expanded(
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            const Padding(padding: EdgeInsets.fromLTRB(18, 2, 18, 4), child: Text('Suggested', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5))),
            if (q.isEmpty) ...[
              ChatRow(
                avatar: const GroupAvatar(),
                title: 'New group',
                subtitle: 'Chat with several contacts at once',
                showChevron: true,
                onTap: () => _replaceWith(const CreateGroupScreen()),
              ),
              ChatRow(
                avatar: const OrchestratorAvatar(),
                title: 'Orchestrator',
                subtitle: 'Create agents, run tasks, define workflows',
                showChevron: true,
                onTap: () => _replaceWith(const OrchestratorScreen()),
              ),
            ],
            if (agents.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.fromLTRB(18, 12, 18, 6), child: Text('INDIE Agents', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5))),
              CardList(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                children: [
                  for (final a in agents)
                    ChatRow(
                      avatar: AgentAvatar(agent: a),
                      title: a.name,
                      subtitle: agentStyleFor(a.name, role: a.role).tag,
                      showChevron: true,
                      onTap: () => _replaceWith(AgentChatScreen(agentId: a.id)),
                    ),
                ],
              ),
            ],
            if (people.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.fromLTRB(18, 14, 18, 4), child: Text('Contacts', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5))),
              for (final p in people)
                ChatRow(
                  avatar: ContactAvatar(initials: p.initials, online: p.status.toLowerCase() == 'online'),
                  title: p.name,
                  subtitle: p.status,
                  onTap: () => _replaceWith(ChatScreen(contactId: p.id)),
                ),
            ],
            if (agents.isEmpty && people.isEmpty && q.isNotEmpty)
              const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text('No matches.', style: TextStyle(color: AppColors.textFaint)))),
          ]),
        ),
      ]),
    );
  }
}
