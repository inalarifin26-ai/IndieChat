import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../models/workflow_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/consent_sheet.dart';
import 'workflow_builder_screen.dart';

class WorkflowExecutionScreen extends StatefulWidget {
  final String workflowId;
  const WorkflowExecutionScreen({super.key, required this.workflowId});

  @override
  State<WorkflowExecutionScreen> createState() => _WorkflowExecutionScreenState();
}

class _WorkflowExecutionScreenState extends State<WorkflowExecutionScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AppState>().ensureWorkflowDetailLoaded(widget.workflowId);
  }

  /// "HH:mm" of the most recent timeline event "<node title> <suffix>" (started / completed).
  String? _timeFor(WorkflowExecution? exec, WorkflowNode n, String suffix) {
    if (exec == null) return null;
    for (final e in exec.timeline.reversed) {
      if (e.label == '${n.title} $suffix') return DateFormat('HH:mm').format(e.time);
    }
    return null;
  }

  String _liveText(WorkflowNode? n) {
    if (n == null) return 'Ready to run.';
    switch (n.category) {
      case NodeCategory.trigger:
        return 'Parsing your request...';
      case NodeCategory.data:
        return 'Collecting data...';
      case NodeCategory.ai:
        return 'Analyzing performance data...';
      case NodeCategory.output:
        return 'Generating the result...';
      case NodeCategory.approval:
        return 'Waiting for your approval...';
      case NodeCategory.storage:
        return 'Saving to your Vault...';
      case NodeCategory.logic:
        return 'Evaluating the condition...';
      case NodeCategory.action:
        return 'Running the action...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final wf = state.workflows.firstWhere((w) => w.id == widget.workflowId);
    final exec = state.liveExecutionFor(wf.id);
    final pendingApproval = state.approvals.where((a) => a.workflowId == wf.id && !a.resolved).toList();
    final running = exec != null && exec.state == ExecutionState.running;
    final waiting = exec != null && exec.state == ExecutionState.waitingApproval;
    final live = running || waiting;

    final total = wf.nodes.length;
    final done = wf.nodes.where((n) => n.state == NodeRuntimeState.success).length;
    WorkflowNode? current;
    for (final n in wf.nodes) {
      if (n.state == NodeRuntimeState.running || n.state == NodeRuntimeState.waiting) current = n;
    }
    final subtitle = waiting
        ? 'Paused — waiting for your approval'
        : running
            ? 'Running your workflow...'
            : exec == null
                ? wf.name
                : exec.state == ExecutionState.completed
                    ? 'Completed'
                    : exec.state == ExecutionState.cancelled
                        ? 'Cancelled'
                        : wf.name;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('INDIE Flow', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Open builder',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkflowBuilderScreen(workflowId: wf.id))),
          ),
          IconButton(icon: const Icon(Icons.history_rounded), tooltip: 'Execution history', onPressed: () => _showHistory(context, exec)),
        ],
      ),
      body: Column(
        children: [
          if (!wf.graphLoaded)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(22, 10, 22, 16), children: [
                for (var i = 0; i < wf.nodes.length; i++)
                  _StepRow(
                    node: wf.nodes[i],
                    isLast: i == wf.nodes.length - 1,
                    started: _timeFor(exec, wf.nodes[i], 'started'),
                    completed: _timeFor(exec, wf.nodes[i], 'completed'),
                    onTap: wf.nodes[i].state == NodeRuntimeState.waiting ? () => _reviewApproval(context, pendingApproval) : null,
                  ),
                if (pendingApproval.isNotEmpty) _ApprovalBanner(onReview: () => _reviewApproval(context, pendingApproval)),
                const SizedBox(height: 4),
                const Text('Live output', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.stroke)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(current?.title ?? (exec?.state == ExecutionState.completed ? 'Completed' : exec?.state == ExecutionState.cancelled ? 'Cancelled' : 'Ready to run'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    SizedBox(height: 70, width: double.infinity, child: CustomPaint(painter: _SparklinePainter(total == 0 ? 0 : (exec?.state == ExecutionState.completed ? 1.0 : done / total)))),
                    const SizedBox(height: 6),
                    Text(
                      exec?.state == ExecutionState.completed
                          ? 'All steps completed. The result was saved to your Vault.'
                          : exec?.state == ExecutionState.cancelled
                              ? 'This run was cancelled. Nothing was published.'
                              : exec == null
                                  ? 'Tap Run now to start this workflow.'
                                  : _liveText(current),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ]),
                ),
              ]),
            ),
          _BottomBar(workflow: wf, live: live),
        ],
      ),
    );
  }

  void _reviewApproval(BuildContext context, List pendingApproval) {
    if (pendingApproval.isEmpty) return;
    final req = pendingApproval.first;
    showApprovalSheet(
      context,
      agentName: req.agentName,
      action: req.action,
      scope: req.scope,
      onDecision: (ok) => context.read<AppState>().resolveApproval(req.id, ok),
    );
  }

  void _showHistory(BuildContext context, WorkflowExecution? exec) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (context, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Execution timeline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Operational audit trail — never hidden model reasoning.', style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
              const SizedBox(height: 14),
              Expanded(
                child: exec == null
                    ? const Center(child: Text('No execution yet. Tap Run to start.', style: TextStyle(color: AppColors.textFaint)))
                    : ListView.builder(
                        controller: controller,
                        itemCount: exec.timeline.length,
                        itemBuilder: (context, i) {
                          final e = exec.timeline[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Text(DateFormat('HH:mm:ss').format(e.time), style: const TextStyle(color: AppColors.textFaint, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
                                const SizedBox(width: 12),
                                Expanded(child: Text(e.label, style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApprovalBanner extends StatelessWidget {
  final VoidCallback onReview;
  const _ApprovalBanner({required this.onReview});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      padding: const EdgeInsets.fromLTRB(13, 6, 6, 6),
      decoration: BoxDecoration(color: const Color(0xFFF3EEFF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDCCFFF))),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppColors.approval, size: 18),
          const SizedBox(width: 10),
          const Expanded(child: Text('Paused — waiting for your approval', style: TextStyle(fontSize: 12.5))),
          TextButton(onPressed: onReview, child: const Text('Review', style: TextStyle(color: AppColors.approval, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

/// One step of the run: status circle on a vertical timeline, title and status line.
class _StepRow extends StatelessWidget {
  final WorkflowNode node;
  final bool isLast;
  final String? started;
  final String? completed;
  final VoidCallback? onTap;
  const _StepRow({required this.node, required this.isLast, this.started, this.completed, this.onTap});

  @override
  Widget build(BuildContext context) {
    Color fill = Colors.white, border = const Color(0xFFD3D9EA);
    Widget glyph = Icon(node.category.icon, size: 14, color: const Color(0xFFB7BFD6));
    var sub = 'Waiting...';
    var subColor = const Color(0xFFA9B1C9);
    var titleColor = const Color(0xFFA9B1C9);
    List<BoxShadow>? glow;
    switch (node.state) {
      case NodeRuntimeState.success:
        fill = AppColors.success;
        border = AppColors.success;
        glyph = const Icon(Icons.check_rounded, size: 17, color: Colors.white);
        sub = completed == null ? 'Completed' : 'Completed · $completed';
        subColor = AppColors.textSecondary;
        titleColor = AppColors.textPrimary;
        break;
      case NodeRuntimeState.running:
      case NodeRuntimeState.queued:
        fill = AppColors.accent;
        border = AppColors.accent;
        glyph = Icon(node.category.icon, size: 14, color: Colors.white);
        sub = started == null ? 'In progress' : 'In progress · $started';
        subColor = AppColors.accent;
        titleColor = AppColors.textPrimary;
        glow = [BoxShadow(color: AppColors.accent.withOpacity(0.18), spreadRadius: 4)];
        break;
      case NodeRuntimeState.waiting:
        fill = AppColors.approval;
        border = AppColors.approval;
        glyph = const Icon(Icons.lock_outline_rounded, size: 14, color: Colors.white);
        sub = 'Waiting for your approval';
        subColor = AppColors.approval;
        titleColor = AppColors.textPrimary;
        glow = [BoxShadow(color: AppColors.approval.withOpacity(0.18), spreadRadius: 4)];
        break;
      case NodeRuntimeState.error:
        fill = AppColors.danger;
        border = AppColors.danger;
        glyph = const Icon(Icons.close_rounded, size: 16, color: Colors.white);
        sub = 'Failed';
        subColor = AppColors.danger;
        titleColor = AppColors.textPrimary;
        break;
      case NodeRuntimeState.skipped:
      case NodeRuntimeState.cancelled:
        fill = const Color(0xFFF1F3F9);
        sub = node.state == NodeRuntimeState.skipped ? 'Skipped' : 'Cancelled';
        break;
      case NodeRuntimeState.idle:
        break;
    }
    return InkWell(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 30,
            child: Column(children: [
              Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: fill, shape: BoxShape.circle, border: Border.all(color: border, width: 2), boxShadow: glow), child: glyph),
              if (!isLast) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 2), color: node.state == NodeRuntimeState.success ? AppColors.success.withOpacity(0.45) : const Color(0xFFDDE2F0))),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 3),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(node.title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: titleColor)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 12, color: subColor, fontWeight: node.state == NodeRuntimeState.running ? FontWeight.w600 : FontWeight.w400)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// A calm progress sparkline for the live-output card (rises with completed steps).
class _SparklinePainter extends CustomPainter {
  final double progress;
  _SparklinePainter(this.progress);

  static const _pts = [0.0, 0.12, 0.10, 0.30, 0.22, 0.50, 0.42, 0.70, 0.62, 0.90, 0.80, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    final n = (2 + (progress * 10).round()).clamp(2, _pts.length);
    final path = Path();
    for (var i = 0; i < n; i++) {
      final x = size.width * i / (_pts.length - 1);
      final y = size.height - 8 - (size.height - 16) * _pts[i];
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final area = Path.from(path)
      ..lineTo(size.width * (n - 1) / (_pts.length - 1), size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = AppColors.accent.withOpacity(0.10));
    canvas.drawPath(path, Paint()..color = AppColors.accent..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => old.progress != progress;
}

class _BottomBar extends StatelessWidget {
  final Workflow workflow;
  final bool live;
  const _BottomBar({required this.workflow, required this.live});

  @override
  Widget build(BuildContext context) {
    final active = workflow.lifecycle == WorkflowLifecycle.active;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (live)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  try {
                    await context.read<AppState>().cancelWorkflowRun(workflow.id);
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not cancel: $e')));
                  }
                },
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            )
          else
            GradientButton(
              label: context.watch<AppState>().liveExecutionFor(workflow.id) == null ? 'Run now' : 'Run again',
              onPressed: () async {
                try {
                  await context.read<AppState>().runWorkflow(workflow.id);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start run: $e')));
                }
              },
            ),
          TextButton(
            onPressed: () => context.read<AppState>().setWorkflowLifecycle(workflow.id, active ? WorkflowLifecycle.paused : WorkflowLifecycle.active),
            child: Text(active ? 'Pause automation' : 'Activate automation', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
        ]),
      ),
    );
  }
}
