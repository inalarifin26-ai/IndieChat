import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/workflow_models.dart';
import '../../state/app_state.dart';
import '../../widgets/canvas_wire_painter.dart';

const Size kBuilderNodeSize = Size(168, 74);
const Size kBuilderCanvasSize = Size(1400, 1400);

class WorkflowBuilderScreen extends StatefulWidget {
  final String workflowId;
  const WorkflowBuilderScreen({super.key, required this.workflowId});

  @override
  State<WorkflowBuilderScreen> createState() => _WorkflowBuilderScreenState();
}

class _WorkflowBuilderScreenState extends State<WorkflowBuilderScreen> {
  String? _dragFromNodeId;
  Offset? _dragCurrentPoint;
  String? _selectedNodeId;

  Workflow get _wf => context.read<AppState>().workflows.firstWhere((w) => w.id == widget.workflowId);

  @override
  void initState() {
    super.initState();
    context.read<AppState>().ensureWorkflowDetailLoaded(widget.workflowId);
  }

  @override
  Widget build(BuildContext context) {
    // watch so the canvas rebuilds when AppState notifies (add/delete/connect).
    final state = context.watch<AppState>();
    final wf = state.workflows.firstWhere((w) => w.id == widget.workflowId);

    if (!wf.graphLoaded) {
      return Scaffold(
        appBar: AppBar(title: Text('${wf.name} · Builder')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${wf.name} · Builder'),
        actions: [
          IconButton(icon: const Icon(Icons.fact_check_outlined), tooltip: 'Validate', onPressed: () => _runValidate(context)),
          IconButton(icon: const Icon(Icons.add_box_outlined), tooltip: 'Add node', onPressed: () => _openPalette(context)),
        ],
      ),
      body: Stack(
        children: [
          InteractiveViewer(
            constrained: false,
            minScale: 0.5,
            maxScale: 1.8,
            boundaryMargin: const EdgeInsets.all(400),
            child: SizedBox(
              width: kBuilderCanvasSize.width,
              height: kBuilderCanvasSize.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: CanvasWirePainter(
                        nodes: wf.nodes,
                        connections: wf.connections,
                        nodeSize: kBuilderNodeSize,
                        dragFrom: _dragFromNodeId == null
                            ? null
                            : Offset(
                                wf.nodes.firstWhere((n) => n.id == _dragFromNodeId).position.dx + kBuilderNodeSize.width / 2,
                                wf.nodes.firstWhere((n) => n.id == _dragFromNodeId).position.dy + kBuilderNodeSize.height,
                              ),
                        dragTo: _dragCurrentPoint,
                      ),
                    ),
                  ),
                  for (final node in wf.nodes)
                    Positioned(
                      left: node.position.dx,
                      top: node.position.dy,
                      child: _CanvasNode(
                        node: node,
                        selected: _selectedNodeId == node.id,
                        onMove: (delta) => setState(() => node.position += delta),
                        onMoveEnd: () => context.read<AppState>().commitNodeMove(widget.workflowId, node.id),
                        onTap: () => _openConfig(context, node),
                        onHandleStart: () => setState(() => _dragFromNodeId = node.id),
                        onHandleUpdate: (delta) => setState(() {
                          _dragCurrentPoint = (_dragCurrentPoint ??
                                  Offset(node.position.dx + kBuilderNodeSize.width / 2, node.position.dy + kBuilderNodeSize.height)) +
                              delta;
                        }),
                        onHandleEnd: () => _finishConnection(context, wf),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _Toolbar(workflow: wf),
          ),
        ],
      ),
    );
  }

  void _finishConnection(BuildContext context, Workflow wf) async {
    if (_dragFromNodeId != null && _dragCurrentPoint != null) {
      WorkflowNode? target;
      for (final n in wf.nodes) {
        if (n.id == _dragFromNodeId) continue;
        final rect = Rect.fromLTWH(n.position.dx, n.position.dy, kBuilderNodeSize.width, kBuilderNodeSize.height);
        if (rect.contains(_dragCurrentPoint!)) {
          target = n;
          break;
        }
      }
      if (target != null) {
        final ok = await context.read<AppState>().addConnection(widget.workflowId, _dragFromNodeId!, target.id);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection already exists'), duration: Duration(seconds: 1)));
        }
      }
    }
    setState(() {
      _dragFromNodeId = null;
      _dragCurrentPoint = null;
    });
  }

  void _runValidate(BuildContext context) async {
    List<String> issues;
    try {
      issues = await context.read<AppState>().validateWorkflow(widget.workflowId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not validate: $e')));
      return;
    }
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: Text(issues.isEmpty ? 'Looks good' : 'Validation issues'),
        content: SizedBox(
          width: 300,
          child: issues.isEmpty
              ? const Text('Every node is reachable from the trigger. Ready to test or activate.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: issues.map((e) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('•  $e'))).toList(),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  void _openPalette(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: NodeCategory.values
              .map((cat) => ListTile(
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: cat.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: Icon(cat.icon, color: cat.color, size: 18),
                    ),
                    title: Text(cat.label),
                    onTap: () {
                      Navigator.of(context).pop();
                      final wf = _wf;
                      double maxY = 0;
                      for (final n in wf.nodes) {
                        if (n.position.dy > maxY) maxY = n.position.dy;
                      }
                      context.read<AppState>().addNode(widget.workflowId, cat, Offset(40, maxY + 110));
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _openConfig(BuildContext context, WorkflowNode node) {
    setState(() => _selectedNodeId = node.id);
    final titleCtl = TextEditingController(text: node.title);
    final subtitleCtl = TextEditingController(text: node.subtitle);
    Map<String, dynamic>? condition = node.condition;
    var conditionTouched = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: node.category.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(node.category.icon, color: node.category.color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(node.category.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(controller: titleCtl, decoration: const InputDecoration(labelText: 'Node name')),
            const SizedBox(height: 12),
            TextField(controller: subtitleCtl, decoration: const InputDecoration(labelText: 'Description')),
            if (node.category == NodeCategory.logic) ...[
              const SizedBox(height: 16),
              const Text('Branch condition', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 4),
              const Text('How this node chooses between its labelled branches.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              _ConditionEditor(
                initial: node.condition,
                onChanged: (c) {
                  condition = c;
                  conditionTouched = true;
                },
              ),
            ],
            if (node.permissionRequirements.isNotEmpty) [
              const SizedBox(height: 14),
              const Text('Permission requirements', style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: node.permissionRequirements.map((p) => Chip(label: Text(p), visualDensity: VisualDensity.compact)).toList(),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.read<AppState>().duplicateNode(widget.workflowId, node.id);
                      Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Duplicate'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.read<AppState>().deleteNode(widget.workflowId, node.id);
                      Navigator.of(ctx).pop();
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.read<AppState>().updateNodeConfig(
                        widget.workflowId,
                        node.id,
                        title: titleCtl.text,
                        subtitle: subtitleCtl.text,
                        condition: conditionTouched ? condition : null,
                        clearCondition: conditionTouched && condition == null,
                      );
                  Navigator.of(ctx).pop();
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() => setState(() => _selectedNodeId = null));
  }
}

class _CanvasNode extends StatelessWidget {
  final WorkflowNode node;
  final bool selected;
  final ValueChanged<Offset> onMove;
  final VoidCallback onMoveEnd;
  final VoidCallback onTap;
  final VoidCallback onHandleStart;
  final ValueChanged<Offset> onHandleUpdate;
  final VoidCallback onHandleEnd;

  const _CanvasNode({
    required this.node,
    required this.selected,
    required this.onMove,
    required this.onMoveEnd,
    required this.onTap,
    required this.onHandleStart,
    required this.onHandleUpdate,
    required this.onHandleEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kBuilderNodeSize.width,
      height: kBuilderNodeSize.height + 16, // extra room for the handle
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onTap,
            onPanUpdate: (d) => onMove(d.delta),
            onPanEnd: (_) => onMoveEnd(),
            child: Container(
              width: kBuilderNodeSize.width,
              height: kBuilderNodeSize.height,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: selected ? AppColors.accent : AppColors.stroke, width: selected ? 1.6 : 1),
                boxShadow: node.disabled ? null : [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Opacity(
                opacity: node.disabled ? 0.45 : 1,
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: node.category.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: Icon(node.category.icon, color: node.category.color, size: 17),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(node.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          Text(node.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.textFaint)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -2,
            left: kBuilderNodeSize.width / 2 - 10,
            child: GestureDetector(
              onPanStart: (_) => onHandleStart(),
              onPanUpdate: (d) => onHandleUpdate(d.delta),
              onPanEnd: (_) => onHandleEnd(),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent, width: 2),
                ),
                child: const Icon(Icons.add_rounded, size: 12, color: AppColors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final Workflow workflow;
  const _Toolbar({required this.workflow});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 16)],
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, size: 15, color: AppColors.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(workflow.triggerSummary, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ),
          Text('Autosaved', style: const TextStyle(fontSize: 10.5, color: AppColors.textFaint)),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () => context.read<AppState>().setWorkflowLifecycle(
                  workflow.id,
                  workflow.lifecycle == WorkflowLifecycle.active ? WorkflowLifecycle.paused : WorkflowLifecycle.active,
                ),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
            child: Text(workflow.lifecycle == WorkflowLifecycle.active ? 'Pause' : 'Activate', style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

/// Picks how a logic node chooses its branch. Mirrors the server's chooseBranch():
/// none = alphabetical default, always = one fixed branch, probability = that
/// branch X% of the time, random = uniform among all labelled branches.
class _ConditionEditor extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final ValueChanged<Map<String, dynamic>?> onChanged;
  const _ConditionEditor({required this.initial, required this.onChanged});

  @override
  State<_ConditionEditor> createState() => _ConditionEditorState();
}

class _ConditionEditorState extends State<_ConditionEditor> {
  late String _type = (widget.initial?['type'] as String?) ?? 'none';
  late final TextEditingController _branch = TextEditingController(text: (widget.initial?['branch'] as String?) ?? 'Yes');
  late final TextEditingController _percent = TextEditingController(text: '${(widget.initial?['percent'] as num?)?.toInt() ?? 50}');

  @override
  void dispose() {
    _branch.dispose();
    _percent.dispose();
    super.dispose();
  }

  void _emit() {
    if (_type == 'none') {
      widget.onChanged(null);
    } else if (_type == 'random') {
      widget.onChanged({'type': 'random'});
    } else {
      final pct = (int.tryParse(_percent.text.trim()) ?? 50).clamp(0, 100);
      widget.onChanged({'type': _type, 'branch': _branch.text.trim(), if (_type == 'probability') 'percent': pct});
    }
  }

  @override
  Widget build(BuildContext context) {
    const labels = {'none': 'Alphabetical (default)', 'always': 'Always', 'probability': 'Probability', 'random': 'Random'};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final e in labels.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: _type == e.key,
            onSelected: (_) {
              setState(() => _type = e.key);
              _emit();
            },
          ),
      ]),
      if (_type == 'always' || _type == 'probability') ...[
        const SizedBox(height: 10),
        TextField(controller: _branch, onChanged: (_) => _emit(), decoration: const InputDecoration(labelText: 'Branch label (e.g. Yes)')),
      ],
      if (_type == 'probability') ...[
        const SizedBox(height: 10),
        TextField(controller: _percent, keyboardType: TextInputType.number, onChanged: (_) => _emit(), decoration: const InputDecoration(labelText: 'Chance of that branch (0–100 %)')),
      ],
    ]);
  }
}
