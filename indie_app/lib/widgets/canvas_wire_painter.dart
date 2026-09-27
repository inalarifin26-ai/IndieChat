import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/workflow_models.dart';

/// Draws curved connector lines between freely-positioned nodes on the
/// Workflow Builder canvas, plus an optional in-progress connection line
/// while the user is dragging from a node's output handle.
class CanvasWirePainter extends CustomPainter {
  final List<WorkflowNode> nodes;
  final List<WorkflowConnection> connections;
  final Size nodeSize;
  final Offset? dragFrom;
  final Offset? dragTo;

  CanvasWirePainter({
    required this.nodes,
    required this.connections,
    required this.nodeSize,
    this.dragFrom,
    this.dragTo,
  });

  Offset _outAnchor(WorkflowNode n) => Offset(n.position.dx + nodeSize.width / 2, n.position.dy + nodeSize.height);
  Offset _inAnchor(WorkflowNode n) => Offset(n.position.dx + nodeSize.width / 2, n.position.dy);

  void _curve(Canvas canvas, Offset a, Offset b, Paint paint) {
    final path = Path()..moveTo(a.dx, a.dy);
    final mid = (a.dy + b.dy) / 2;
    path.cubicTo(a.dx, mid, b.dx, mid, b.dx, b.dy);
    canvas.drawPath(path, paint);
    // small arrowhead pointing into the target anchor
    final arrow = Path()
      ..moveTo(b.dx - 5, b.dy - 7)
      ..lineTo(b.dx, b.dy)
      ..lineTo(b.dx + 5, b.dy - 7);
    canvas.drawPath(arrow, Paint()
      ..color = paint.color
      ..strokeWidth = paint.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in connections) {
      final from = nodes.where((n) => n.id == c.fromNodeId);
      final to = nodes.where((n) => n.id == c.toNodeId);
      if (from.isEmpty || to.isEmpty) continue;
      final a = _outAnchor(from.first);
      final b = _inAnchor(to.first);
      final done = from.first.state == NodeRuntimeState.success;
      final paint = Paint()
        ..color = done ? AppColors.success.withOpacity(0.55) : AppColors.stroke
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      _curve(canvas, a, b, paint);
    }

    if (dragFrom != null && dragTo != null) {
      final paint = Paint()
        ..color = AppColors.cyan.withOpacity(0.8)
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke;
      _curve(canvas, dragFrom!, dragTo!, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CanvasWirePainter oldDelegate) => true;
}
