import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/agent_models.dart';

// ───────────────────────── small primitives ─────────────────────────

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

/// "● Active" style line used under agent names.
class StatusLine extends StatelessWidget {
  final String label;
  final Color color;
  final String? suffix;
  const StatusLine({super.key, required this.label, required this.color, this.suffix});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
      if (suffix != null) Flexible(child: Text(' · $suffix', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5))),
    ]);
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w800))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// Big bold title row used at the top of root tabs ("Messages", "Agent Center"…).
class PageHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  const PageHeader({super.key, required this.title, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 8, 8),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.textPrimary))),
        ...actions,
      ]),
    );
  }
}

// ───────────────────────── buttons ─────────────────────────

/// Primary call-to-action: indigo → blue → cyan gradient, as on the reference screens.
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  const GradientButton({super.key, required this.label, required this.onPressed, this.loading = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Center(
                child: loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        if (icon != null) ...[Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8)],
                        Text(label, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700)),
                      ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round gradient floating action button (Contacts "+").
class GradientFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const GradientFab({super.key, required this.onPressed, this.icon = Icons.add_rounded});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

// ───────────────────────── filters / tabs / search ─────────────────────────

/// Horizontal filter chips — selected = solid blue, others = soft fill.
class FilterChips extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final EdgeInsets padding;
  const FilterChips({super.key, required this.labels, required this.selected, required this.onSelected, this.padding = const EdgeInsets.fromLTRB(18, 0, 18, 12)});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(children: [
        for (var i = 0; i < labels.length; i++) ...[
          GestureDetector(
            onTap: () => onSelected(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: i == selected ? AppColors.accent : AppColors.surfaceRaised, borderRadius: BorderRadius.circular(20)),
              child: Text(labels[i], style: TextStyle(color: i == selected ? Colors.white : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ]),
    );
  }
}

/// Two/three-way segmented control (My Agents | Templates, People | Agent).
class SegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final List<IconData?>? icons;
  const SegmentedTabs({super.key, required this.labels, required this.selected, required this.onChanged, this.icons});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surfaceRaised, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: i == selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: i == selected ? [BoxShadow(color: AppColors.indigo.withOpacity(0.12), blurRadius: 4, offset: const Offset(0, 1))] : null,
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (icons != null && icons![i] != null) ...[Icon(icons![i], size: 16, color: i == selected ? AppColors.indigo : AppColors.textSecondary), const SizedBox(width: 6)],
                  Text(labels[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: i == selected ? AppColors.indigo : AppColors.textSecondary)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Soft rounded search field. With [onTap] and [readOnly] it acts as a button
/// that opens the Search screen.
class SoftSearchField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;
  const SoftSearchField({super.key, required this.hint, this.controller, this.onChanged, this.onTap, this.readOnly = false, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: AppColors.surfaceRaised, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.search_rounded, size: 19, color: AppColors.textFaint),
            const SizedBox(width: 9),
            Expanded(
              child: IgnorePointer(
                ignoring: readOnly,
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  readOnly: readOnly,
                  autofocus: autofocus,
                  style: const TextStyle(fontSize: 14.5, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── avatars ─────────────────────────

class AgentStyle {
  final Color color;
  final IconData icon;
  final String tag;
  const AgentStyle(this.color, this.icon, this.tag);
}

const _knownAgents = <String, AgentStyle>{
  'Marketing Agent': AgentStyle(Color(0xFF8B5CF6), Icons.campaign_outlined, 'Marketing & Content'),
  'Research Agent': AgentStyle(Color(0xFF3B82F6), Icons.search_rounded, 'Research & Analysis'),
  'Finance Agent': AgentStyle(Color(0xFF22C55E), Icons.bar_chart_rounded, 'Finance & Accounting'),
  'Personal Assistant': AgentStyle(Color(0xFFF59E0B), Icons.schedule_rounded, 'Daily Life & Productivity'),
  'Health Coach': AgentStyle(Color(0xFFF43F5E), Icons.favorite_border_rounded, 'Fitness, nutrition, wellness'),
  'Content Creator': AgentStyle(Color(0xFF14B8A6), Icons.edit_outlined, 'Content & Social Media'),
  'Travel Agent': AgentStyle(Color(0xFF0EA5E9), Icons.public_rounded, 'Flights & hotels'),
  'Itinerary Agent': AgentStyle(Color(0xFF6366F1), Icons.schedule_rounded, 'Daily itineraries'),
};
const _fallbackAgentColors = [Color(0xFF8B5CF6), Color(0xFF3B82F6), Color(0xFF22C55E), Color(0xFFF59E0B), Color(0xFFF43F5E), Color(0xFF14B8A6), Color(0xFF6366F1), Color(0xFF0EA5E9)];

int _hash(String s) => s.codeUnits.fold(7, (a, c) => (a * 31 + c) & 0x7fffffff);

/// Color + icon + one-line description for an agent, by name (custom agents get a stable color).
AgentStyle agentStyleFor(String name, {String? role}) {
  final known = _knownAgents[name];
  if (known != null) return known;
  return AgentStyle(_fallbackAgentColors[_hash(name) % _fallbackAgentColors.length], Icons.auto_awesome_rounded, role ?? 'Custom agent');
}

/// Agents: a solid coloured circle with a white glyph — clearly different
/// from people (pastel initials) so the two never read as the same thing.
class AgentAvatar extends StatelessWidget {
  final Agent agent;
  final double size;
  const AgentAvatar({super.key, required this.agent, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final st = agentStyleFor(agent.name, role: agent.role);
    final busy = agent.state == AgentActivityState.working || agent.state == AgentActivityState.monitoring;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(width: size, height: size, decoration: BoxDecoration(color: st.color, shape: BoxShape.circle), child: Icon(st.icon, color: Colors.white, size: size * 0.5)),
        if (agent.needsAttention)
          Positioned(right: -1, top: -1, child: _dot(AppColors.approval, size * 0.28))
        else if (busy)
          Positioned(right: -1, bottom: -1, child: _dot(AppColors.success, size * 0.26)),
      ]),
    );
  }

  Widget _dot(Color c, double d) => Container(width: d, height: d, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)));
}

/// The Orchestrator's own mark (gradient circle with a sparkle).
class OrchestratorAvatar extends StatelessWidget {
  final double size;
  const OrchestratorAvatar({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(gradient: AppColors.msgGradient, shape: BoxShape.circle),
        child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: size * 0.48),
      );
}

/// People: pastel circle with initials (colour is stable per name).
class ContactAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final bool online;
  const ContactAvatar({super.key, required this.initials, this.size = 48, this.online = false});

  @override
  Widget build(BuildContext context) {
    final p = AppColors.pastels[_hash(initials) % AppColors.pastels.length];
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p[0], shape: BoxShape.circle),
          child: Text(initials, style: TextStyle(fontSize: size * 0.34, fontWeight: FontWeight.w800, color: p[1])),
        ),
        if (online)
          Positioned(right: -1, bottom: -1, child: Container(width: size * 0.26, height: size * 0.26, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
      ]),
    );
  }
}

class GroupAvatar extends StatelessWidget {
  final double size;
  const GroupAvatar({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: Color(0xFFE5EEFF), shape: BoxShape.circle),
        child: Icon(Icons.groups_2_outlined, color: AppColors.accent, size: size * 0.5),
      );
}

// ───────────────────────── list row & composer ─────────────────────────

/// One conversation / contact row: avatar, name + time, preview, optional status + badge.
class ChatRow extends StatelessWidget {
  final Widget avatar;
  final String title;
  final String? time;
  final String subtitle;
  final Widget? statusLine;
  final int unread;
  final bool pinned;
  final bool muted;
  final bool showChevron;
  final VoidCallback onTap;
  const ChatRow({
    super.key,
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.time,
    this.statusLine,
    this.unread = 0,
    this.pinned = false,
    this.muted = false,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                if (pinned) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.push_pin_outlined, size: 13, color: AppColors.textFaint)),
                if (muted) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.notifications_off_outlined, size: 13, color: AppColors.textFaint)),
                const Spacer(),
                if (time != null) Text(time!, style: const TextStyle(fontSize: 12, color: AppColors.textFaint)),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Expanded(child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                if (unread > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ]),
              if (statusLine != null) Padding(padding: const EdgeInsets.only(top: 3), child: statusLine),
            ]),
          ),
          if (showChevron) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.chevron_right_rounded, color: AppColors.textFaint)),
        ]),
      ),
    );
  }
}

/// Message composer: [+]  (rounded field with emoji icon)  (gradient send).
class ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onSend;
  final VoidCallback? onPlus;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  const ChatComposer({super.key, required this.controller, required this.onSend, this.hint = 'Type a message...', this.onPlus, this.onChanged, this.focusNode});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).padding.bottom * 0),
      child: SafeArea(
        top: false,
        child: Row(children: [
          GestureDetector(
            onTap: onPlus,
            child: Container(width: 38, height: 38, decoration: const BoxDecoration(color: AppColors.surfaceRaised, shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: AppColors.indigo, size: 22)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.only(left: 16, right: 12),
              decoration: BoxDecoration(color: AppColors.surfaceRaised, borderRadius: BorderRadius.circular(22)),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    onSubmitted: (_) => onSend(),
                    textInputAction: TextInputAction.send,
                    style: const TextStyle(fontSize: 14.5, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 14.5),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const Icon(Icons.sentiment_satisfied_alt_rounded, size: 20, color: AppColors.textFaint),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Rounded white card with a hairline border (grouped settings rows, forms…).
class CardList extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets margin;
  const CardList({super.key, required this.children, this.margin = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(const Divider(height: 1, indent: 14, endIndent: 14));
      items.add(children[i]);
    }
    return Container(
      margin: margin,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.stroke)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: items),
    );
  }
}

/// Settings-style row: tinted icon tile, title + subtitle, chevron (or custom trailing).
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;
  const SettingsRow({super.key, required this.icon, required this.title, this.subtitle, this.onTap, this.trailing, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.danger : AppColors.indigo;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: danger ? const Color(0xFFFFE0E1) : AppColors.surfaceRaised, borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 18, color: fg)),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: danger ? AppColors.danger : AppColors.textPrimary)),
              if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 1), child: Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
            ]),
          ),
          trailing ?? (onTap == null || danger ? const SizedBox.shrink() : const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint)),
        ]),
      ),
    );
  }
}

String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${diff.inDays}d';
}
