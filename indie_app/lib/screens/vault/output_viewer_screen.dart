import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../widgets/share_result_sheet.dart';

class OutputViewerScreen extends StatelessWidget {
  final String outputId;
  const OutputViewerScreen({super.key, required this.outputId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final o = state.outputs.firstWhere((e) => e.id == outputId);

    return Scaffold(
      appBar: AppBar(title: Text(o.title)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(o.summary, style: const TextStyle(fontSize: 15, height: 1.4)),
          const SizedBox(height: 18),
          _block('AI Summary', o.aiSummary, Icons.auto_awesome_rounded, AppColors.cyan),
          _block('Raw data', o.rawDataPreview, Icons.dataset_outlined, AppColors.textFaint),
          _blockList('Agent activity', o.agentActivity, Icons.timeline_rounded, AppColors.agentAccent),
          const SizedBox(height: 24),
          if (o.shared)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.cyan, size: 18),
                  SizedBox(width: 8),
                  Text('Already shared', style: TextStyle(color: AppColors.cyan, fontSize: 12.5)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => ShareResultSheet(
                output: o,
                onShared: ({required report, required aiSummary, required rawData, required agentActivity, recipient}) async {
                  try {
                    await context.read<AppState>().shareOutput(
                          o.id,
                          recipient: recipient,
                          report: report,
                          aiSummary: aiSummary,
                          rawData: rawData,
                          agentActivity: agentActivity,
                        );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share: $e')));
                    }
                  }
                },
              ),
            ),
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: const Text('Share result'),
          ),
        ],
      ),
    );
  }

  Widget _block(String title, String body, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))]),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _blockList(String title, List<String> items, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))]),
          const SizedBox(height: 6),
          ...items.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('•  $e', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
              )),
        ],
      ),
    );
  }
}
