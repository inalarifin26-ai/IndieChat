import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../models/chat_models.dart';
import '../../models/vault_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../agents/agent_chat_screen.dart';
import 'chat_screen.dart';

/// Search messages, contacts, groups and agents (server-side, scoped to you).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _scopes = ['messages', 'contacts', 'groups', 'agents'];
  final _query = TextEditingController();
  Timer? _debounce;
  int _chip = 0;
  SearchResults? _results;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    if (_query.text.trim().isEmpty) {
      setState(() {
        _results = null;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _run);
  }

  Future<void> _run() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await context.read<AppState>().search(q);
      if (!mounted || q != _query.text.trim()) return;
      setState(() => _results = r);
    } catch (e) {
      if (mounted) setState(() => _error = 'Search failed — check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openRoom(String type, String id, {String? messageId}) {
    final page = type == 'agent' ? AgentChatScreen(agentId: id) : ChatScreen(contactId: id, highlightMessageId: messageId);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _avatarFor(AppState state, String type, String id, String name) {
    if (type == 'agent') {
      final a = state.agents.where((x) => x.id == id);
      if (a.isNotEmpty) return AgentAvatar(agent: a.first);
    }
    if (type == 'group') return const GroupAvatar();
    final c = state.contacts.where((x) => x.id == id);
    return ContactAvatar(initials: c.isNotEmpty ? c.first.initials : name.isEmpty ? '?' : name[0].toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final q = _query.text.trim();
    final rows = <Widget>[];

    if (q.isEmpty) {
      final recent = <_Recent>[
        for (final c in state.contacts) if (c.lastMessage != null) _Recent(c.isGroup ? 'group' : 'contact', c.id, c.name, c.lastMessage!),
        for (final a in state.agents) if (a.lastMessage != null) _Recent('agent', a.id, a.name, a.lastMessage!),
      ]..sort((a, b) => b.last.timestamp.compareTo(a.last.timestamp));
      rows.add(const Padding(padding: EdgeInsets.fromLTRB(18, 4, 18, 4), child: Text('Recent', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5))));
      for (final r in recent.take(7)) {
        rows.add(ChatRow(
          avatar: _avatarFor(state, r.type, r.id, r.name),
          title: r.name,
          time: listTime(r.last.timestamp),
          subtitle: (r.last.isMine ? 'You: ' : '') + r.last.snippet,
          onTap: () => _openRoom(r.type, r.id),
        ));
      }
    } else if (_results != null) {
      final res = _results!;
      switch (_scopes[_chip]) {
        case 'messages':
          rows.add(Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 4), child: Text('${res.messages.length} result${res.messages.length == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5))));
          for (final m in res.messages) {
            rows.add(ChatRow(
              avatar: _avatarFor(state, m.roomType, m.roomId, m.roomName),
              title: m.roomName,
              time: listTime(m.createdAt),
              subtitle: m.snippet,
              onTap: () => _openRoom(m.roomType, m.roomId, messageId: m.messageId),
            ));
          }
          break;
        case 'contacts':
          for (final id in res.contactIds) {
            final c = state.contacts.where((x) => x.id == id);
            if (c.isEmpty) continue;
            rows.add(ChatRow(avatar: ContactAvatar(initials: c.first.initials), title: c.first.name, subtitle: c.first.info.isEmpty ? c.first.status : c.first.info, onTap: () => _openRoom('contact', id)));
          }
          break;
        case 'groups':
          for (final id in res.groupIds) {
            final c = state.contacts.where((x) => x.id == id);
            if (c.isEmpty) continue;
            rows.add(ChatRow(avatar: const GroupAvatar(), title: c.first.name, subtitle: '${c.first.memberCount} members', onTap: () => _openRoom('group', id)));
          }
          break;
        default:
          for (final id in res.agentIds) {
            final a = state.agents.where((x) => x.id == id);
            if (a.isEmpty) continue;
            rows.add(ChatRow(avatar: AgentAvatar(agent: a.first), title: a.first.name, subtitle: agentStyleFor(a.first.name, role: a.first.role).tag, onTap: () => _openRoom('agent', id)));
          }
      }
      if (rows.length <= 1 && _scopes[_chip] == 'messages' || rows.isEmpty) {
        rows.add(Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: Text('No results for “$q”.', style: const TextStyle(color: AppColors.textFaint)))));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Search'), actions: const [Padding(padding: EdgeInsets.only(right: 14), child: Icon(Icons.search_rounded, color: AppColors.textSecondary))]),
      body: Column(children: [
        SoftSearchField(hint: 'Search messages, contacts, groups...', controller: _query, onChanged: _onChanged, autofocus: true),
        FilterChips(labels: const ['Messages', 'Contacts', 'Groups', 'Agents'], selected: _chip, onSelected: (i) => setState(() => _chip = i)),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
        Expanded(child: ListView(children: rows)),
      ]),
    );
  }
}

class _Recent {
  final String type;
  final String id;
  final String name;
  final ChatMessage last;
  _Recent(this.type, this.id, this.name, this.last);
}
