import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/workflow_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'workflow_builder_screen.dart';
import 'workflow_execution_screen.dart';

class WorkflowsListScreen extends StatelessWidget {
  const WorkflowsListScreen({super.key});

  String _lifecycleLabel(WorkflowLifecycle l) {
    switch (l) {
      case WorkflowLifecycle.draft:
        return 'Draft';
      case WorkflowLifecycle.validating:
        return 'Validating';
      case WorkflowLifecycle.ready:
        return 'Ready';
      case WorkflowLifecycle.active:
        return 'Active';
      case WorkflowLifecycle.paused:
        return 'Paused';
    }
  }

  Color _lifecycleColor(WorkflowLifecycle l) {
    switch (l) {
      case WorkflowLifecycle.active:
        return AppColors.success;
      case WorkflowLifecycle.paused:
        return AppColors.warning;
      case WorkflowLifecycle.draft:
        return AppColors.textFaint;
      default:
        return AppColors.cyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workflows'),
        actions: [
          IconButton(
            tooltip: 'New workflow',
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final wf = await context.read<AppState>().createDraftWorkflow();
              if (context.mounted) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkflowBuilderScreen(workflowId: wf.id)));
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const Text(
            'Personal automations. Private to you — only outputs can ever be shared.',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          ...state.workflows.map((wf) => _WorkflowTile(
                workflow: wf,
                lifecycleLabel: _lifecycleLabel(wf.lifecycle),
                lifecycleColor: _lifecycleColor(wf.lifecycle),
              )),
        ],
      ),
    );
  }
}

class _WorkflowTile extends StatelessWidget {
  final Workflow workflow;
  final String lifecycleLabel;
  final Color lifecycleColor;
  const _WorkflowTile({required this.workflow, required this.lifecycleLabel, required this.lifecycleColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkflowExecutionScreen(workflowId: workflow.id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(workflow.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                  StatusPill(label: lifecycleLabel, color: lifecycleColor),
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkflowBuilderScreen(workflowId: workflow.id))),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.edit_road_rounded, size: 18, color: AppColors.textFaint),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(workflow.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, size: 14, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(workflow.triggerSummary, style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
                  const SizedBox(width: 14),
                  const Icon(Icons.account_tree_outlined, size: 14, color: AppColors.textFaint),
                  const SizedBox(width: 4),
                  Text('${workflow.nodes.length} nodes', style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
                  const Spacer(),
                  Text(workflow.version, style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
