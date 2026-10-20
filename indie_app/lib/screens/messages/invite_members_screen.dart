import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Pick people from your own contacts.
///  • [groupId] == null → "Add Members" while creating a group; pops with the chosen ids.
///  • [groupId] set     → "Invite to Group"; adds them to that group and pops.
class InviteMembersScreen extends StatefulWidget {
  final String? groupId;
  final Set<String> initial;
  const InviteMembersScreen({super.key, this.groupId, this.initial = const {}});

  @override
  State<InviteMembersScreen> createState() => _InviteMembersScreenState();
}

class _InviteMembersScreenState extends State<InviteMembersScreen> {
  late final Set<String> _selected = {...widget.initial};
  final _query = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    if (widget.groupId == null) {
      Navigator.of(context).pop(_selected);
      return;
    }
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one contact')));
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AppState>().addGroupMembers(widget.groupId!, _selected.toList());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not invite: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final existing = <String>{};
    if (widget.groupId != null) {
      final g = state.contacts.where((c) => c.id == widget.groupId);
      if (g.isNotEmpty) existing.addAll(g.first.members.map((m) => m.id));
    }
    final q = _query.text.trim().toLowerCase();
    final people = state.people.where((p) => !existing.contains(p.id) && (q.isEmpty || p.name.toLowerCase().contains(q))).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.groupId == null ? 'Add Members' : 'Invite to Group')),
      body: Column(children: [
        SoftSearchField(hint: 'Search contacts...', controller: _query, onChanged: (_) => setState(() {})),
        Expanded(
          child: ListView(children: [
            for (final p in people)
              InkWell(
                onTap: () => setState(() => _selected.contains(p.id) ? _selected.remove(p.id) : _selected.add(p.id)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Row(children: [
                    _Check(on: _selected.contains(p.id)),
                    const SizedBox(width: 12),
                    ContactAvatar(initials: p.initials, online: p.status.toLowerCase() == 'online'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        Text(p.info.isEmpty ? p.status : p.info, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ]),
                    ),
                  ]),
                ),
              ),
            if (people.isEmpty) const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text('No contacts to add.', style: TextStyle(color: AppColors.textFaint)))),
          ]),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Align(alignment: Alignment.centerLeft, child: Text('${_selected.length} selected', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: GradientButton(label: widget.groupId == null ? 'Done' : 'Invite', loading: _busy, onPressed: _done)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Check extends StatelessWidget {
  final bool on;
  const _Check({required this.on});

  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: on ? AppColors.accent : Colors.white, borderRadius: BorderRadius.circular(7), border: Border.all(color: on ? AppColors.accent : const Color(0xFFC4CCE2), width: 1.8)),
        child: on ? const Icon(Icons.check_rounded, color: Colors.white, size: 15) : null,
      );
}
