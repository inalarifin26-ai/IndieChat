import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/indie_logo.dart';
import '../../widgets/common.dart';
import '../../state/app_state.dart';
import '../onboarding_screen.dart';
import 'consent_manager_screen.dart';
import 'connector_manager_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const IndieMark(size: 40),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Personal ID', style: TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
                      Text(state.personalId ?? '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'Privacy & control'),
          _tile(context, Icons.verified_user_outlined, 'Consent Manager', 'Review and revoke agent mandates', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsentManagerScreen()))),
          _tile(context, Icons.hub_outlined, 'Connectors', 'External services and scoped access', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectorManagerScreen()))),
          _tile(context, Icons.security_rounded, 'Security', 'Sessions, devices, recovery', () {}),
          const SectionHeader(title: 'Account'),
          _tile(context, Icons.person_outline_rounded, 'Account', 'Personal ID & preferences', () {}),
          _tile(context, Icons.workspace_premium_outlined, 'Subscription', 'Manage your plan', () {}),
          _tile(context, Icons.logout_rounded, 'Log out', 'End this session on this device', () async {
            await context.read<AppState>().logout();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                (route) => false,
              );
            }
          }),
          const SizedBox(height: 20),
          const Center(
            child: Text('Personal by default · Consent by design · Private by architecture', style: TextStyle(color: AppColors.textFaint, fontSize: 11), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textFaint)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
      ),
    );
  }
}
