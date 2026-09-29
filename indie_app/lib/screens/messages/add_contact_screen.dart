import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/chat_models.dart';
import '../../state/app_state.dart';
import 'chat_screen.dart';

/// Contacts are people only — to add an agent, ask the Orchestrator.
/// With [existing] set, edits that contact instead of creating a new one.
class AddContactScreen extends StatefulWidget {
  final Contact? existing;
  const AddContactScreen({super.key, this.existing});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _info = TextEditingController(text: widget.existing?.info ?? '');
  String _group = '';
  bool _loading = false;
  String? _nameErr, _infoErr;

  static const _groups = ['None', 'Family', 'Work', 'Clients'];

  @override
  void initState() {
    super.initState();
    _group = widget.existing?.group.isNotEmpty == true ? widget.existing!.group : 'None';
  }

  Future<void> _save() async {
    setState(() {
      _nameErr = _name.text.trim().isEmpty ? 'Name is required' : null;
      _infoErr = _info.text.trim().isEmpty ? 'Enter an Indie ID, phone number or email' : null;
    });
    if (_nameErr != null || _infoErr != null) return;
    setState(() => _loading = true);
    final group = _group == 'None' ? '' : _group;
    try {
      if (widget.existing != null) {
        await context.read<AppState>().updateContact(widget.existing!.id, name: _name.text.trim(), info: _info.text.trim(), group: group);
        if (mounted) Navigator.of(context).pop();
      } else {
        final c = await context.read<AppState>().addContact(name: _name.text.trim(), info: _info.text.trim(), group: group);
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
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Contact' : 'Create New Contact')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!editing)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('Contacts are people only. To add an agent, ask the Orchestrator to create one.', style: TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
            ),
          TextField(controller: _name, decoration: InputDecoration(labelText: 'Name', hintText: 'e.g. John Smith', errorText: _nameErr)),
          const SizedBox(height: 14),
          TextField(controller: _info, decoration: InputDecoration(labelText: 'Indie ID / Phone / Email', hintText: 'e.g. john@indie.id', errorText: _infoErr)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _group,
            decoration: const InputDecoration(labelText: 'Add to group (optional)'),
            items: _groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (v) => setState(() => _group = v ?? 'None'),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(editing ? 'Save changes' : 'Save Contact'),
          ),
        ],
      ),
    );
  }
}
