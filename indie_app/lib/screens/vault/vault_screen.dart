import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../models/consent_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'output_viewer_screen.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  IconData _iconFor(OutputKind k) {
    switch (k) {
      case OutputKind.report:
        return Icons.description_rounded;
      case OutputKind.dashboard:
        return Icons.space_dashboard_rounded;
      case OutputKind.message:
        return Icons.message_rounded;
      case OutputKind.document:
        return Icons.article_rounded;
      case OutputKind.spreadsheet:
        return Icons.table_chart_rounded;
      case OutputKind.image:
        return Icons.image_rounded;
      case OutputKind.data:
        return Icons.dataset_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Personal Vault')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const Text(
            'Your private storage — outputs, reports and workflow records. Nothing leaves here without explicit sharing.',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
          ),
          const SectionHeader(title: 'Agent outputs'),
          ...state.outputs.map((o) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OutputViewerScreen(outputId: o.id))),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
                    child: Icon(_iconFor(o.kind), color: AppColors.success, size: 20),
                  ),
                  title: Text(o.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: Text('${o.workflowName} · ${DateFormat('MMM d').format(o.createdAt)}', style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                  trailing: o.shared
                      ? const Icon(Icons.ios_share_rounded, size: 16, color: AppColors.cyan)
                      : const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
                ),
              )),
          const SectionHeader(title: 'Vault sections'),
          Row(
            children: [
              Expanded(child: _VaultChip(icon: Icons.folder_rounded, label: 'Files')),
              const SizedBox(width: 10),
              Expanded(child: _VaultChip(icon: Icons.psychology_alt_outlined, label: 'Memory')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _VaultChip(icon: Icons.account_tree_outlined, label: 'Workflow records')),
              const SizedBox(width: 10),
              Expanded(child: _VaultChip(icon: Icons.receipt_long_rounded, label: 'Execution history')),
            ],
          ),
        ],
      ),
    );
  }
}

class _VaultChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _VaultChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(icon, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}
