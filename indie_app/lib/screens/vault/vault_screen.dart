import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../models/consent_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'output_viewer_screen.dart';

/// My Vault — Files (results), Notes and Memories. Private to you; only a
/// result can ever be shared out of here, never a workflow.
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  int _tab = 0; // Files, Notes, Memories

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    Future.microtask(() async {
      try {
        await s.loadNotes();
        await s.loadMemories();
      } catch (_) {
        // The Files tab works without them; the other tabs show an empty state.
      }
    });
  }

  /// Colour + glyph per kind — reports read as PDFs (red), documents blue, etc.
  (Color, IconData) _style(OutputKind k) {
    switch (k) {
      case OutputKind.report:
        return (const Color(0xFFEF4444), Icons.description_outlined);
      case OutputKind.document:
        return (const Color(0xFF3B82F6), Icons.article_outlined);
      case OutputKind.message:
        return (const Color(0xFF60A5FA), Icons.sticky_note_2_outlined);
      case OutputKind.spreadsheet:
        return (const Color(0xFF22C55E), Icons.table_chart_outlined);
      case OutputKind.image:
        return (const Color(0xFF22C55E), Icons.image_outlined);
      case OutputKind.dashboard:
        return (const Color(0xFF8B5CF6), Icons.space_dashboard_outlined);
      case OutputKind.data:
        return (const Color(0xFF3B82F6), Icons.dataset_outlined);
    }
  }

  String _when(DateTime t) {
    final label = dayLabel(t);
    return (label == 'Today' || label == 'Yesterday') ? '$label, ${DateFormat('HH:mm').format(t)}' : '${DateTime.now().difference(t).inDays} days ago';
  }

  Future<void> _addNote() async {
    final title = TextEditingController();
    final body = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('New note', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: 'Note')),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel'))),
            const SizedBox(width: 10),
            Expanded(
              child: GradientButton(
                label: 'Save',
                onPressed: () async {
                  if (title.text.trim().isEmpty) return;
                  try {
                    await context.read<AppState>().addNote(title.text.trim(), body.text.trim());
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Could not save: $e')));
                  }
                },
              ),
            ),
          ]),
        ]),
      ),
    );
    title.dispose();
    body.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final children = <Widget>[];

    if (_tab == 0) {
      for (final o in state.outputs) {
        final (color, icon) = _style(o.kind);
        children.add(InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OutputViewerScreen(outputId: o.id))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: Colors.white, size: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${o.kind.name[0].toUpperCase()}${o.kind.name.substring(1)} · ${_when(o.createdAt)}${o.shared ? ' · shared' : ''}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
            ]),
          ),
        ));
      }
      if (state.outputs.isEmpty) children.add(const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text('No results yet. Run a workflow or ask the Orchestrator.', style: TextStyle(color: AppColors.textFaint)))));
    } else if (_tab == 1) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
        child: Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _addNote, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add note'))),
      ));
      for (final n in state.notes) {
        children.add(ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
          leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF60A5FA), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.sticky_note_2_outlined, color: Colors.white, size: 20)),
          title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          subtitle: n.body.isEmpty ? null : Text(n.body, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 19), onPressed: () => context.read<AppState>().deleteNote(n.id)),
        ));
      }
      if (state.notes.isEmpty) children.add(const Padding(padding: EdgeInsets.only(top: 30), child: Center(child: Text('No notes yet.', style: TextStyle(color: AppColors.textFaint)))));
    } else {
      for (final m in state.memories) {
        final agent = state.agents.where((a) => a.id == m.agentId);
        children.add(ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
          leading: agent.isNotEmpty ? AgentAvatar(agent: agent.first, size: 36) : const GroupAvatar(size: 36),
          title: Text(m.note, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(m.agentName),
        ));
      }
      if (state.memories.isEmpty) children.add(const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text('Agents have not noted anything yet.', style: TextStyle(color: AppColors.textFaint)))));
    }

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          PageHeader(title: 'My Vault', actions: [
            IconButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Everything here is private to you'))), icon: const Icon(Icons.verified_user_outlined)),
          ]),
          FilterChips(labels: const ['Files', 'Notes', 'Memories'], selected: _tab, onSelected: (i) => setState(() => _tab = i)),
          Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 24), children: children)),
        ]),
      ),
    );
  }
}
