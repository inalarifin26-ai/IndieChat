import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/consent_models.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Share Result — "Share the output, not your workflow."
/// Output → review → format → recipient → included data → Share.
/// Raw Data and Agent Activity are never pre-checked: they need an explicit
/// opt-in every time (Invariant 3, result sharing only). The workflow
/// definition, credentials and private memory have no checkbox at all
/// because they can never be part of a share.
class ShareResultSheet extends StatefulWidget {
  final VaultOutput output;
  final void Function({
    required bool report,
    required bool aiSummary,
    required bool rawData,
    required bool agentActivity,
    required String format,
    String? recipient,
  }) onShared;
  const ShareResultSheet({super.key, required this.output, required this.onShared});

  @override
  State<ShareResultSheet> createState() => _ShareResultSheetState();
}

class _ShareResultSheetState extends State<ShareResultSheet> {
  static const _formats = ['PDF', 'Link', 'Message', 'File'];
  String _format = 'PDF';
  bool report = true;
  bool aiSummary = true;
  bool rawData = false;
  bool agentActivity = false;
  String? _recipient; // a contact or group name; null = not chosen

  Future<void> _pickRecipient() async {
    final state = context.read<AppState>();
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(padding: EdgeInsets.fromLTRB(20, 14, 20, 6), child: Text('Recipient', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
          for (final c in state.contacts)
            ListTile(
              leading: c.isGroup ? const GroupAvatar(size: 34) : ContactAvatar(initials: c.initials, size: 34),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(ctx).pop(c.name),
            ),
        ]),
      ),
    );
    if (choice != null) setState(() => _recipient = choice);
  }

  @override
  Widget build(BuildContext context) {
    final any = report || aiSummary || rawData || agentActivity;
    return SingleChildScrollView(
      padding: EdgeInsets.only(left: 20, right: 20, top: 4, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: Text('Share Result', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19))),
          const SizedBox(height: 2),
          const Center(child: Text('Share the output, not your workflow.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5))),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.stroke)),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.description_outlined, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.output.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
            ]),
          ),
          const _Label('Share as'),
          CardList(children: [
            for (final f in _formats)
              InkWell(
                onTap: () => setState(() => _format = f),
                child: Container(
                  color: _format == f ? const Color(0xFFEEF3FF) : Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: _format == f ? AppColors.accent : const Color(0xFFC4CCE2), width: 1.8)),
                      child: _format == f ? Container(width: 11, height: 11, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)) : null,
                    ),
                    const SizedBox(width: 12),
                    Text(f, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
          ]),
          const _Label('Recipient'),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickRecipient,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.stroke)),
              child: Row(children: [
                const Icon(Icons.person_add_alt_1_rounded, size: 19, color: AppColors.textFaint),
                const SizedBox(width: 10),
                Expanded(child: Text(_recipient ?? 'Choose recipient', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _recipient == null ? AppColors.textFaint : AppColors.textPrimary))),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
              ]),
            ),
          ),
          const _Label('Data included'),
          _check('Report', report, (v) => setState(() => report = v)),
          _check('AI Summary', aiSummary, (v) => setState(() => aiSummary = v)),
          _check('Raw Data', rawData, (v) => setState(() => rawData = v)),
          _check('Agent Activity', agentActivity, (v) => setState(() => agentActivity = v)),
          const SizedBox(height: 6),
          const Text('The workflow definition, credentials and private memory are never included.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(
              child: GradientButton(
                label: 'Share',
                onPressed: any
                    ? () {
                        Navigator.of(context).pop();
                        widget.onShared(report: report, aiSummary: aiSummary, rawData: rawData, agentActivity: agentActivity, format: _format, recipient: _recipient);
                      }
                    : null,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _check(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Row(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: value ? AppColors.accent : Colors.white, borderRadius: BorderRadius.circular(7), border: Border.all(color: value ? AppColors.accent : const Color(0xFFC4CCE2), width: 1.8)),
            child: value ? const Icon(Icons.check_rounded, color: Colors.white, size: 15) : null,
          ),
          const SizedBox(width: 11),
          Text(label, style: const TextStyle(fontSize: 14)),
        ]),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)));
}
