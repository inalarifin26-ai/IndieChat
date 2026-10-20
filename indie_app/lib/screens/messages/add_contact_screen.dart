import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/chat_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../agents/orchestrator_screen.dart';
import 'chat_screen.dart';

/// Create New Contact — People | Agent. Agents cannot be added by hand:
/// the Agent tab hands you to the Orchestrator, which builds the agent and
/// defines its workflow. With [existing] set, edits that contact instead.
class AddContactScreen extends StatefulWidget {
  final Contact? existing;
  const AddContactScreen({super.key, this.existing});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _info = TextEditingController(text: widget.existing?.info ?? '');
  String _group = 'None';
  int _tab = 0;
  bool _loading = false;
  String? _nameErr, _infoErr;

  @override
  void initState() {
    super.initState();
    if (widget.existing?.group.isNotEmpty == true) _group = widget.existing!.group;
  }

  @override
  void dispose() {
    _name.dispose();
    _info.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _nameErr = _name.text.trim().isEmpty ? 'Name is required' : null;
      _infoErr = _info.text.trim().isEmpty ? 'Enter an Indie ID, phone number or email' : null;
    });
    if (_nameErr != null || _infoErr != null) return;
    setState(() => _loading = true);
    final state = context.read<AppState>();
    final group = _group == 'None' ? '' : _group;
    try {
      if (widget.existing != null) {
        await state.updateContact(widget.existing!.id, name: _name.text.trim(), info: _info.text.trim(), group: group);
        if (mounted) Navigator.of(context).pop();
      } else {
        final c = await state.addContact(name: _name.text.trim(), info: _info.text.trim(), group: group);
        // "Add to Group": if the chosen name is a real group chat, join it too.
        final real = state.groups.where((g) => g.name == group);
        if (real.isNotEmpty) await state.addGroupMembers(real.first.id, [c.id]);
        if (mounted) {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(contactId: c.id)));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final state = context.watch<AppState>();
    final groups = <String>{'None', 'Family', 'Work', 'Clients', ...state.groups.map((g) => g.name), if (_group != 'None') _group}.toList();
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Contact' : 'Create New Contact')),
      body: Column(children: [
        if (!editing) SegmentedTabs(labels: const ['People', 'Agent'], icons: const [Icons.person_outline_rounded, Icons.auto_awesome_outlined], selected: _tab, onChanged: (i) => setState(() => _tab = i)),
        Expanded(
          child: _tab == 1
              ? ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 24), children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.stroke)),
                    child: Column(children: [
                      const OrchestratorAvatar(size: 64),
                      const SizedBox(height: 14),
                      const Text('Agents are created by the Orchestrator', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text('Tell the Orchestrator what you need. It builds the agent and defines its workflow — then you can chat with it directly.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: GradientButton(
                          label: 'Ask the Orchestrator',
                          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OrchestratorScreen(prefill: 'Create an agent to '))),
                        ),
                      ),
                    ]),
                  ),
                ])
              : ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 24), children: [
                  _label('Name'),
                  TextField(controller: _name, decoration: InputDecoration(hintText: 'John Smith', errorText: _nameErr)),
                  const SizedBox(height: 14),
                  _label('Indie ID / Phone / Email'),
                  TextField(controller: _info, decoration: InputDecoration(hintText: 'e.g. john@indie.id', errorText: _infoErr)),
                  const SizedBox(height: 14),
                  _label('Add to Group (Optional)'),
                  DropdownButtonFormField<String>(
                    value: groups.contains(_group) ? _group : 'None',
                    items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g == 'None' ? 'Select group' : g))).toList(),
                    onChanged: (v) => setState(() => _group = v ?? 'None'),
                  ),
                  const SizedBox(height: 22),
                  GradientButton(label: editing ? 'Save changes' : 'Save Contact', loading: _loading, onPressed: _save),
                ]),
        ),
      ]),
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)));
}
