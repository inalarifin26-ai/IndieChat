import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'add_contact_screen.dart';

class ContactSettingsScreen extends StatefulWidget {
  final String contactId;
  const ContactSettingsScreen({super.key, required this.contactId});

  @override
  State<ContactSettingsScreen> createState() => _ContactSettingsScreenState();
}

class _ContactSettingsScreenState extends State<ContactSettingsScreen> {
  bool _armedClear = false;
  bool _armedDelete = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = state.contacts.firstWhere((x) => x.id == widget.contactId);

    return Scaffold(
      appBar: AppBar(title: const Text('Chat Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                ContactAvatar(initials: c.initials, size: 64),
                const SizedBox(height: 10),
                Text(c.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text(c.status, style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _row(
            icon: Icons.person_outline_rounded,
            title: 'Contact info',
            subtitle: c.info.isEmpty ? 'Not shared' : c.info,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddContactScreen(existing: c))),
          ),
          _switchRow(
            icon: Icons.notifications_off_outlined,
            title: 'Mute notifications',
            subtitle: 'Message and call alerts',
            value: c.muted,
            onChanged: (_) => context.read<AppState>().updateContact(c.id, muted: !c.muted),
          ),
          _switchRow(
            icon: Icons.push_pin_outlined,
            title: 'Pin chat',
            subtitle: 'Keep at the top of Messages',
            value: c.pinned,
            onChanged: (_) => context.read<AppState>().updateContact(c.id, pinned: !c.pinned),
          ),
          _row(icon: Icons.perm_media_outlined, title: 'Media & files', subtitle: 'Shared media and documents', onTap: () => _toast('No media shared yet')),
          _row(icon: Icons.groups_outlined, title: 'Group', subtitle: c.group.isEmpty ? 'None' : c.group, onTap: () => _toast('Group: ${c.group.isEmpty ? 'None' : c.group}')),
          const SizedBox(height: 10),
          _dangerRow(
            icon: Icons.cleaning_services_outlined,
            title: 'Clear chat history',
            subtitle: 'Remove all messages in this chat',
            armed: _armedClear,
            onTap: () {
              if (!_armedClear) {
                setState(() => _armedClear = true);
                _toast('Tap again to confirm');
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) setState(() => _armedClear = false);
                });
                return;
              }
              context.read<AppState>().clearContactHistory(c.id);
              setState(() => _armedClear = false);
              _toast('Chat history cleared');
            },
          ),
          _dangerRow(
            icon: Icons.delete_outline_rounded,
            title: 'Delete contact',
            subtitle: 'Removes the contact and its chat',
            armed: _armedDelete,
            onTap: () async {
              if (!_armedDelete) {
                setState(() => _armedDelete = true);
                _toast('Tap again to confirm');
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) setState(() => _armedDelete = false);
                });
                return;
              }
              await context.read<AppState>().deleteContact(c.id);
              if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
        ],
      ),
    );
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

  Widget _row({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
    );
  }

  Widget _switchRow({required IconData icon, required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return ListTile(
      onTap: () => onChanged(!value),
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
      trailing: Switch(value: value, onChanged: onChanged, activeColor: AppColors.indigo),
    );
  }

  Widget _dangerRow({required IconData icon, required String title, required String subtitle, required bool armed, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.danger),
      title: Text(armed ? 'Tap again to confirm' : title, style: const TextStyle(fontSize: 14, color: AppColors.danger)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
    );
  }
}
