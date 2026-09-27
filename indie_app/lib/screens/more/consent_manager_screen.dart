import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/consent_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class ConsentManagerScreen extends StatelessWidget {
  const ConsentManagerScreen({super.key});

  String _label(MandateStatus s) {
    switch (s) {
      case MandateStatus.active:
        return 'Active';
      case MandateStatus.paused:
        return 'Paused';
      case MandateStatus.revoked:
        return 'Revoked';
      case MandateStatus.expired:
        return 'Expired';
    }
  }

  Color _color(MandateStatus s) {
    switch (s) {
      case MandateStatus.active:
        return AppColors.success;
      case MandateStatus.paused:
        return AppColors.warning;
      case MandateStatus.revoked:
      case MandateStatus.expired:
        return AppColors.textFaint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Consent Manager')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Every mandate is attributable to an agent, purpose, scope and autonomy level. You can pause or revoke at any time.',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          ...state.mandates.map((m) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(m.agentName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
                          StatusPill(label: _label(m.status), color: _color(m.status)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(m.purpose, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: m.allowedActions.map((a) => Chip(label: Text(a), visualDensity: VisualDensity.compact)).toList(),
                      ),
                      const SizedBox(height: 4),
                      Text('Autonomy: ${m.autonomy}', style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
                      if (m.externalTarget != null) Text('External: ${m.externalTarget}', style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (m.status == MandateStatus.active)
                            TextButton(
                              onPressed: () => context.read<AppState>().setMandateStatus(m.id, MandateStatus.paused),
                              child: const Text('Pause'),
                            ),
                          if (m.status == MandateStatus.paused)
                            TextButton(
                              onPressed: () => context.read<AppState>().setMandateStatus(m.id, MandateStatus.active),
                              child: const Text('Resume'),
                            ),
                          const Spacer(),
                          if (m.status != MandateStatus.revoked)
                            TextButton(
                              onPressed: () => context.read<AppState>().setMandateStatus(m.id, MandateStatus.revoked),
                              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                              child: const Text('Revoke'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
