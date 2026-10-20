import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../models/agent_models.dart';
import '../../models/chat_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../core/theme/app_colors.dart';
import '../agents/agent_chat_screen.dart';
import '../agents/orchestrator_screen.dart';
import 'chat_screen.dart';
import 'contacts_screen.dart';
import 'new_chat_screen.dart';
import 'search_screen.dart';

/// One unified conversation list (people, groups, agents) with filter chips.
/// Every row is still unmistakable: people = pastel initials, groups = group
/// icon, agents = coloured glyph circle + a status line.
class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _Item {
  final Contact? contact;
  final Agent? agent;
  _Item.contact(Contact c)
      : contact = c,
        agent = null;
  _Item.agent(Agent a)
      : agent = a,
        contact = null;

  DateTime get time => (contact?.lastMessage ?? agent?.lastMessage)?.timestamp ?? DateTime(2000);
  bool get pinned => contact?.pinned ?? false;
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  int _filter = 0; // All, People, Agents, Groups

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = <_Item>[];
    if (_filter == 0 || _filter == 1) {
      for (final c in state.people) {
        if (c.lastMessage != null) items.add(_Item.contact(c));
      }
    }
    if (_filter == 0 || _filter == 3) {
      for (final c in state.groups) {
        items.add(_Item.contact(c));
      }
    }
    if (_filter == 0 || _filter == 2) {
      for (final a in state.agents) {
        if (a.lastMessage != null) items.add(_Item.agent(a));
      }
    }
    items.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.time.compareTo(a.time);
    });

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          PageHeader(title: 'Messages', actions: [
            IconButton(tooltip: 'Contacts', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactsScreen())), icon: const Icon(Icons.groups_2_outlined)),
            IconButton(tooltip: 'New chat', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewChatScreen())), icon: const Icon(Icons.edit_outlined)),
          ]),
          SoftSearchField(hint: 'Search chats, agents, or contacts', readOnly: true, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen()))),
          FilterChips(labels: const ['All', 'People', 'Agents', 'Groups'], selected: _filter, onSelected: (i) => setState(() => _filter = i)),
          Expanded(
            child: ListView(children: [
              if (_filter == 0 || _filter == 2)
                ChatRow(
                  avatar: const OrchestratorAvatar(),
                  title: 'Orchestrator',
                  subtitle: 'Direct your agents. Turn ideas into action.',
                  statusLine: const StatusLine(label: 'Active', color: AppColors.success),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrchestratorScreen())),
                ),
              for (final it in items) it.contact != null ? _contactRow(context, it.contact!) : _agentRow(context, it.agent!),
              if (items.isEmpty && _filter != 0 && _filter != 2)
                const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text('No conversations here yet.', style: TextStyle(color: AppColors.textFaint)))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _contactRow(BuildContext context, Contact c) {
    final last = c.lastMessage;
    var preview = last == null ? c.status : last.snippet;
    if (last != null) {
      if (last.isMine) {
        preview = 'You: $preview';
      } else if (c.isGroup && last.from != null) {
        preview = '${last.from}: $preview';
      }
    }
    return ChatRow(
      avatar: c.isGroup ? const GroupAvatar() : ContactAvatar(initials: c.initials, online: c.status.toLowerCase() == 'online'),
      title: c.name,
      time: last == null ? null : listTime(last.timestamp),
      subtitle: preview,
      unread: c.unread,
      pinned: c.pinned,
      muted: c.muted,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(contactId: c.id))),
    );
  }

  Widget _agentRow(BuildContext context, Agent a) {
    final last = a.lastMessage;
    return ChatRow(
      avatar: AgentAvatar(agent: a),
      title: a.name,
      time: last == null ? null : listTime(last.timestamp),
      subtitle: last == null ? a.currentActivity : (last.isMine ? 'You: ${last.snippet}' : last.snippet),
      statusLine: agentStatusLine(a),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AgentChatScreen(agentId: a.id))),
    );
  }
}

/// "● Active" / "● Approval required" / … for an agent.
Widget agentStatusLine(Agent a, {String? suffix}) {
  switch (a.state) {
    case AgentActivityState.waitingApproval:
      return StatusLine(label: 'Approval required', color: AppColors.approval, suffix: suffix);
    case AgentActivityState.scheduled:
      return StatusLine(label: 'Scheduled', color: AppColors.warning, suffix: suffix);
    case AgentActivityState.error:
      return StatusLine(label: 'Error', color: AppColors.danger, suffix: suffix);
    case AgentActivityState.idle:
      return StatusLine(label: 'Idle', color: AppColors.textFaint, suffix: suffix);
    case AgentActivityState.working:
    case AgentActivityState.monitoring:
    case AgentActivityState.ready:
      return StatusLine(label: 'Active', color: AppColors.success, suffix: suffix);
  }
}
