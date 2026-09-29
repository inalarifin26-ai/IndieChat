import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/format.dart';
import '../models/chat_models.dart';

/// Renders one message in a chat room: text/file/output/card body, an
/// optional reply quote, reactions, and (for messages the user sent in a
/// contact chat) delivery ticks. Tap opens the action sheet via [onOpen];
/// tap on a quote jumps to the original via [onJumpTo].
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showTicks;
  final VoidCallback? onOpen;
  final VoidCallback? onOutputTap;
  final ValueChanged<String>? onJumpTo;
  final ValueChanged<String>? onReact;

  const MessageBubble({
    super.key,
    required this.message,
    this.showTicks = false,
    this.onOpen,
    this.onOutputTap,
    this.onJumpTo,
    this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m.sender == SenderKind.system) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(12)),
          child: Text(m.text, style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5), textAlign: TextAlign.center),
        ),
      );
    }

    final mine = m.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: m.deleted ? null : onOpen,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
              child: _body(context, mine),
            ),
          ),
          if (!m.deleted && m.reactions.isNotEmpty) _reactions(),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(fmtTime(m.timestamp), style: const TextStyle(color: AppColors.textFaint, fontSize: 10.5)),
                if (mine && showTicks && m.status != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    m.status == 'sent' ? Icons.done_rounded : Icons.done_all_rounded,
                    size: 13,
                    color: m.status == 'read' ? AppColors.cyan : AppColors.textFaint,
                  ),
                ],
              ],
            ),
          ),
          if (!m.deleted && m.kind == MessageKind.text && m.payload?['cta'] == true)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ActionChip(
                label: const Text('Ask Orchestrator to change my workflow'),
                labelStyle: const TextStyle(fontSize: 11.5),
                onPressed: onOutputTap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _quote(bool mine) {
    if (m.replyTo == null) return const SizedBox.shrink();
    final r = m.replyTo!;
    return GestureDetector(
      onTap: () => onJumpTo?.call(r.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: mine ? Colors.black.withOpacity(0.18) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: mine ? Colors.white : AppColors.cyan, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(r.sender == SenderKind.user ? 'You' : (r.sender == SenderKind.agent ? 'Agent' : 'Contact'),
                style: TextStyle(color: mine ? Colors.white : AppColors.cyan, fontSize: 10.5, fontWeight: FontWeight.w700)),
            Text(r.snippet, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  ChatMessage get m => message;

  Widget _body(BuildContext context, bool mine) {
    if (m.deleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(16)),
        child: const Text('🚫 Message deleted', style: TextStyle(color: AppColors.textFaint, fontStyle: FontStyle.italic, fontSize: 13)),
      );
    }
    switch (m.kind) {
      case MessageKind.file:
        final f = m.payload?['file'] as Map<String, dynamic>?;
        return _bubbleShell(
          mine,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.description_rounded, color: AppColors.danger, size: 18),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(f?['name']?.toString() ?? 'File', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    Text(f?['size']?.toString() ?? '', style: const TextStyle(fontSize: 10.5, color: AppColors.textFaint)),
                  ],
                ),
              ),
            ],
          ),
          quote: _quote(mine),
        );
      case MessageKind.output:
        final o = m.payload?['output'] as Map<String, dynamic>?;
        return _resultCard(
          title: '📄 ${o?['title'] ?? 'Result'}',
          note: o?['note']?.toString(),
          quote: _quote(mine),
          onView: onOutputTap,
        );
      case MessageKind.card:
        final c = m.payload?['card'] as Map<String, dynamic>?;
        return _resultCard(
          title: c?['title']?.toString() ?? 'Result',
          metrics: (c?['metrics'] as List?)?.cast<List>(),
          insights: (c?['insights'] as List?)?.cast<dynamic>(),
          saved: m.saved,
          quote: _quote(mine),
        );
      default:
        return _bubbleShell(mine, Text(m.text, style: TextStyle(color: mine ? Colors.white : AppColors.textPrimary, fontSize: 14.5)), quote: _quote(mine));
    }
  }

  Widget _bubbleShell(bool mine, Widget child, {Widget? quote}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? AppColors.indigo : AppColors.surfaceCard,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [if (quote != null) quote, child]),
    );
  }

  Widget _resultCard({required String title, String? note, List<List>? metrics, List? insights, bool saved = false, Widget? quote, VoidCallback? onView}) {
    return Container(
      padding: const EdgeInsets.all(13),
      constraints: const BoxConstraints(minWidth: 220),
      decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.stroke)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (quote != null) quote,
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          if (note != null) ...[const SizedBox(height: 4), Text(note, style: const TextStyle(fontSize: 11, color: AppColors.textFaint))],
          if (metrics != null) ...[
            const SizedBox(height: 9),
            Row(
              children: metrics
                  .map((row) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(row[0].toString(), style: const TextStyle(fontSize: 10, color: AppColors.textFaint)),
                              Row(children: [
                                Text(row[1].toString(), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                                if (row.length > 2 && row[2].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text(row[2].toString(), style: const TextStyle(fontSize: 10.5, color: AppColors.success)),
                                  ),
                              ]),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (insights != null) ...[
            const SizedBox(height: 9),
            ...insights.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('•  $i', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                )),
          ],
          const SizedBox(height: 9),
          Row(
            children: [
              if (onView != null)
                Expanded(child: OutlinedButton(onPressed: onView, style: _smallBtn, child: const Text('View full report'))),
              if (onView != null) const SizedBox(width: 8),
              if (metrics != null || insights != null)
                Expanded(
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10), textStyle: const TextStyle(fontSize: 11.5)),
                    child: Text(saved ? 'Saved ✓' : 'Save to Vault'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static final _smallBtn = OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10), textStyle: const TextStyle(fontSize: 11.5));

  Widget _reactions() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        children: m.reactions.entries.map((e) {
          final mine = m.myReaction == e.key;
          return GestureDetector(
            onTap: () => onReact?.call(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: mine ? AppColors.cyan : AppColors.stroke),
              ),
              child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 11.5)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class TypingBubble extends StatelessWidget {
  const TypingBubble({super.key});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(16)),
        child: const SizedBox(width: 28, height: 10, child: _Dots()),
      ),
    );
  }
}

class _Dots extends StatefulWidget {
  const _Dots();
  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(3, (i) {
          final t = (c.value - i * 0.2) % 1.0;
          final o = (t < 0.4) ? (0.3 + 0.7 * (t / 0.4)) : 0.3;
          return Opacity(opacity: o.clamp(0.3, 1.0), child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.textFaint, shape: BoxShape.circle)));
        }),
      ),
    );
  }
}

class DateSeparator extends StatelessWidget {
  final String label;
  const DateSeparator({super.key, required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
          decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(10)),
          child: Text(label, style: const TextStyle(color: AppColors.textFaint, fontSize: 10.5, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
