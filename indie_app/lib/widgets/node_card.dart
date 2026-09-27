import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/workflow_models.dart';

class NodeCard extends StatelessWidget {
  final WorkflowNode node;
  final double height;
  final VoidCallback? onTap;

  const NodeCard({super.key, required this.node, this.height = 76, this.onTap});

  Color get _stateColor {
    switch (node.state) {
      case NodeRuntimeState.success:
        return AppColors.success;
      case NodeRuntimeState.running:
        return AppColors.cyan;
      case NodeRuntimeState.waiting:
        return AppColors.approval;
      case NodeRuntimeState.error:
        return AppColors.danger;
      case NodeRuntimeState.skipped:
      case NodeRuntimeState.cancelled:
        return AppColors.textFaint;
      case NodeRuntimeState.idle:
      case NodeRuntimeState.queued:
        return AppColors.stroke;
    }
  }

  Widget get _stateBadge {
    switch (node.state) {
      case NodeRuntimeState.success:
        return const Icon(Icons.check_rounded, size: 14, color: AppColors.success);
      case NodeRuntimeState.running:
        return const SizedBox(
          width: 13,
          height: 13,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan),
        );
      case NodeRuntimeState.waiting:
        return const Icon(Icons.lock_clock_rounded, size: 14, color: AppColors.approval);
      case NodeRuntimeState.error:
        return const Icon(Icons.error_rounded, size: 14, color: AppColors.danger);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final glow = node.state == NodeRuntimeState.running || node.state == NodeRuntimeState.waiting;
    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _stateColor.withOpacity(glow ? 0.7 : 0.5), width: glow ? 1.4 : 1),
              boxShadow: glow
                  ? [BoxShadow(color: _stateColor.withOpacity(0.25), blurRadius: 16, spreadRadius: 1)]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: node.category.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(node.category.icon, color: node.category.color, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(node.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5)),
                          ),
                          _stateBadge,
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(node.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
