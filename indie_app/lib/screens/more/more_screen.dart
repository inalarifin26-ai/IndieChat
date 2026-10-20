import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../auth/welcome_screen.dart';
import 'connector_manager_screen.dart';
import 'consent_manager_screen.dart';

/// More → "Indie Profile": who you are, then privacy, connectors and account rows.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  String _initials(String n) {
    final p = n.trim().split(RegExp(r'\s+'));
    final a = p.first.isEmpty ? '?' : p.first[0];
    final b = p.length > 1 ? p[1][0] : (p.first.length > 1 ? p.first[1] : '');
    return (a + b).toUpperCase();
  }

  Future<void> _editName(BuildContext context, AppState state) async {
    final c = TextEditingController(text: state.displayName ?? state.personalId ?? '');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Display name', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(controller: c, autofocus: true, maxLength: 40, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel'))),
            const SizedBox(width: 10),
            Expanded(
              child: GradientButton(
                label: 'Save',
                onPressed: () async {
                  if (c.text.trim().isEmpty) return;
                  try {
                    await context.read<AppState>().updateDisplayName(c.text.trim());
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Could not save: $e')));
                  }
                },
              ),
            ),
          ]),
        ]),
      ),
    );
    c.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final name = state.displayName ?? state.personalId ?? '—';
    void snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          const PageHeader(title: 'Indie Profile'),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
            child: Row(children: [
              ContactAvatar(initials: _initials(name), size: 72, online: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                    IconButton(visualDensity: VisualDensity.compact, onPressed: () => _editName(context, state), icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.textSecondary)),
                  ]),
                  const StatusLine(label: 'Online', color: AppColors.success),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(children: [
              CardList(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Indie ID', style: TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                        const SizedBox(height: 2),
                        Text(state.personalId ?? '—', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.content_copy_rounded, size: 18, color: AppColors.textFaint),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: state.personalId ?? ''));
                        snack('Indie ID copied');
                      },
                    ),
                  ]),
                ),
                _kv('Email', 'Not shared', () => snack('Email is not shared')),
                _kv('Phone', 'Not shared', () => snack('Phone is not shared')),
              ]),
              const SizedBox(height: 14),
              CardList(children: [
                SettingsRow(icon: Icons.lock_outline_rounded, title: 'Privacy & Security', subtitle: 'Manage your data and permissions', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsentManagerScreen()))),
                SettingsRow(icon: Icons.link_rounded, title: 'Connectors', subtitle: 'External services and scoped access', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectorManagerScreen()))),
                SettingsRow(icon: Icons.tune_rounded, title: 'Account Settings', subtitle: 'Notification, appearance, language', onTap: () => snack('Account settings are not available yet')),
                SettingsRow(icon: Icons.help_outline_rounded, title: 'Help & Support', subtitle: 'Get help or contact us', onTap: () => snack('support@indie.id')),
              ]),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () async {
                  await context.read<AppState>().logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WelcomeScreen()), (route) => false);
                  }
                },
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: AppColors.danger, side: const BorderSide(color: Color(0xFFF6CFD1)), backgroundColor: const Color(0xFFFFF6F6)),
                child: const Text('Log out', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 18),
              const Text('Personal by default · Consent by design · Private by architecture', style: TextStyle(color: AppColors.textFaint, fontSize: 11), textAlign: TextAlign.center),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _kv(String k, String v, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(k, style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                const SizedBox(height: 2),
                Text(v, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
          ]),
        ),
      );
}
