import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/consent_models.dart';

/// Renders the spec's "Consent UI pattern": what is accessed, why, what
/// action is requested, the scope, whether it recurs, and that it can be
/// revoked later. Used both for approvals and for new mandate requests.
class ConsentSheet extends StatelessWidget {
  final String agentName;
  final String purpose;
  final String action;
  final String scope;
  final String autonomy;
  final bool showRevocationNote;
  final ValueChanged<bool> onDecision;

  const ConsentSheet({
    super.key,
    required this.agentName,
    required this.purpose,
    required this.action,
    required this.scope,
    required this.autonomy,
    required this.onDecision,
    this.showRevocationNote = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.approval.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.lock_person_rounded, color: AppColors.approval, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(agentName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                    const Text('Requesting permission', style: TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _row('Wants to', action),
          _row('Purpose', purpose),
          _row('Access / scope', scope),
          _row('Autonomy', autonomy),
          if (showRevocationNote) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: AppColors.textFaint),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can review or revoke this anytime in Consent Manager.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onDecision(false);
                  },
                  child: const Text('Deny'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onDecision(true);
                  },
                  child: const Text('Allow'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 104, child: Text(label, style: const TextStyle(color: AppColors.textFaint, fontSize: 12.5))),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

Future<void> showConsentSheet(
  BuildContext context, {
  required ConsentMandate mandate,
  required ValueChanged<bool> onDecision,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => ConsentSheet(
      agentName: mandate.agentName,
      purpose: mandate.purpose,
      action: mandate.allowedActions.join(', '),
      scope: mandate.dataScope,
      autonomy: mandate.autonomy,
      onDecision: onDecision,
    ),
  );
}

Future<void> showApprovalSheet(
  BuildContext context, {
  required String agentName,
  required String action,
  required String scope,
  required ValueChanged<bool> onDecision,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => ConsentSheet(
      agentName: agentName,
      purpose: 'Approval required — outside current mandate',
      action: action,
      scope: scope,
      autonomy: 'One-time approval',
      showRevocationNote: false,
      onDecision: onDecision,
    ),
  );
}
