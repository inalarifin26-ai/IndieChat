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

class ChatScreen extends StatefulWidget {
  final String contactId;
  const ChatScreen({super.key, required this.contactId});

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
    context.read<AppState>().ensureContactMessagesLoaded(widget.contactId);
  }

  Contact get _contact => context.read<AppState>().contacts.firstWhere((c) => c.id == widget.contactId);

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
    // Poll twice to pick up delivered -> read receipts (server flips them
    // at ~0.5s and ~2s after the message lands).
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) context.read<AppState>().refreshContactMessages(widget.contactId);
    });
    Future.delayed(const Duration(milliseconds: 2300), () {
      if (mounted) context.read<AppState>().refreshContactMessages(widget.contactId);
    });
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
    if (key?.currentContext != null) Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final contact = state.contacts.firstWhere((c) => c.id == widget.contactId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ContactSettingsScreen(contactId: contact.id))),
          child: Row(
            children: [
              ContactAvatar(initials: contact.initials, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(contact.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    Text(contact.status, style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ContactSettingsScreen(contactId: contact.id))),
          ),
        ],
      ),
      body: Column(
        children: [
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
                            padding: const EdgeInsets.only(bottom: 4),
                            child: MessageBubble(
                              message: m,
                              showTicks: true,
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
          _Composer(
            controller: _controller,
            onAttach: () => showAttachSheet(
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
            onSend: (t) {
              if (t.trim().isEmpty) return;
              _controller.clear();
              _send(text: t.trim());
            },
          ),
        ],
      ),
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
      child: Row(
        children: [
          Container(width: 3, height: 30, color: AppColors.cyan),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Replying to ${message.isMine ? 'yourself' : 'them'}', style: const TextStyle(color: AppColors.cyan, fontSize: 11, fontWeight: FontWeight.w700)),
                Text(message.snippet, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: onCancel),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final VoidCallback onAttach;
  const _Composer({required this.controller, required this.onSend, required this.onAttach});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 8, 10, 8),
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.stroke))),
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.attach_file_rounded, color: AppColors.textSecondary), onPressed: onAttach),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 14.5),
                decoration: const InputDecoration(hintText: 'Message', isDense: true),
                onSubmitted: onSend,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => onSend(controller.text),
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
    );
  }
}
