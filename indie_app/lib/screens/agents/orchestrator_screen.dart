import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../models/agent_models.dart';
import '../../models/orchestrator_models.dart';
import '../../state/app_state.dart';
import '../../widgets/indie_logo.dart';
import '../../widgets/message_bubble.dart';
import 'agent_chat_screen.dart';

/// The Orchestrator: the only place agents get created. Give it an
/// instruction ("create an agent to…", "plan a trip to…", "update workflow
/// of X: …") and it replies in this thread, spinning up agents and a real
/// workflow behind the scenes.
class OrchestratorScreen extends StatefulWidget {
  final String? prefill;
  const OrchestratorScreen({super.key, this.prefill});

  @override
  State<OrchestratorScreen> createState() => _OrchestratorScreenState();
}

class _OrchestratorScreenState extends State<OrchestratorScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    if (widget.prefill != null) _controller.text = widget.prefill!;
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    if (!state.orchLoaded) await state.loadOrchestrator();
    _jumpToEndSoon();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _jumpToEndSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _send([String? text]) async {
    final t = (text ?? _controller.text).trim();
    if (t.isEmpty) return;
    _controller.clear();
    final state = context.read<AppState>();
    try {
      await state.sendOrchestrator(t);
      _jumpToEndSoon();
      _startPolling();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.statusCode == 409 ? 'Orchestrator is still working…' : 'Error: ${e.message}')));
    }
  }

  void _startPolling() {
    _poll?.cancel();
    var ticks = 0;
    _poll = Timer.periodic(const Duration(milliseconds: 700), (timer) async {
      final state = context.read<AppState>();
      await state.refreshOrchestrator();
      _jumpToEndSoon();
      ticks++;
      // Task orchestrations can take a few seconds (one tick per agent); a
      // generous cap avoids polling forever if something goes wrong.
      if (!state.orchWaiting || ticks > 20) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 4),
            const IndieMark(size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('Orchestrator', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  Text('Creates agents & defines their workflows', style: TextStyle(fontSize: 11, color: AppColors.textFaint)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: !state.orchLoaded
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(14),
                    itemCount: state.orchMessages.length + (state.orchWaiting ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= state.orchMessages.length) return const Padding(padding: EdgeInsets.only(bottom: 8), child: TypingBubble());
                      final m = state.orchMessages[i];
                      return Padding(padding: const EdgeInsets.only(bottom: 4), child: _OrchBubble(message: m));
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.stroke))),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(fontSize: 14.5),
                      decoration: const InputDecoration(hintText: 'Give an instruction or create an agent…', isDense: true),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _send(),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(color: AppColors.indigo, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrchBubble extends StatelessWidget {
  final OrchMessage message;
  const _OrchBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.indigo, borderRadius: BorderRadius.circular(16)),
              child: Text(m.text, style: const TextStyle(color: Colors.white, fontSize: 14.5)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(fmtTime(m.createdAt), style: const TextStyle(color: AppColors.textFaint, fontSize: 10.5)),
                const SizedBox(width: 4),
                const Icon(Icons.done_all_rounded, size: 13, color: AppColors.cyan),
              ]),
            ),
          ],
        ),
      );
    }
    if (m.sender == 'agent') return _AgentResultRow(message: m);
    return _OrchCard(message: m);
  }
}

class _OrchTag extends StatelessWidget {
  final DateTime time;
  const _OrchTag({required this.time});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const IndieMark(size: 16),
      const SizedBox(width: 6),
      const Text('ORCHESTRATOR', style: TextStyle(color: AppColors.cyan, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
      const Spacer(),
      Text(fmtTime(time), style: const TextStyle(color: AppColors.textFaint, fontSize: 10.5)),
    ]);
  }
}

class _OrchCard extends StatelessWidget {
  final OrchMessage message;
  const _OrchCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final m = message;
    final p = m.payload ?? const {};
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
        padding: const EdgeInsets.all(13),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.stroke)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _OrchTag(time: m.createdAt),
            const SizedBox(height: 8),
            Text(m.text, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            if (m.kind == OrchKind.welcome) ...[
              const SizedBox(height: 8),
              const Text('Tell me:', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              const _Bullets(['Create an agent — I set up its workflow', 'Give a task — I pick or create the agents and run them', 'Update workflow of <agent>: … — I change its scope']),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ((p['suggestions'] as List?) ?? []).map<Widget>((s) => _SuggestionChip(text: s.toString())).toList(),
              ),
            ],
            if (m.kind == OrchKind.plan) ...[
              const SizedBox(height: 8),
              _Bullets(((p['agents'] as List?) ?? []).map((a) => '${a['name']} → ${a['firstStep']}').toList().cast<String>()),
              if (((p['created'] as List?) ?? []).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('＋ Created ${(p['created'] as List).length} new agent(s): ${(p['created'] as List).join(', ')}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.cyan)),
              ],
            ],
            if (m.kind == OrchKind.agentCreated || m.kind == OrchKind.workflowUpdated) ...[
              const SizedBox(height: 8),
              _Bullets(((p['workflow'] as List?) ?? []).cast<dynamic>().map((e) => e.toString()).toList()),
              const SizedBox(height: 10),
              _ChatWithButton(agentId: p['agentId'] as String?, name: p['name']?.toString() ?? 'agent'),
            ],
            if (m.kind == OrchKind.result) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: ((p['rows'] as List?) ?? [])
                      .map<Widget>((r) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              Expanded(child: Text(r['agent'].toString(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
                              Flexible(child: Text(r['result'].toString(), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
                            ]),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: m.saved
                        ? null
                        : () async {
                            try {
                              await context.read<AppState>().saveOrchestratorResult(m.id);
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Vault'), duration: Duration(seconds: 1)));
                            } catch (e) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                            }
                          },
                    child: Text(m.saved ? 'Saved ✓' : 'Save to Vault'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open the result from the Vault tab to share it'), duration: Duration(seconds: 2))),
                    child: const Text('Share'),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              const Text('Chat directly with an agent — it only works inside its workflow:', style: TextStyle(fontSize: 11, color: AppColors.textFaint)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ((p['agentIds'] as List?) ?? []).map<Widget>((id) => _ChatChip(agentId: id as String)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AgentResultRow extends StatelessWidget {
  final OrchMessage message;
  const _AgentResultRow({required this.message});

  @override
  Widget build(BuildContext context) {
    final agents = context.watch<AppState>().agents;
    final agent = agents.where((a) => a.id == message.agentId);
    final a = agent.isNotEmpty ? agent.first : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AgentAvatarDot(color: a != null ? Color(int.parse('FF${a.accentHex}', radix: 16)) : AppColors.textFaint, glyph: a?.glyph ?? '?'),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14).copyWith(topLeft: const Radius.circular(4)),
                border: Border.all(color: AppColors.stroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(a?.name ?? 'Agent', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(message.text, style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AgentAvatarDot extends StatelessWidget {
  final Color color;
  final String glyph;
  const AgentAvatarDot({super.key, required this.color, required this.glyph});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
      child: Text(glyph, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
    );
  }
}

class _Bullets extends StatelessWidget {
  final List<String> items;
  const _Bullets(this.items);
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('•  $s', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ))
          .toList(),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  const _SuggestionChip({required this.text});
  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 11.5)),
      onPressed: () => context.findAncestorStateOfType<_OrchestratorScreenState>()?._send(text),
    );
  }
}

class _ChatWithButton extends StatelessWidget {
  final String? agentId;
  final String name;
  const _ChatWithButton({required this.agentId, required this.name});
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: agentId == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AgentChatScreen(agentId: agentId!))),
      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
      label: Text('Chat with $name'),
    );
  }
}

class _ChatChip extends StatelessWidget {
  final String agentId;
  const _ChatChip({required this.agentId});
  @override
  Widget build(BuildContext context) {
    final agents = context.watch<AppState>().agents;
    final a = agents.where((x) => x.id == agentId);
    final name = a.isNotEmpty ? a.first.name : 'Agent';
    return ActionChip(
      avatar: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
      label: Text(name, style: const TextStyle(fontSize: 11.5)),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AgentChatScreen(agentId: agentId))),
    );
  }
}
