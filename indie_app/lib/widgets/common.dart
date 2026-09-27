import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/agent_models.dart';

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                )),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Distinct, non-generic avatar for an autonomous Agent — a soft gradient
/// glyph tile rather than a robot icon or a human photo placeholder.
class AgentAvatar extends StatelessWidget {
  final Agent agent;
  final double size;
  const AgentAvatar({super.key, required this.agent, this.size = 48});

  Color get _accent => Color(int.parse('FF${agent.accentHex}', radix: 16));

  @override
  Widget build(BuildContext context) {
    final busy = agent.state == AgentActivityState.working || agent.state == AgentActivityState.monitoring;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.32),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_accent.withOpacity(0.9), AppColors.violet.withOpacity(0.85)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              agent.glyph,
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (agent.needsAttention)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: size * 0.26,
                height: size * 0.26,
                decoration: BoxDecoration(
                  color: AppColors.approval,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
              ),
            )
          else if (busy)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: size * 0.24,
                height: size * 0.24,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ContactAvatar extends StatelessWidget {
  final String initials;
  final double size;
  const ContactAvatar({super.key, required this.initials, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.stroke),
      ),
      child: Text(initials, style: TextStyle(fontSize: size * 0.34, fontWeight: FontWeight.w700, color: AppColors.contactAccent)),
    );
  }
}

String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${diff.inDays}d';
}
