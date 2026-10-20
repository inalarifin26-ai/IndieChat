import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../agents/agent_chat_screen.dart';
import 'add_contact_screen.dart';
import 'chat_screen.dart';
import 'messages_list_screen.dart' show agentStatusLine;

/// Contacts: people, groups and agents, each clearly labelled.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _query = TextEditingController();
  int _filter = 0; // All, People, Groups, Agents

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _match(String name) => _query.text.trim().isEmpty || name.toLowerCase().contains(_query.text.trim().toLowerCase());

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rows = <Widget>[];
    if (_filter == 0 || _filter == 1) {
      for (final p in state.people.where((c) => _match(c.name))) {
        final last = p.lastMessage;
        rows.add(ChatRow(
          avatar: ContactAvatar(initials: p.initials, online: p.status.toLowerCase() == 'online'),
          title: p.name,
          subtitle: last == null ? p.status : '${p.status} · ${last.snippet}',
          showChevron: true,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(contactId: p.id))),
        ));
      }
    }
    if (_filter == 0 || _filter == 2) {
      for (final g in state.groups.where((c) => _match(c.name))) {
        rows.add(ChatRow(
          avatar: const GroupAvatar(),
          title: g.name,
          subtitle: '${g.memberCount} members',
          showChevron: true,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(contactId: g.id))),
        ));
      }
    }
    if (_filter == 0 || _filter == 3) {
      for (final a in state.agents.where((c) => _match(c.name))) {
        rows.add(ChatRow(
          avatar: AgentAvatar(agent: a),
          title: a.name,
          subtitle: agentStyleFor(a.name, role: a.role).tag,
          statusLine: agentStatusLine(a),
          showChevron: true,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AgentChatScreen(agentId: a.id))),
        ));
      }
    }

    return Scaffold(
      floatingActionButton: GradientFab(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddContactScreen()))),
      body: SafeArea(
        child: Column(children: [
          PageHeader(title: 'Contacts', actions: [
            IconButton(onPressed: () => context.read<AppState>().refreshAll(), icon: const Icon(Icons.refresh_rounded)),
          ]),
          SoftSearchField(hint: 'Search contacts...', controller: _query, onChanged: (_) => setState(() {})),
          FilterChips(labels: const ['All', 'People', 'Groups', 'Agents'], selected: _filter, onSelected: (i) => setState(() => _filter = i)),
          const Padding(padding: EdgeInsets.fromLTRB(18, 0, 18, 4), child: Align(alignment: Alignment.centerLeft, child: Text('Recent', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)))),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('Nothing matches.', style: TextStyle(color: AppColors.textFaint)))
                : ListView(padding: const EdgeInsets.only(bottom: 90), children: rows),
          ),
        ]),
      ),
    );
  }
}
