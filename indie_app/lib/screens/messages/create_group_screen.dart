import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'chat_screen.dart';
import 'invite_members_screen.dart';

/// Create Group Chat — name, description, members (your own contacts),
/// "allow new members" and public/private.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  Set<String> _members = {};
  bool _allowNew = true;
  String _visibility = 'private';
  String? _nameErr;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickMembers() async {
    final res = await Navigator.of(context).push<Set<String>>(MaterialPageRoute(builder: (_) => InviteMembersScreen(initial: _members)));
    if (res != null) setState(() => _members = res);
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameErr = 'Group name is required');
      return;
    }
    setState(() {
      _nameErr = null;
      _busy = true;
    });
    try {
      final g = await context.read<AppState>().createGroup(name: _name.text.trim(), description: _desc.text.trim(), visibility: _visibility, allowNewMembers: _allowNew, memberIds: _members.toList());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen(contactId: g.id)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create the group: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final picked = state.people.where((p) => _members.contains(p.id)).toList();
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 24), children: [
        Center(child: Container(width: 68, height: 68, decoration: BoxDecoration(color: const Color(0xFFE5EEFF), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.groups_2_outlined, color: AppColors.accent, size: 32))),
        const SizedBox(height: 14),
        const Center(child: Text('Create Group Chat', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
        const SizedBox(height: 6),
        const Text('Add members and give your group a name and description.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 18),
        _label('Group Name'),
        TextField(controller: _name, decoration: InputDecoration(hintText: 'Marketing Team', errorText: _nameErr)),
        const SizedBox(height: 14),
        _label('Description (Optional)'),
        TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(hintText: 'Discuss campaigns, updates, and more.')),
        const SizedBox(height: 16),
        const Text('Add Members', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          for (final p in picked.take(5)) Padding(padding: const EdgeInsets.only(right: 8), child: ContactAvatar(initials: p.initials, size: 34)),
          GestureDetector(
            onTap: _pickMembers,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.surfaceRaised, borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, size: 15, color: AppColors.textSecondary), SizedBox(width: 4), Text('Add', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))]),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.stroke)),
          child: Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Allow new members', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Others can join this group via invite link', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ),
            Switch(value: _allowNew, onChanged: (v) => setState(() => _allowNew = v)),
          ]),
        ),
        const SizedBox(height: 12),
        CardList(children: [
          _visRow('public', Icons.public_rounded, 'Public Group', 'Anyone with the link can join.'),
          _visRow('private', Icons.lock_outline_rounded, 'Private Group', 'Only invited members can join.'),
        ]),
        const SizedBox(height: 18),
        GradientButton(label: 'Create Group', loading: _busy, onPressed: _create),
      ]),
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)));

  Widget _visRow(String value, IconData icon, String title, String sub) {
    final on = _visibility == value;
    return InkWell(
      onTap: () => setState(() => _visibility = value),
      child: Container(
        color: on ? const Color(0xFFEEF3FF) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.surfaceRaised, borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 18, color: AppColors.indigo)),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
              Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: on ? AppColors.accent : const Color(0xFFC4CCE2), width: 1.8)),
            child: on ? Container(width: 11, height: 11, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)) : null,
          ),
        ]),
      ),
    );
  }
}
