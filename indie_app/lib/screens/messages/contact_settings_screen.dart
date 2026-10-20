import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/chat_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'add_contact_screen.dart';
import 'invite_members_screen.dart';

/// Chat Settings for a person or a group chat.
class ContactSettingsScreen extends StatefulWidget {
  final String contactId;
  const ContactSettingsScreen({super.key, required this.contactId});

  @override
  State<ContactSettingsScreen> createState() => _ContactSettingsScreenState();
}

class _ContactSettingsScreenState extends State<ContactSettingsScreen> {
  String? _armed; // 'clear' | 'leave' — destructive actions need a second tap

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

  void _arm(String key, String msg, Future<void> Function() action) {
    if (_armed != key) {
      setState(() => _armed = key);
      _toast(msg);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _armed == key) setState(() => _armed = null);
      });
      return;
    }
    setState(() => _armed = null);
    action();
  }

  Future<void> _editGroupInfo(Contact g) async {
    final name = TextEditingController(text: g.name);
    final desc = TextEditingController(text: g.description);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Group info', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Group name')),
          const SizedBox(height: 12),
          TextField(controller: desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel'))),
            const SizedBox(width: 10),
            Expanded(
              child: GradientButton(
                label: 'Save',
                onPressed: () async {
                  if (name.text.trim().isEmpty) return;
                  await context.read<AppState>().updateContact(g.id, name: name.text.trim(), description: desc.text.trim());
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            ),
          ]),
        ]),
      ),
    );
    name.dispose();
    desc.dispose();
  }

  void _openMembers(Contact g) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Consumer<AppState>(builder: (ctx, state, _) {
        final cur = state.contacts.where((c) => c.id == g.id);
        final members = cur.isEmpty ? <GroupMember>[] : cur.first.members;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Members · ${members.length + 1}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(children: [
                ContactAvatar(initials: _myInitials(state), size: 34),
                const SizedBox(width: 12),
                Text(state.displayName ?? state.personalId ?? 'You', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                const StatusPill(label: 'You', color: AppColors.textSecondary),
              ]),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final m in members)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ContactAvatar(initials: m.initials, size: 34),
                      title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                      trailing: IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => context.read<AppState>().removeGroupMember(g.id, m.id)),
                    ),
                ]),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  label: 'Invite more',
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => InviteMembersScreen(groupId: g.id)));
                  },
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  String _myInitials(AppState s) {
    final n = (s.displayName ?? s.personalId ?? '?').trim();
    return n.isEmpty ? '?' : n.substring(0, n.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final found = state.contacts.where((x) => x.id == widget.contactId);
    if (found.isEmpty) return Scaffold(appBar: AppBar(title: const Text('Chat Settings')), body: const SizedBox.shrink());
    final c = found.first;
    final g = c.isGroup;

    return Scaffold(
      appBar: AppBar(title: const Text('Chat Settings')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 24), children: [
        const SizedBox(height: 6),
        Center(
          child: Column(children: [
            g ? const GroupAvatar(size: 72) : ContactAvatar(initials: c.initials, size: 72),
            const SizedBox(height: 10),
            Text(c.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(g ? '${c.memberCount} members' : (c.info.isEmpty ? c.status : c.info), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
            if (g && c.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(c.description, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5))),
          ]),
        ),
        const SizedBox(height: 16),
        CardList(children: [
          if (g) ...[
            SettingsRow(icon: Icons.person_outline_rounded, title: 'Group Info', subtitle: 'Name, description, icon', onTap: () => _editGroupInfo(c)),
            SettingsRow(icon: Icons.groups_2_outlined, title: 'Members', subtitle: 'View and manage members', onTap: () => _openMembers(c)),
          ] else
            SettingsRow(icon: Icons.person_outline_rounded, title: 'Contact Info', subtitle: c.info.isEmpty ? 'Not shared' : c.info, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddContactScreen(existing: c)))),
          SettingsRow(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: g ? 'Message, mention, and call' : 'Mute message and call alerts',
            onTap: () => context.read<AppState>().updateContact(c.id, muted: !c.muted),
            trailing: Switch(value: !c.muted, activeColor: AppColors.accent, onChanged: (_) => context.read<AppState>().updateContact(c.id, muted: !c.muted)),
          ),
          if (!g)
            SettingsRow(
              icon: Icons.push_pin_outlined,
              title: 'Pin chat',
              subtitle: 'Keep at the top of Messages',
              onTap: () => context.read<AppState>().updateContact(c.id, pinned: !c.pinned),
              trailing: Switch(value: c.pinned, activeColor: AppColors.accent, onChanged: (_) => context.read<AppState>().updateContact(c.id, pinned: !c.pinned)),
            ),
          SettingsRow(
            icon: Icons.perm_media_outlined,
            title: 'Media & Files',
            subtitle: 'Shared media and documents',
            onTap: () {
              final n = c.messages.where((m) => m.kind == MessageKind.file || m.kind == MessageKind.output).length;
              _toast(n == 0 ? 'No files shared yet' : '$n file${n == 1 ? '' : 's'} shared in this chat');
            },
          ),
          SettingsRow(
            icon: Icons.delete_outline_rounded,
            title: _armed == 'clear' ? 'Tap again to confirm' : 'Clear Chat History',
            subtitle: 'Remove all messages',
            onTap: () => _arm('clear', 'Tap "Clear Chat History" again to confirm', () async {
              await context.read<AppState>().clearContactHistory(c.id);
              _toast('Chat history cleared');
            }),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(color: const Color(0xFFFFF1F1), borderRadius: BorderRadius.circular(14)),
          child: SettingsRow(
            icon: g ? Icons.logout_rounded : Icons.delete_outline_rounded,
            title: _armed == 'leave' ? 'Tap again to confirm' : (g ? 'Leave Group' : 'Delete Contact'),
            danger: true,
            onTap: () => _arm('leave', g ? 'Tap "Leave Group" again to confirm' : 'Tap "Delete Contact" again to confirm', () async {
              await context.read<AppState>().deleteContact(c.id);
              if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            }),
          ),
        ),
      ]),
    );
  }
}
