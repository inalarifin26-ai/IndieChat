import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/consent_models.dart';

/// Implements: Output -> User review -> Select recipient -> Select data -> Share.
/// Never pre-checks Raw Data / Agent Activity / Private Notes — those require
/// explicit opt-in every time, per Invariant 3 (result sharing only).
class ShareResultSheet extends StatefulWidget {
  final VaultOutput output;
  final void Function({
    required bool report,
    required bool aiSummary,
    required bool rawData,
    required bool agentActivity,
    String? recipient,
  }) onShared;
  const ShareResultSheet({super.key, required this.output, required this.onShared});

  @override
  State<ShareResultSheet> createState() => _ShareResultSheetState();
}

class _ShareResultSheetState extends State<ShareResultSheet> {
  bool report = true;
  bool aiSummary = true;
  bool rawData = false;
  bool agentActivity = false;
  bool privateNotes = false;
  String recipient = 'Choose recipient';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Share result', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 2),
          Text(widget.output.title, style: const TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
          const SizedBox(height: 16),
          _recipientPicker(),
          const SizedBox(height: 14),
          const Text('Included data', style: TextStyle(color: AppColors.textFaint, fontSize: 12, fontWeight: FontWeight.w600)),
          _check('Report', report, (v) => setState(() => report = v)),
          _check('AI Summary', aiSummary, (v) => setState(() => aiSummary = v)),
          _check('Raw Data', rawData, (v) => setState(() => rawData = v)),
          _check('Agent Activity', agentActivity, (v) => setState(() => agentActivity = v)),
          _check('Private Notes', privateNotes, (v) => setState(() => privateNotes = v)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(12)),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 15, color: AppColors.textFaint),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The workflow definition, credentials and private memory are never included.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: (report || aiSummary || rawData || agentActivity || privateNotes)
                      ? () {
                          Navigator.of(context).pop();
                          widget.onShared(
                            report: report,
                            aiSummary: aiSummary,
                            rawData: rawData,
                            agentActivity: agentActivity,
                            recipient: recipient == 'Choose recipient' ? null : recipient,
                          );
                        }
                      : null,
                  child: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recipientPicker() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final choice = await showModalBottomSheet<String>(
          context: context,
          builder: (_) => SafeArea(
            child: Wrap(
              children: ['Alex Rahman', 'Sarah Putri', 'Client — Tokopintar UMKM', 'Copy link']
                  .map((e) => ListTile(title: Text(e), onTap: () => Navigator.of(context).pop(e)))
                  .toList(),
            ),
          ),
        );
        if (choice != null) setState(() => recipient = choice);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.stroke)),
        child: Row(
          children: [
            const Icon(Icons.person_add_alt_1_rounded, size: 18, color: AppColors.textFaint),
            const SizedBox(width: 10),
            Expanded(child: Text(recipient, style: const TextStyle(fontSize: 13.5))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }

  Widget _check(String label, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      title: Text(label, style: const TextStyle(fontSize: 13.5)),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeColor: AppColors.indigo,
    );
  }
}
