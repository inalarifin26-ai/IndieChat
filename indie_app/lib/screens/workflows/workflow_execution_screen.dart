import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../models/workflow_models.dart';
import '../../state/app_state.dart';
import '../../widgets/node_card.dart';
import '../../widgets/wire_painter.dart';
import '../../widgets/consent_sheet.dart';
import 'workflow_builder_screen.dart';

class WorkflowExecutionScreen extends StatefulWidget {
  final String workflowId;
  const WorkflowExecutionScreen({super.key, required this.workflowId});

  @override
  State<WorkflowExecutionScreen> createState() => _WorkflowExecutionScreenState();
}

class _WorkflowExecutionScreenState extends State<WorkflowExecutionScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  static const double _nodeHeight = 76;
  static const double _nodeSpacing = 28;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    context.read<AppState>().ensureWorkflowDetailLoaded(widget.workflowId);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final wf = state.workflows.firstWhere((w) => w.id == widget.workflowId);
    final exec = state.liveExecutionFor(wf.id);
    final pendingApproval = state.approvals.where((a) => a.workflowId == wf.id && !a.resolved).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(wf.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_road_rounded),
            tooltip: 'Open builder',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkflowBuilderScreen(workflowId: wf.id))),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Execution history',
            onPressed: () => _showHistory(context, exec),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!wf.graphLoaded)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                height: wf.nodes.length * (_nodeHeight + _nodeSpacing),
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) => CustomPaint(
                        size: Size.infinite,
                        painter: WirePainter(
                          nodes: wf.nodes,
                          connections: wf.connections,
                          nodeHeight: _nodeHeight,
                          nodeSpacing: _nodeSpacing,
                          pulseValue: _pulse.value,
                        ),
                      ),
                    ),
                    for (int i = 0; i < wf.nodes.length; i++)
                      Positioned(
                        top: i * (_nodeHeight + _nodeSpacing),
                        left: 76,
                        right: 0,
                        child: NodeCard(
                          node: wf.nodes[i],
                          height: _nodeHeight,
                          onTap: wf.nodes[i].state == NodeRuntimeState.waiting
                              ? () => _reviewApproval(context, pendingApproval)
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (pendingApproval.isNotEmpty) _ApprovalBanner(onReview: () => _reviewApproval(context, pendingApproval)),
          _BottomBar(workflow: wf, isRunning: exec != null && exec.state == ExecutionState.running),
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.approval.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.approval.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_clock_rounded, color: AppColors.approval, size: 18),
          const SizedBox(width: 10),
          const Expanded(child: Text('Execution paused — waiting for your approval', style: TextStyle(fontSize: 12.5))),
          TextButton(onPressed: onReview, child: const Text('Review')),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final Workflow workflow;
  final bool isRunning;
  const _BottomBar({required this.workflow, required this.isRunning});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.stroke))),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.read<AppState>().setWorkflowLifecycle(
                      workflow.id,
                      workflow.lifecycle == WorkflowLifecycle.active ? WorkflowLifecycle.paused : WorkflowLifecycle.active,
                    ),
                icon: Icon(workflow.lifecycle == WorkflowLifecycle.active ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 18),
                label: Text(workflow.lifecycle == WorkflowLifecycle.active ? 'Pause automation' : 'Activate'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isRunning
                    ? null
                    : () async {
                        try {
                          await context.read<AppState>().runWorkflow(workflow.id);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start run: $e')));
                          }
                        }
                      },
                icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                label: Text(isRunning ? 'Running…' : 'Run now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
