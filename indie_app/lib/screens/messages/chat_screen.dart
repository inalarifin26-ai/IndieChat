import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/format.dart';
import '../../models/chat_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/message_action_sheet.dart';
import 'contact_settings_screen.dart';

/// A person or group chat room. In groups, incoming messages show who said it.
class ChatScreen extends StatefulWidget {
  final String contactId;
  /// When opened from Search: scroll to (and briefly keep in view) this message.
  final String? highlightMessageId;
  const ChatScreen({super.key, required this.contactId, this.highlightMessageId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};
  ChatMessage? _replyTo;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().ensureContactMessagesLoaded(widget.contactId).then((_) {
      if (!mounted || widget.highlightMessageId == null) return;
      final c = context.read<AppState>().contacts.where((c) => c.id == widget.contactId);
      if (c.isEmpty) return;
      final idx = c.first.messages.indexWhere((m) => m.id == widget.highlightMessageId);
      if (idx < 0) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        // Rows are built lazily, so first jump close by, then fine-tune once the target exists.
        _scroll.jumpTo((idx * 84.0).clamp(0.0, _scroll.position.maxScrollExtent));
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpTo(widget.highlightMessageId!));
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send({String? text, MessageKind kind = MessageKind.text, Map<String, dynamic>? payload, String? outputId}) async {
    final replyId = _replyTo?.id;
    setState(() => _replyTo = null);
    try {
      await context.read<AppState>().sendContactMessage(
            widget.contactId,
            text: text,
            kind: kind,
            payload: payload,
            outputId: outputId,
            replyToId: replyId,
          );
      _afterSend();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send: $e')));
    }
  }

  void _afterSend() {
    _jumpToEndSoon();
    // Poll a few times to pick up delivered → read receipts and (in groups)
    // the member reply the server simulates ~2.3s after your message.
    for (final ms in [700, 2300, 3300]) {
      Future.delayed(Duration(milliseconds: ms), () {
        if (!mounted) return;
        context.read<AppState>().refreshContactMessages(widget.contactId).then((_) => _jumpToEndSoon());
      });
    }
  }

  void _jumpToEndSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  void _openMessage(ChatMessage m) {
    showMessageActions(
      context,
      message: m,
      onReact: (e) => context.read<AppState>().reactContactMessage(widget.contactId, m.id, e),
      onReply: () => setState(() => _replyTo = m),
      onCopy: m.kind == MessageKind.text
          ? () {
              Clipboard.setData(ClipboardData(text: m.text));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
            }
          : null,
      onSave: m.kind == MessageKind.file || m.kind == MessageKind.output ? () => context.read<AppState>().saveContactMessage(widget.contactId, m.id) : null,
      onDelete: m.isMine ? () => context.read<AppState>().deleteContactMessage(widget.contactId, m.id) : null,
    );
  }

  void _jumpTo(String id) {
    final key = _keys[id];
    if (key?.currentContext != null) Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 300), alignment: 0.3);
  }

  void _openSettings(Contact c) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ContactSettingsScreen(contactId: c.id)));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final found = state.contacts.where((c) => c.id == widget.contactId);
    if (found.isEmpty) {
      // The contact/group was deleted (or left) from the settings screen.
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('This chat no longer exists.', style: TextStyle(color: AppColors.textFaint))));
    }
    final contact = found.first;
    final online = contact.status.toLowerCase() == 'online';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => _openSettings(contact),
          child: Row(children: [
            contact.isGroup ? const GroupAvatar(size: 36) : ContactAvatar(initials: contact.initials, size: 36, online: online),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(contact.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                contact.isGroup
                    ? Text('${contact.memberCount} members', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
                    : (online ? const StatusLine(label: 'Online', color: AppColors.success) : Text(contact.status, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              ]),
            ),
          ]),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.phone_outlined), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calls are not available yet'))),),
          IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: () => _openSettings(contact)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: contact.messages.isEmpty
              ? const Center(child: Text('No messages yet — say hi 👋', style: TextStyle(color: AppColors.textFaint)))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(14),
                  itemCount: contact.messages.length,
                  itemBuilder: (context, i) {
                    final m = contact.messages[i];
                    final showDate = i == 0 || !sameDay(contact.messages[i - 1].timestamp, m.timestamp);
                    _keys.putIfAbsent(m.id, () => GlobalKey());
                    return Column(
                      key: _keys[m.id],
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDate) DateSeparator(label: dayLabel(m.timestamp)),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: MessageBubble(
                            message: m,
                            showTicks: true,
                            showSender: contact.isGroup,
                            onOpen: () => _openMessage(m),
                            onJumpTo: _jumpTo,
                            onReact: (e) => context.read<AppState>().reactContactMessage(widget.contactId, m.id, e),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        if (_replyTo != null) _ReplyBar(message: _replyTo!, onCancel: () => setState(() => _replyTo = null)),
        ChatComposer(
          controller: _controller,
          onPlus: () => showAttachSheet(
            context,
            onFile: () => _send(kind: MessageKind.file, payload: {
              'file': {'name': 'Campaign-Report.pdf', 'size': '2.4 MB'}
            }),
            onPhoto: () => _send(kind: MessageKind.file, payload: {
              'file': {'name': 'IMG_2041.jpg', 'size': '1.1 MB'}
            }),
            vaultOutputs: state.outputs,
            onPickOutput: (o) => _send(kind: MessageKind.output, outputId: o.id as String),
          ),
          onSend: () {
            final t = _controller.text.trim();
            if (t.isEmpty) return;
            _controller.clear();
            _send(text: t);
          },
        ),
      ]),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onCancel;
  const _ReplyBar({required this.message, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.stroke))),
      child: Row(children: [
        Container(width: 3, height: 30, color: AppColors.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Replying to ${message.isMine ? 'yourself' : (message.from ?? 'them')}', style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700)),
            Text(message.snippet, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ]),
        ),
        IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: onCancel),
      ]),
    );
  }
}
