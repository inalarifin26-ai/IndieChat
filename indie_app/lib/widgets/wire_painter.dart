import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/workflow_models.dart';

/// Paints the connector lines between stacked workflow nodes and, when
/// [pulseValue] is non-null, animates a moving pulse along active edges —
/// the "live wiring visualization" pattern from the spec.
class WirePainter extends CustomPainter {
  final List<WorkflowNode> nodes;
  final List<WorkflowConnection> connections;
  final double nodeHeight;
  final double nodeSpacing;
  final double? pulseValue; // 0..1, null = no animation
  final int? activeNodeIndex;

  WirePainter({
    required this.nodes,
    required this.connections,
    required this.nodeHeight,
    required this.nodeSpacing,
    this.pulseValue,
    this.activeNodeIndex,
  });

  Offset _centerBottom(int index) {
    final y = index * (nodeHeight + nodeSpacing) + nodeHeight;
    return Offset(38, y);
  }

  Offset _centerTop(int index) {
    final y = index * (nodeHeight + nodeSpacing);
    return Offset(38, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final conn in connections) {
      final fromIdx = nodes.indexWhere((n) => n.id == conn.fromNodeId);
      final toIdx = nodes.indexWhere((n) => n.id == conn.toNodeId);
      if (fromIdx == -1 || toIdx == -1) continue;
      final start = _centerBottom(fromIdx);
      final end = _centerTop(toIdx);

      final fromNode = nodes[fromIdx];
      final isDone = fromNode.state == NodeRuntimeState.success;
      final isActive = fromNode.state == NodeRuntimeState.running;

      final basePaint = Paint()
        ..color = isDone
            ? AppColors.success.withOpacity(0.55)
            : AppColors.stroke
        ..strokeWidth = isDone ? 2.4 : 2
        ..style = PaintingStyle.stroke;

      canvas.drawLine(start, end, basePaint);

      if (isActive && pulseValue != null) {
        final t = pulseValue!;
        final pos = Offset.lerp(start, end, t)!;
        final glow = Paint()..color = AppColors.cyan.withOpacity(0.9);
        canvas.drawCircle(pos, 4.2, glow);
        final glowOuter = Paint()..color = AppColors.cyan.withOpacity(0.25);
        canvas.drawCircle(pos, 9, glowOuter);
      }

      if (conn.branchLabel != null) {
        final mid = Offset.lerp(start, end, 0.5)!;
        final tp = TextPainter(
          text: TextSpan(
            text: conn.branchLabel,
            style: const TextStyle(color: AppColors.textFaint, fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(mid.dx + 10, mid.dy - tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant WirePainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue || oldDelegate.nodes != nodes;
  }
}
